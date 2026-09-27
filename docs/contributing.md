# Contributing

This is a community-made game. Ideas, bug reports, art, and code contributions
are welcome. Discuss larger changes in an issue before starting so we can agree
on the direction together.

1. Fork or clone the repository and create a branch for your change.
2. Use Godot **4.7.2 (standard edition)**. Open `project.godot` and press **F5**.
3. Keep changes focused and check the Web export using the steps below.
4. Open a pull request targeting **`master`**. Explain the change and how you
   tested it; screenshots help for visual changes.

Every feature branch push and pull request targeting `master` automatically
builds the browser version. A TFPP member merges the pull request after the
**Build web export** check passes against the current `master`. If `master`
changes, update your branch and let the checks run again. Merging publishes the
result to GitHub Pages.

After a successful PR build, **Publish game and PR previews** publishes a playable
preview and adds or updates a **Playable game preview** comment on the PR. Click
**Play this build** in that comment to test on desktop or mobile before approving.
The link identifies the PR commit and build attempt; the game also displays the
PR commit alongside master in its watermark. Failed builds do not replace the
last successful preview.

Maintainers must enable the [branch protection settings](branch-protection.md)
on GitHub to enforce this merge policy.

Use GDScript if adding scripts, and keep the Compatibility renderer and
single-threaded Web export working. Commit source assets and Godot `.uid` and
`.import` metadata, but leave `.godot/` and `build/` out of commits.

The current scene is a first-person movement playground. See
[controls and movement](controls.md) for bindings, tuning, and mobile behavior.

## Run locally

1. Install **Godot 4.7.2 (standard edition)**, matching the version pinned in CI.
2. Import `project.godot` in Godot.
3. Run `python3 tools/write_build_info.py` to stamp the locally known master revision.
4. Press **F5**, then click/tap to play or press the gamepad's bottom face button.

## Build for the browser

Install the matching export templates via **Editor → Manage Export Templates**.
Then select **Project → Export → Web → Export Project**, or run these commands
from the repository root with `godot` on your PATH:

```sh
python3 tools/write_build_info.py
godot --headless --path . --editor --import
godot --headless --path . tests/controller_test.tscn
mkdir -p build/web
godot --headless --path . --export-release Web build/web/index.html
python3 -m http.server 8000 --directory build/web
```

Open <http://localhost:8000>. Serve the files over HTTP; opening `index.html`
directly from disk will not work. Generated files in `build/` are ignored by Git.

The project uses the Compatibility renderer and a single-threaded Web export.
This supports GitHub Pages without special cross-origin isolation headers. The
browser needs WebGL 2.0 and WebAssembly. See the
[Godot web export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html).

For a phone on the same Wi-Fi network, open `http://<your-computer-LAN-IP>:8000`.
Use the HTTPS GitHub Pages URL to test Home Screen installation. Test both
portrait and landscape, moving/looking/jumping together, focus loss, and gamepad
connect/disconnect. Browser emulation does not replace an actual iPhone/Android
device check.

The lower-right watermark shows `master / <8-character hash>` from build-time
metadata. CI stamps the deployed commit on master; feature and PR builds show
the fetched `origin/master` revision. PR builds additionally show their PR number
and head commit; `build_hash` records the proposed merge commit actually tested.
Local stamps use the locally known
`origin/master` (or `master` if no remote ref exists), so fetch first if you need
the latest remote revision. Missing metadata shows `master / unstamped dev`.
`build_info.json` is generated, ignored by Git, and explicitly included in Web
exports. Re-run the stamp before a manual export after updating master.

## Automatic GitHub Pages deployment

One-time repository setup:

1. Push this project to a GitHub repository with **`master`** as its default branch.
2. In **Settings → Pages → Build and deployment**, set **Source** to
   **GitHub Actions**.
3. Merge a pull request into `master`, push to `master`, or run **Build and deploy
   web game** manually from the Actions tab with `master` selected.

The [workflow](../.github/workflows/pages.yml) downloads Godot 4.7.2 and its official
export templates, verifies their release checksums, imports the project, runs a
short headless smoke test, and exports the Web build. Every branch push (including
names such as `feature/my-change`) and pull requests targeting `master` run these
build checks. Successful master and PR builds upload a `web-build` artifact.
The separate [publishing workflow](../.github/workflows/publish-pages.yml) runs
after successful builds and uses GitHub's built-in token to publish and comment;
no personal access token or repository secret is needed.

The publisher assembles one complete Pages site: the latest retained successful
master build at `/game/`, and previews at
`/game/previews/pr-<number>/<full-head-sha>/<run-id>-<attempt>/`. Separate paths
prevent one preview's cached game files from being reused by another build.
Re-running a build gets a new path even if the PR head commit has not changed.
The publisher always runs trusted code from `master`; it only copies validated
export files from PR artifacts and never executes those artifacts on the runner.
Fork PRs use this same flow after GitHub's normal workflow-approval requirements.

Preview retention is **14 days**, at most **12 recent PR commit previews**, with
a **700 MiB** total site budget. The newest successful attempt for each PR commit
is kept. Closed PRs and expired previews are removed at the next publication or
the daily cleanup run. PR comments are updated after a successful deployment,
including retiring expired links. The publisher reconstructs the full site under
one concurrency group, so simultaneous PR builds preserve production and other
retained previews. The constants are in `tools/publish_previews.py`.

**Initial activation:** the publishing workflow must first be merged into the
default branch (`master`), as required for GitHub's `workflow_run` trigger. Its
first successful master build seeds production. Then push a new PR commit or
rerun an existing PR build that includes the `web-build` upload step. This setup
PR cannot activate its own publisher before it is merged. If master build
artifacts eventually expire, run **Build and deploy web game** on master to
refresh them; publishing fails safely rather than deleting the live game.

For a deployment/comment failure, rerun **Publish game and PR previews** on
master. The build check remains separate from publication; do not require the
publishing workflow as a pre-merge check. Both workflows must be enabled, and
organization policies must allow the publisher's declared token permissions.

Publisher logic can be checked locally without tokens or network access:
`python3 -m unittest discover -s tests -p 'test_*.py'`.

The deployment URL appears in the workflow's `github-pages` environment and in
**Settings → Pages**. The default URL for this repository is
[https://tfpp.github.io/game/](https://tfpp.github.io/game/).

If the repository restricts deployment environments, allow `master` to deploy
to `github-pages`. See [GitHub's custom Pages workflow documentation](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).

## Protecting master

The required build check is named **Build web export**. GitHub must also be
configured to require this check before merging and restrict merges to TFPP
members. Workflow files alone do not enforce branch protection. Follow the
[branch protection setup](branch-protection.md) after creating the repository
and publishing its initial `master` branch.

See [the project overview](project.md) for more context.
