#!/usr/bin/env python3
"""Dry run by default; --submit explicitly sends a paid request."""
import importlib.util
from pathlib import Path
import sys
HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
spec = importlib.util.spec_from_file_location("wan_runner", ROOT / ".claude/skills/wan-video/scripts/qwen_wan3_generate.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
module.SUBMIT_URL = "https://maas.qwencloudapi.com/api/v1/services/aigc/video-generation/video-synthesis"
module.QUERY_URL = "https://maas.qwencloudapi.com/api/v1/tasks/{task_id}"
sys.argv = [sys.argv[0], str(HERE / "wan3_config.json"), *sys.argv[1:]]
if __name__ == "__main__":
    raise SystemExit(module.main())
