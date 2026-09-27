# Master branch protection

This is the intended repository policy. It only takes effect after a repository
administrator configures it on GitHub; committing this document does not enable it.

## Required configuration

After publishing the initial `master` branch and running the build workflow:

1. In the TFPP organization, choose or create a team containing the members who
   may merge. To include every TFPP member, keep the team's membership synchronized
   with the organization. Give that team **Write** access to this repository.
2. Open **Settings → Branches → Add classic branch protection rule** and set the
   branch name pattern to **`master`**.
3. Enable **Require a pull request before merging**. A separate approval count
   is optional; the initial policy requires a passing build and an authorized
   merger.
4. Enable **Require status checks to pass before merging** and select
   **Build web export**, with **GitHub Actions** as the expected source.
   Enable **Require branches to be up to date before merging** so the check
   covers the current target branch. If the check is missing from the selector,
   first let the workflow run successfully on GitHub.
5. Enable **Restrict who can push to matching branches** and select only the TFPP
   team from step 1. This also restricts who can merge pull requests. Do not add
   outside collaborators or apps to the allowed list.
6. Enable **Do not allow bypassing the above settings**. Leave pull request bypass
   allowances empty, and leave force pushes and branch deletion disabled.
7. Save the rule. Confirm an open pull request cannot merge while the build is
   pending or failing, and that a successful, up-to-date pull request can be
   merged by a permitted member.

GitHub's classic branch restrictions select users, teams, or apps, rather than
an organization URL. Organization membership alone also does not grant repository
write access. Keep access and the selected team's membership current as people
join or leave TFPP.

GitHub grants repository administrators push access to protected branches even
when actor restrictions are enabled. Keep administrator access limited to TFPP
members too. Enabling enforcement for administrators still requires them to
satisfy the pull request and build requirements.

## Workflow behavior

- Pushes to any branch run **Build web export**, including branch names with `/`.
- Pull requests into `master` run the same check on GitHub's proposed merge commit.
- Feature branch pushes validate builds; PR builds upload playable artifacts.
- **Publish game and PR previews** runs from `master` after successful builds.
  It publishes master at the site root and PR previews in separate subdirectories,
  then adds or updates the PR's clickable preview comment.
- Only successful master builds can change the production game. The publisher
  copies validated PR export files without executing PR code with write permissions.
- **Deploy production and PR previews** must not be a required pre-merge check:
  it runs in the separate publishing workflow, not as a check on the PR commit.
- Keep the `github-pages` environment restricted to `master`; PRs do not need
  permission to deploy directly. The publisher itself runs from the default branch.

Keep the **Build web export** job name stable, or update the required check in
GitHub when renaming it. Do not add path filters that could prevent a required
pull request check from running.

See GitHub's [protected branch documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches).
