#!/usr/bin/env python3
"""Submit one recorded Tripo image job, inspect it, or download its outputs."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import mimetypes
from pathlib import Path
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid

from tripo_setup import NoRedirect, SetupError, load_key


BASE = "https://openapi.tripo3d.ai/v3"


def save(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def api(path, data=None, content_type="application/json"):
    key = load_key()
    request = urllib.request.Request(
        BASE + path, data=data,
        headers={"Authorization": "Bearer " + key, "Content-Type": content_type},
        method="POST" if data is not None else "GET",
    )
    try:
        with urllib.request.build_opener(NoRedirect()).open(request, timeout=90) as response:
            result = json.load(response)
    except urllib.error.HTTPError as error:
        # Surface the provider's actual restriction, without printing credentials.
        detail = error.read(8192).decode("utf-8", errors="replace").replace(key, "[REDACTED]")
        raise SetupError(f"HTTP {error.code}: {detail}") from None
    except (urllib.error.URLError, TimeoutError):
        raise SetupError("Network failure. Do not resubmit a generation blindly; inspect its submission record.") from None
    if not isinstance(result, dict) or result.get("code") != 0:
        raise SetupError(json.dumps(result, ensure_ascii=False).replace(key, "[REDACTED]"))
    return result


def validate(config_path):
    config = json.loads(config_path.read_text())
    image = (config_path.parent / config["image"]).resolve()
    options = config["generation"]
    if not image.is_file() or image.suffix.lower() not in (".png", ".jpg", ".jpeg"):
        raise SetupError("Input must be an existing PNG or JPEG.")
    if image.stat().st_size > 20 * 1024 * 1024:
        raise SetupError("Input exceeds 20 MB.")
    if options.get("model") != "P2-20260801" or options.get("texture_quality") != "detailed":
        raise SetupError("This runner is scoped to the authorized P2 detailed generation.")
    if options.get("texture") is not True or options.get("pbr") is not True:
        raise SetupError("Detailed PBR textures must be enabled.")
    faces = options.get("face_limit")
    maximum = 25000 if options.get("quad") else 50000
    if type(faces) is not int or not 48 <= faces <= maximum:
        raise SetupError("Invalid P2 face_limit.")
    if "input" in options:
        raise SetupError("Input is supplied by the upload step.")
    return image, options


def submit(config_path):
    folder = config_path.parent
    image, options = validate(config_path)
    marker = folder / "submission_started.json"
    if marker.exists() or (folder / "task.json").exists():
        raise SetupError("A submission record already exists. Use status; do not duplicate this job.")
    before = api("/account/balance")
    if before["data"]["balance"] < 120:
        raise SetupError("Less than the documented 120-credit estimate is available.")
    upload_path = folder / "upload_response.json"
    digest = hashlib.sha256(image.read_bytes()).hexdigest()
    if upload_path.exists():
        upload = json.loads(upload_path.read_text())
        if upload.get("input_sha256") != digest:
            raise SetupError("Input changed since upload; use a new run directory.")
    else:
        boundary = "tripo-" + uuid.uuid4().hex
        mime = mimetypes.guess_type(image.name)[0] or "application/octet-stream"
        header = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; "
                  f"filename=\"input{image.suffix.lower()}\"\r\nContent-Type: {mime}\r\n\r\n").encode()
        body = header + image.read_bytes() + f"\r\n--{boundary}--\r\n".encode()
        upload = api("/files", body, f"multipart/form-data; boundary={boundary}")
        upload["input_sha256"] = digest
        save(upload_path, upload)
    payload = dict(options, input=upload["data"]["file_token"])
    save(folder / "request.json", payload)
    # Exclusive marker BEFORE the paid POST prevents accidental duplicate submissions.
    with marker.open("x") as stream:
        json.dump({"started_at": datetime.now(timezone.utc).isoformat(), "balance_before": before["data"]}, stream)
    result = api("/generation/image-to-model", json.dumps(payload).encode())
    task_id = result["data"]["task_id"]
    save(folder / "task.json", {"task_id": task_id, "input_sha256": digest, "balance_before": before["data"], "model": options["model"]})
    print(json.dumps({"task_id": task_id, "status": "submitted", "estimated_credits": 120}))


def status(folder):
    record = json.loads((folder / "task.json").read_text())
    task_id = record["task_id"]
    if not isinstance(task_id, str) or not re.fullmatch(r"[A-Za-z0-9_-]+", task_id):
        raise SetupError("Invalid task ID.")
    result = api("/tasks/" + task_id)
    save(folder / "task_response.json", result)
    task = result["data"]
    fields = ("task_id", "status", "progress", "credits_consumed", "error_code", "error_message")
    print(json.dumps({k: task[k] for k in fields if k in task}, ensure_ascii=False))
    if task["status"] in ("success", "failed", "cancelled"):
        after = api("/account/balance")["data"]
        record.update({k: task[k] for k in fields if k in task})
        record["balance_after"] = after
        save(folder / "task.json", record)
        print(json.dumps({"balance_after": after}))
    return task


def find_urls(value, prefix="output"):
    if isinstance(value, dict):
        for name, child in value.items():
            yield from find_urls(child, prefix + "_" + name)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from find_urls(child, prefix + "_" + str(index))
    elif isinstance(value, str) and value.startswith("https://"):
        yield prefix, value


def download(folder):
    task = status(folder)
    if task["status"] != "success":
        raise SetupError("Task is not successful; no outputs downloaded.")
    raw = folder / "raw"
    raw.mkdir(exist_ok=True)
    manifest = []
    for label, url in find_urls(task.get("output", {})):
        parsed = urllib.parse.urlparse(url)
        if parsed.username or parsed.password or not parsed.hostname:
            raise SetupError("Invalid output URL.")
        extension = Path(parsed.path).suffix.lower()
        if extension not in (".glb", ".gltf", ".fbx", ".obj", ".zip", ".png", ".jpg", ".jpeg", ".webp"):
            extension = ".bin"
        target = raw / (re.sub(r"[^A-Za-z0-9_-]", "_", label) + extension)
        if not target.exists():
            partial = target.with_suffix(target.suffix + ".part")
            # Download only URLs returned by this job; send NO API authorization.
            with urllib.request.urlopen(url, timeout=90) as response, partial.open("wb") as output:
                while chunk := response.read(1024 * 1024):
                    output.write(chunk)
            partial.replace(target)
        manifest.append({"file": str(target.relative_to(folder)), "bytes": target.stat().st_size,
                         "sha256": hashlib.sha256(target.read_bytes()).hexdigest()})
    if not manifest:
        raise SetupError("No downloadable outputs found; inspect task_response.json.")
    save(folder / "download_manifest.json", manifest)
    print(json.dumps(manifest, ensure_ascii=False))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("plan", "submit", "status", "download"))
    parser.add_argument("config", type=Path)
    args = parser.parse_args()
    config_path = args.config.resolve()
    try:
        if args.command == "plan":
            image, options = validate(config_path)
            print(json.dumps({"image": str(image), "generation": options, "estimated_credits": 120}, indent=2))
        elif args.command == "submit":
            submit(config_path)
        elif args.command == "status":
            status(config_path.parent)
        else:
            download(config_path.parent)
    except SetupError as error:
        print(str(error), file=sys.stderr)
        return 1
    except (OSError, ValueError, KeyError):
        print("I/O or response-format failure. Check saved records before attempting another submission.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
