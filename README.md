# TFPP Community Game

A fun, community-made Godot game by the TFPP community. This first milestone
establishes the project and browser deployment. The only scene is a blue cube on
a flat floor, with a light and camera, so we can verify that rendering works.
There are no gameplay mechanics yet.

## Run locally

1. Install **Godot 4.7.2 (standard edition)**, matching the version pinned in CI.
2. Import `project.godot` in Godot.
3. Press **F5**. You should see the cube and floor.

## Build for the browser

Install the matching export templates via **Editor → Manage Export Templates**.
Then select **Project → Export → Web → Export Project**, or run these commands
from the repository root with `godot` on your PATH:

```sh
godot --headless --path . --editor --import
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

## Automatic GitHub Pages deployment

One-time repository setup:

1. Push this project to a GitHub repository with **`master`** as its default branch.
2. In **Settings → Pages → Build and deployment**, set **Source** to
   **GitHub Actions**.
3. Merge a pull request into `master`, push to `master`, or run **Build and deploy
   web game** manually from the Actions tab with `master` selected.

The [workflow](.github/workflows/pages.yml) downloads Godot 4.7.2 and its official
export templates, verifies their release checksums, imports the project, runs a
short headless smoke test, and exports the Web build. Every branch push (including
names such as `feature/my-change`) and pull requests targeting `master` run these
build checks. Only `master` builds deploy to Pages, using
GitHub's built-in token; no personal access token or repository secret is needed.

The deployment URL appears in the workflow's `github-pages` environment and in
**Settings → Pages**. For a typical project repository it is
`https://<owner>.github.io/<repository>/`.

If the repository restricts deployment environments, allow `master` to deploy
to `github-pages`. See [GitHub's custom Pages workflow documentation](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).

## Protecting master

The required build check is named **Build web export**. GitHub must also be
configured to require this check before merging and restrict merges to TFPP
members. Workflow files alone do not enforce branch protection. Follow the
[branch protection setup](docs/branch-protection.md) after creating the repository
and publishing its initial `master` branch.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the basic workflow and
[docs/project.md](docs/project.md) for the project overview.
