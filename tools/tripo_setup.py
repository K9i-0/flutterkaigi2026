#!/usr/bin/env python3
"""Store a local Tripo credential or check its balance; never generate assets."""

import argparse
from decimal import Decimal, InvalidOperation
import getpass
import json
import os
from pathlib import Path
import sys
import tempfile
import urllib.error
import urllib.request


ROOT = Path(__file__).resolve().parents[1]
KEY_FILE = ROOT / ".local" / "tripo" / "api_key"
BALANCE_URL = "https://openapi.tripo3d.ai/v3/account/balance"


class SetupError(Exception):
    pass


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # Never forward credentials to a redirected endpoint.
        return None


def validate_key(value):
    key = value.strip()
    if not key or not key.isascii() or any(c.isspace() for c in key):
        raise SetupError("APIキーが空か、空白・非ASCII文字を含んでいます。")
    return key


def save_key():
    if not sys.stdin.isatty():
        raise SetupError("set-keyは手元の対話ターミナルで実行してください。")
    key = validate_key(getpass.getpass("Tripo API key（入力は非表示）: "))
    KEY_FILE.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    KEY_FILE.parent.chmod(0o700)
    # Atomic replacement also keeps an existing key intact if writing fails.
    fd, temporary = tempfile.mkstemp(prefix=".api_key-", dir=KEY_FILE.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            stream.write(key + "\n")
        os.replace(temporary, KEY_FILE)
    finally:
        Path(temporary).unlink(missing_ok=True)
    print("APIキーを.local/tripo/api_keyへ保存しました（所有者のみ読み書き可）。")
    print("接続確認: python3 tools/tripo_setup.py check")


def load_key():
    if "TRIPO_API_KEY" in os.environ:
        return validate_key(os.environ["TRIPO_API_KEY"])
    if not KEY_FILE.is_file():
        raise SetupError("APIキー未設定です。python3 tools/tripo_setup.py set-key を実行してください。")
    return validate_key(KEY_FILE.read_text(encoding="utf-8"))


def parse_balance(payload):
    if not isinstance(payload, dict) or payload.get("code") != 0:
        raise SetupError("Tripo APIが成功以外を返しました。コンソールでキーとアカウントを確認してください。")
    data = payload.get("data")
    if not isinstance(data, dict):
        raise SetupError("残高レスポンスの形式が想定と異なります。")
    amounts = []
    for field in ("balance", "frozen"):
        value = data.get(field)
        if isinstance(value, bool) or not isinstance(value, (int, Decimal)):
            raise SetupError("残高レスポンスの数値形式が想定と異なります。")
        amount = Decimal(value)
        if not amount.is_finite() or amount < 0:
            raise SetupError("残高レスポンスの数値が不正です。")
        amounts.append(amount)
    return amounts


def check_balance():
    request = urllib.request.Request(
        BALANCE_URL,
        headers={"Authorization": "Bearer " + load_key(), "Accept": "application/json"},
        method="GET",
    )
    opener = urllib.request.build_opener(NoRedirect())
    try:
        with opener.open(request, timeout=30) as response:
            payload = json.load(response, parse_float=Decimal)
    except urllib.error.HTTPError as error:
        hints = {
            401: "APIキーが無効、または期限切れです。",
            403: "アカウントまたはAPIキーのアクセス権を確認してください。",
            429: "レート制限です。時間をおいて再試行してください。",
        }
        raise SetupError(f"HTTP {error.code}: " + hints.get(error.code, "Tripoへの接続に失敗しました。")) from None
    except (urllib.error.URLError, TimeoutError):
        raise SetupError("Tripoに接続できません。ネットワーク接続を確認してください。") from None
    available, frozen = parse_balance(payload)
    print("Tripo APIの認証に成功しました。")
    print(f"利用可能: {available:.2f} credits / 凍結中: {frozen:.2f} credits")
    if available == 0:
        print("生成前にAPIクレジットのチャージが必要です。")
    print("残高照会のみ実施。生成タスクは送信していません。P2利用可否は未検証です。")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("set-key", "check"))
    args = parser.parse_args()
    try:
        if args.command == "set-key":
            save_key()
        else:
            check_balance()
    except SetupError as error:
        print(str(error), file=sys.stderr)
        return 1
    except (OSError, ValueError, InvalidOperation):
        # Avoid echoing credentials or remote response bodies in diagnostics.
        print("設定ファイルの入出力、またはAPI応答の読み取りに失敗しました。", file=sys.stderr)
        return 1
    except (EOFError, KeyboardInterrupt):
        print("中断しました。", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
