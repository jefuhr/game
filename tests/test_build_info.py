import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("build_info", Path(__file__).resolve().parents[1] / "tools/write_build_info.py")
module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(module)


class BuildInfoTests(unittest.TestCase):
    def test_pr_stamp_distinguishes_head_from_tested_merge(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            event = root / "event.json"
            event.write_text(json.dumps({"number": 42, "pull_request": {"head": {"sha": "b" * 40}}}))
            with patch.object(module, "ROOT", root), patch.object(module, "revision", side_effect=lambda ref: "c" * 40 if ref == "HEAD" else "a" * 40), patch.dict(os.environ, {"GITHUB_REF": "refs/pull/42/merge", "GITHUB_EVENT_NAME": "pull_request", "GITHUB_EVENT_PATH": str(event)}):
                module.main()
            info = json.loads((root / "build_info.json").read_text())
            self.assertEqual(info, {"pr_number": 42, "preview_hash": "b" * 40, "build_hash": "c" * 40, "master_hash": "a" * 40})

    def test_master_stamp_uses_deployed_commit(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with patch.object(module, "ROOT", root), patch.object(module, "revision", return_value="a" * 40), patch.dict(os.environ, {"GITHUB_REF": "refs/heads/master", "GITHUB_SHA": "a" * 40, "GITHUB_EVENT_NAME": "push"}):
                module.main()
            info = json.loads((root / "build_info.json").read_text())
            self.assertNotIn("preview_hash", info)
            self.assertEqual(info["master_hash"], "a" * 40)
