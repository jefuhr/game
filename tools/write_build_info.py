"""Stamp the master revision known at build time; never guess it from a feature HEAD."""

import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def revision(ref: str) -> str | None:
    result = subprocess.run(
        ["git", "rev-parse", "--verify", f"{ref}^{{commit}}"],
        cwd=ROOT, capture_output=True, text=True, check=False,
    )
    return result.stdout.strip() if result.returncode == 0 else None


def main() -> None:
    # A master deployment must identify its own build, even if master advances later.
    if os.environ.get("GITHUB_REF") == "refs/heads/master":
        master = revision(os.environ.get("GITHUB_SHA", "HEAD"))
    else:
        master = revision("refs/remotes/origin/master") or revision("refs/heads/master")
    if not master:
        raise SystemExit("Cannot resolve master. Fetch origin master before stamping this build.")
    metadata = {"master_hash": master, "build_hash": revision("HEAD")}
    if os.environ.get("GITHUB_EVENT_NAME") == "pull_request":
        event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text())
        metadata["preview_hash"] = event["pull_request"]["head"]["sha"]
        metadata["pr_number"] = event["number"]
    (ROOT / "build_info.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(f"Watermark: master {master[:8]}")


if __name__ == "__main__":
    main()
