"""Assemble a Pages site from successful CI artifacts without executing PR code."""

import argparse
from datetime import datetime, timedelta, timezone
import io
import json
import os
from pathlib import Path
import re
import stat
import urllib.error
import urllib.parse
import urllib.request
import zipfile

ARTIFACT = "web-build"
MARKER = "<!-- tfpp-game-preview -->"
RETENTION_DAYS = 14
MAX_PREVIEWS = 12
MAX_BUILD_BYTES = 128 * 1024 * 1024
MAX_SITE_BYTES = 700 * 1024 * 1024
REQUIRED = {"index.html", "index.js", "index.wasm", "index.pck"}


class GitHub:
    def __init__(self):
        self.repo = os.environ["GITHUB_REPOSITORY"]
        self.base = f"https://api.github.com/repos/{self.repo}"
        self.token = os.environ["GH_TOKEN"]

    def request(self, path, method="GET", data=None):
        request = urllib.request.Request(
            self.base + path,
            data=None if data is None else json.dumps(data).encode(),
            method=method,
            headers={"Authorization": f"Bearer {self.token}",
                     "Accept": "application/vnd.github+json",
                     "X-GitHub-Api-Version": "2022-11-28",
                     "Content-Type": "application/json"},
        )
        with urllib.request.urlopen(request, timeout=60) as response:
            body = response.read()
        return json.loads(body) if body else None

    def pages(self, path, key=None, max_pages=10):
        for page in range(1, max_pages + 1):
            separator = "&" if "?" in path else "?"
            result = self.request(f"{path}{separator}per_page=100&page={page}")
            items = result[key] if key else result
            yield from items
            if len(items) < 100:
                break

    def artifact_zip(self, artifact_id):
        # GitHub redirects to signed blob storage. Do not forward the API token there.
        class NoRedirect(urllib.request.HTTPRedirectHandler):
            def redirect_request(self, req, fp, code, msg, headers, newurl):
                return None

        request = urllib.request.Request(
            f"{self.base}/actions/artifacts/{int(artifact_id)}/zip",
            headers={"Authorization": f"Bearer {self.token}",
                     "Accept": "application/vnd.github+json"},
        )
        try:
            urllib.request.build_opener(NoRedirect).open(request, timeout=60)
        except urllib.error.HTTPError as error:
            if error.code != 302:
                raise
            url = error.headers["Location"]
        else:
            raise RuntimeError("Artifact download did not return a signed URL")
        if urllib.parse.urlsplit(url).scheme != "https":
            raise ValueError("Artifact redirect must use HTTPS")
        with urllib.request.urlopen(url, timeout=120) as response:
            content = response.read(MAX_BUILD_BYTES + 1)
        if len(content) > MAX_BUILD_BYTES:
            raise ValueError("Artifact archive exceeds the size limit")
        return content


def unpack_build(content):
    """Accept only regular, flat Godot export files; never use extractall on PR input."""
    files = {}
    with zipfile.ZipFile(io.BytesIO(content)) as archive:
        if len(archive.infolist()) > 64:
            raise ValueError("Too many files in build artifact")
        total = 0
        for entry in archive.infolist():
            name = entry.filename
            mode = entry.external_attr >> 16
            if (not re.fullmatch(r"index\.[a-zA-Z0-9_.-]+", name)
                    or ".." in name or entry.is_dir()
                    or stat.S_ISLNK(mode)
                    or (stat.S_IFMT(mode) and not stat.S_ISREG(mode))):
                raise ValueError(f"Unexpected build artifact entry: {name!r}")
            if name in files:
                raise ValueError("Duplicate artifact entry")
            if entry.flag_bits & 1 or entry.compress_type not in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED):
                raise ValueError("Unsupported or encrypted artifact entry")
            total += entry.file_size
            if total > MAX_BUILD_BYTES:
                raise ValueError("Unpacked build exceeds the size limit")
            files[name] = archive.read(entry)
    if not REQUIRED.issubset(files) or any(not files[name] for name in REQUIRED):
        raise ValueError("Incomplete Godot web export")
    return files


def choose_builds(runs, pull_requests, now):
    """Newest run wins for duplicate commits. Only open PRs targeting master qualify."""
    cutoff = now - timedelta(days=RETENTION_DAYS)
    production = []
    previews = []
    seen = set()
    pulls = {p["number"]: p for p in pull_requests if p["state"] == "open" and p["base"]["ref"] == "master"}
    for run in sorted(runs, key=lambda r: (r["run_number"], r.get("run_attempt", 1)), reverse=True):
        if run["conclusion"] != "success" or run["status"] != "completed":
            continue
        if run["event"] in ("push", "workflow_dispatch") and run["head_branch"] == "master":
            production.append(run)
            continue
        if run["event"] != "pull_request" or datetime.fromisoformat(run.get("updated_at", run["created_at"]).replace("Z", "+00:00")) < cutoff:
            continue
        sha = run["head_sha"]
        if not re.fullmatch(r"[0-9a-f]{40}", sha):
            continue
        for association in run.get("pull_requests", []):
            number = association["number"]
            if number not in pulls or (number, sha) in seen:
                continue
            seen.add((number, sha))
            previews.append({"number": number, "sha": sha, "run": run})
    return production, previews


def artifact_for(api, run):
    artifacts = api.request(f"/actions/runs/{run['id']}/artifacts")["artifacts"]
    return next((a for a in artifacts if a["name"] == ARTIFACT and not a["expired"]), None)


def write_files(directory, files):
    directory.mkdir(parents=True, exist_ok=True)
    for name, content in files.items():
        (directory / name).write_bytes(content)


def assemble(api, output, report_path):
    if output.exists() and any(output.iterdir()):
        raise ValueError("Output directory must be empty")
    pulls = list(api.pages("/pulls?state=open&base=master"))
    runs = list(api.pages("/actions/workflows/pages.yml/runs?status=success", "workflow_runs"))
    # Fork workflow_run payloads can omit pull_requests. Resolve association via
    # GitHub's commit API, never a PR-controlled metadata file in the artifact.
    cutoff = datetime.now(timezone.utc) - timedelta(days=RETENTION_DAYS)
    for run in runs:
        timestamp = datetime.fromisoformat(run.get("updated_at", run["created_at"]).replace("Z", "+00:00"))
        if run["event"] == "pull_request" and not run.get("pull_requests") and timestamp >= cutoff:
            if re.fullmatch(r"[0-9a-f]{40}", run["head_sha"]):
                run["pull_requests"] = list(api.pages(f"/commits/{run['head_sha']}/pulls"))
    production_runs, preview_runs = choose_builds(runs, pulls, datetime.now(timezone.utc))
    production = None
    for run in production_runs:
        artifact = artifact_for(api, run)
        if artifact:
            production = run
            files = unpack_build(api.artifact_zip(artifact["id"]))
            break
    if production is None:
        raise RuntimeError("No retained master web-build artifact. Run 'Build and deploy web game' on master first.")
    write_files(output, files)
    total = sum(map(len, files.values()))
    report = {"production_sha": production["head_sha"], "previews": []}
    for preview in preview_runs:
        if len(report["previews"]) >= MAX_PREVIEWS:
            break
        artifact = artifact_for(api, preview["run"])
        if not artifact:
            continue
        try:
            files = unpack_build(api.artifact_zip(artifact["id"]))
        except (ValueError, zipfile.BadZipFile) as error:
            print(f"Skipping invalid preview from run {preview['run']['id']}: {error}")
            continue
        size = sum(map(len, files.values()))
        if total + size > MAX_SITE_BYTES:
            continue
        build_id = f"{preview['run']['id']}-{preview['run'].get('run_attempt', 1)}"
        relative = f"previews/pr-{preview['number']}/{preview['sha']}/{build_id}"
        write_files(output / relative, files)
        total += size
        report["previews"].append({"number": preview["number"], "sha": preview["sha"],
                                   "path": relative + "/", "run_url": preview["run"]["html_url"]})
    (output / ".nojekyll").touch()
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(f"Assembled production and {len(report['previews'])} previews ({total // 1024 // 1024} MiB)")


def preview_comment(preview, base_url, current_sha):
    stale = "\n\nA newer commit is still awaiting a successful preview; this link tests the commit shown above." if current_sha != preview["sha"] else ""
    return (f"{MARKER}\n### Playable game preview\n\n"
            f"**[▶ Play this build]({base_url.rstrip('/')}/{preview['path']})**\n\n"
            f"PR commit: `{preview['sha']}` · [Build run]({preview['run_url']})\n\n"
            "This build includes GitHub's proposed merge with master. "
            "Open the link on desktop or your phone to test before approving."
            f"{stale}\n\nPreviews are temporary: up to {RETENTION_DAYS} days, subject to the "
            f"{MAX_PREVIEWS}-preview site limit. This comment updates after successful deployments.")


def comment(api, report_path, base_url):
    report = json.loads(report_path.read_text())
    newest = {}
    for preview in report["previews"]:
        newest.setdefault(preview["number"], preview)
    # Refresh every existing preview comment, including expired and closed PRs.
    comments = list(api.pages("/issues/comments?sort=updated&direction=desc"))
    existing = {}
    for item in comments:
        if item["user"]["login"] == "github-actions[bot]" and item["body"].startswith(MARKER):
            number = int(item["issue_url"].rsplit("/", 1)[1])
            existing.setdefault(number, item)
    summary = []
    for number in sorted(newest.keys() | existing.keys()):
        pull = api.request(f"/pulls/{number}")
        preview = newest.get(number)
        if preview and pull["state"] == "open":
            body = preview_comment(preview, base_url, pull["head"]["sha"])
            summary.append(f"- PR #{number}: [Play {preview['sha'][:8]}]({base_url.rstrip('/')}/{preview['path']})")
        else:
            body = f"{MARKER}\n### Game preview expired\n\nThis preview was removed after the PR closed or the retention limit was reached. Push a new commit or rerun the PR build to request a new preview."
        if number in existing:
            if existing[number]["body"] != body:
                api.request(f"/issues/comments/{existing[number]['id']}", "PATCH", {"body": body})
        elif preview and pull["state"] == "open":
            api.request(f"/issues/{number}/comments", "POST", {"body": body})
    with open(os.environ.get("GITHUB_STEP_SUMMARY", os.devnull), "a") as stream:
        stream.write("## Published game previews\n\n" + ("\n".join(summary) or "No active previews.") + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["assemble", "comment"])
    parser.add_argument("--output", type=Path, default=Path("_site"))
    parser.add_argument("--report", type=Path, default=Path("preview-report.json"))
    parser.add_argument("--base-url")
    args = parser.parse_args()
    api = GitHub()
    if args.command == "assemble":
        assemble(api, args.output, args.report)
    else:
        if not args.base_url:
            parser.error("comment requires --base-url")
        comment(api, args.report, args.base_url)


if __name__ == "__main__":
    main()
