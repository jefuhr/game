import importlib.util
import io
import json
from pathlib import Path
import stat
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch
import zipfile

SPEC = importlib.util.spec_from_file_location("publisher", Path(__file__).resolve().parents[1] / "tools/publish_previews.py")
publisher = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(publisher)
NOW = datetime.now(timezone.utc)
MASTER = "a" * 40
HEAD = "b" * 40
OTHER = "c" * 40


def run(number, event="pull_request", sha=HEAD, age=0, pr=42, branch="feature"):
    return {"id": number, "run_number": number, "run_attempt": 1,
            "status": "completed", "conclusion": "success", "event": event,
            "head_branch": branch, "head_sha": sha,
            "created_at": (NOW - timedelta(days=age)).isoformat(),
            "html_url": f"https://github.com/test/game/actions/runs/{number}",
            "pull_requests": [{"number": pr}] if pr else []}


def pull(number=42, state="open", sha=HEAD, base="master"):
    return {"number": number, "state": state, "base": {"ref": base}, "head": {"sha": sha}}


def archive(extra=None, content=b"game"):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as z:
        for name in publisher.REQUIRED:
            z.writestr(name, content)
        for name, value in extra or []:
            z.writestr(name, value)
    return buffer.getvalue()


class FakeGitHub:
    def __init__(self, runs, pulls, artifacts=None, comments=None):
        self.runs = runs
        self.pulls = pulls
        self.artifacts = artifacts or {r["id"]: archive(content=str(r["id"]).encode()) for r in runs}
        self.comments = comments or []
        self.writes = []

    def pages(self, path, key=None):
        if path.startswith("/pulls?"):
            return iter(self.pulls)
        if path.startswith("/actions/workflows/"):
            return iter(self.runs)
        if path.startswith("/issues/comments?"):
            return iter(self.comments)
        if path.startswith("/commits/"):
            return iter(self.pulls)
        raise AssertionError(path)

    def request(self, path, method="GET", data=None):
        if method != "GET":
            self.writes.append((path, method, data))
            return {}
        if path.startswith("/actions/runs/"):
            number = int(path.split("/")[3])
            return {"artifacts": [{"id": number, "name": publisher.ARTIFACT, "expired": False}] if number in self.artifacts else []}
        if path.startswith("/pulls/"):
            number = int(path.rsplit("/", 1)[1])
            return next(p for p in self.pulls if p["number"] == number)
        raise AssertionError(path)

    def artifact_zip(self, number):
        return self.artifacts[number]


class PublishingTests(unittest.TestCase):
    def test_production_is_only_successful_master_build(self):
        failed = run(5, "push", branch="master")
        failed["conclusion"] = "failure"
        production, previews = publisher.choose_builds([
            failed, run(4, "push"), run(3, "push", MASTER, branch="master"), run(2)
        ], [pull()], NOW)
        self.assertEqual([r["id"] for r in production], [3])
        self.assertEqual([p["run"]["id"] for p in previews], [2])

    def test_only_open_recent_master_prs_and_newest_duplicate(self):
        _, previews = publisher.choose_builds([
            run(10), run(9), run(8, sha=OTHER), run(7, age=15, sha="d"*40),
            run(6, pr=43), run(5, pr=44), run(4, sha="../invalid")
        ], [pull(), pull(43, "closed"), pull(44, base="other")], NOW)
        self.assertEqual([p["run"]["id"] for p in previews], [10, 8])

    def test_rerun_renews_retention(self):
        old = run(1, age=20)
        old["updated_at"] = NOW.isoformat()
        self.assertEqual(len(publisher.choose_builds([old], [pull()], NOW)[1]), 1)

    def test_archive_cannot_escape_or_overwrite_site(self):
        for name in ["../index.html", "/index.html", "previews/index.html", "index..html", "evil.sh", ".git/config"]:
            with self.subTest(name=name), self.assertRaises(ValueError):
                publisher.unpack_build(archive([(name, b"bad")]))

    def test_archive_rejects_symlink_duplicates_and_missing_files(self):
        link = zipfile.ZipInfo("index.link")
        link.create_system = 3
        link.external_attr = (stat.S_IFLNK | 0o777) << 16
        with self.assertRaises(ValueError):
            publisher.unpack_build(archive([(link, b"/etc/passwd")]))
        with self.assertWarns(UserWarning):
            duplicate = archive([("index.html", b"duplicate")])
        with self.assertRaises(ValueError):
            publisher.unpack_build(duplicate)
        with self.assertRaises(ValueError):
            publisher.unpack_build(archive(content=b""))

    def test_archive_size_limit(self):
        with patch.object(publisher, "MAX_BUILD_BYTES", 3), self.assertRaises(ValueError):
            publisher.unpack_build(archive())

    def test_production_and_previews_are_kept_separate_and_invalid_preview_skipped(self):
        runs = [run(3, sha=OTHER), run(2), run(1, "push", MASTER, branch="master")]
        api = FakeGitHub(runs, [pull()])
        api.artifacts[3] = archive([("../index.html", b"bad")])
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            publisher.assemble(api, root / "site", root / "report.json")
            self.assertEqual((root / "site/index.html").read_bytes(), b"1")
            report = json.loads((root / "report.json").read_text())
            self.assertEqual(report["production_sha"], MASTER)
            self.assertEqual(len(report["previews"]), 1)
            self.assertEqual((root / "site" / report["previews"][0]["path"] / "index.html").read_bytes(), b"2")

    def test_preview_limit_and_fork_association(self):
        runs = [run(3, sha=OTHER, pr=None), run(2), run(1, "push", MASTER, branch="master")]
        api = FakeGitHub(runs, [pull()])
        with tempfile.TemporaryDirectory() as directory, patch.object(publisher, "MAX_PREVIEWS", 1):
            root = Path(directory)
            publisher.assemble(api, root / "site", root / "report.json")
            report = json.loads((root / "report.json").read_text())
            self.assertEqual([p["sha"] for p in report["previews"]], [OTHER])

    def test_missing_production_fails_instead_of_replacing_live_game(self):
        with tempfile.TemporaryDirectory() as directory, self.assertRaises(RuntimeError):
            publisher.assemble(FakeGitHub([run(2)], [pull()]), Path(directory) / "site", Path(directory) / "report")

    def test_site_budget_preserves_production_and_newest_preview(self):
        runs = [run(3, sha=OTHER), run(2), run(1, "push", MASTER, branch="master")]
        with tempfile.TemporaryDirectory() as directory, patch.object(publisher, "MAX_SITE_BYTES", 8):
            root = Path(directory)
            publisher.assemble(FakeGitHub(runs, [pull()]), root / "site", root / "report")
            report = json.loads((root / "report").read_text())
            self.assertEqual([p["sha"] for p in report["previews"]], [OTHER])
            self.assertEqual((root / "site/index.html").read_bytes(), b"1")

    def test_reruns_use_distinct_urls(self):
        paths = []
        for attempt in (1, 2):
            preview_run = run(2)
            preview_run["run_attempt"] = attempt
            api = FakeGitHub([preview_run, run(1, "push", MASTER, branch="master")], [pull()])
            with tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                publisher.assemble(api, root / "site", root / "report")
                paths.append(json.loads((root / "report").read_text())["previews"][0]["path"])
        self.assertNotEqual(*paths)

    def test_missing_latest_artifact_uses_previous_retained_build(self):
        runs = [run(3), run(2, "push", MASTER, branch="master"), run(1, "push", MASTER, branch="master")]
        api = FakeGitHub(runs, [pull()])
        del api.artifacts[2]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            publisher.assemble(api, root / "site", root / "report")
            self.assertEqual((root / "site/index.html").read_bytes(), b"1")

    def test_sticky_comment_updates_and_expired_comment_is_retired(self):
        comments = [{"id": n, "issue_url": f"https://api.github.com/repos/test/game/issues/{pr}",
                     "user": {"login": "github-actions[bot]"}, "body": publisher.MARKER + " old"}
                    for n, pr in [(100, 42), (101, 43)]]
        api = FakeGitHub([], [pull(), pull(43, "closed")], comments=comments)
        preview = {"number": 42, "sha": HEAD, "path": f"previews/pr-42/{HEAD}/", "run_url": "https://github.com/test/game/actions/runs/2"}
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / "report.json"
            report.write_text(json.dumps({"previews": [preview]}))
            publisher.comment(api, report, "https://test.github.io/game/")
        self.assertEqual([w[1] for w in api.writes], ["PATCH", "PATCH"])
        self.assertIn(f"https://test.github.io/game/previews/pr-42/{HEAD}/", api.writes[0][2]["body"])
        self.assertIn("expired", api.writes[1][2]["body"])

    def test_comment_marks_older_commit_and_creates_once(self):
        preview = {"number": 42, "sha": HEAD, "path": "previews/pr-42/test/", "run_url": "https://github.com/test/game/actions/runs/2"}
        self.assertIn("newer commit", publisher.preview_comment(preview, "https://test.github.io/game", OTHER))
        self.assertNotIn("newer commit", publisher.preview_comment(preview, "https://test.github.io/game", HEAD))
        api = FakeGitHub([], [pull()])
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / "report.json"
            report.write_text(json.dumps({"previews": [preview]}))
            publisher.comment(api, report, "https://test.github.io/game")
        self.assertEqual(api.writes[0][0:2], ("/issues/42/comments", "POST"))


if __name__ == "__main__":
    unittest.main()
