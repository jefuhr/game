# Contributing

This is a community-made game. Ideas, bug reports, art, and code contributions
are welcome. Discuss larger changes in an issue before starting so we can agree
on the direction together.

1. Fork or clone the repository and create a branch for your change.
2. Use Godot **4.7.2 (standard edition)**. Open `project.godot` and press **F5**.
3. Keep changes focused and check the Web export using the steps in the README.
4. Open a pull request targeting **`master`**. Explain the change and how you
   tested it; screenshots help for visual changes.

Every feature branch push and pull request targeting `master` automatically
builds the browser version. A TFPP member merges the pull request after the
**Build web export** check passes against the current `master`. If `master`
changes, update your branch and let the checks run again. Merging publishes the
result to GitHub Pages.

Maintainers must enable the [branch protection settings](docs/branch-protection.md)
on GitHub to enforce this merge policy.

Use GDScript if adding scripts, and keep the Compatibility renderer and
single-threaded Web export working. Commit source assets and Godot `.uid` and
`.import` metadata, but leave `.godot/` and `build/` out of commits.

The initial milestone is deliberately small: a 3D test scene and deployment.
Future gameplay and creative direction will be decided together.
