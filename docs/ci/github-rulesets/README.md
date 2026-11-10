# GitHub rulesets

`main-ruleset.json` is the request body for the `main` branch ruleset.
The repository admin applies it by hand; nothing in CI changes repository settings.

## What the ruleset enforces

- No deletion of `main` and no non-fast-forward pushes.
- Signed commits.
- Pull requests only, merge commits only, with every review thread resolved before merge. No approving review is required.
- A pull request that introduces a CodeQL alert cannot merge.

The one bypass actor is the repository operator (user id 35460307) in `pull_request` mode, so the sole maintainer can merge their own pull requests.
Direct pushes to `main` stay blocked.

## Order

1. Merge the pull request that adds `.github/workflows/codeql.yml`.
2. Wait for the `codeql` run on `main` to finish. The Security tab then shows the analysis.
3. Create the ruleset.

The rule was observed on 2026-11-10 in a sibling repository: it is accepted on the Free plan for a public repository and judges only the alerts a pull request introduces, not the backlog on the base branch.
What it does for a pull request with no analysis at all was not established, which is why the analysis of `main` comes first.

## Create the ruleset

```bash
gh api -X POST repos/paragon-stats/github-actions/rulesets --input docs/ci/github-rulesets/main-ruleset.json
```

Read back the id:

```bash
gh api repos/paragon-stats/github-actions/rulesets --jq '.[] | select(.name=="main") | .id'
```

Later changes use `PUT` with that id:

```bash
gh api -X PUT repos/paragon-stats/github-actions/rulesets/<id> --input docs/ci/github-rulesets/main-ruleset.json
```

## Dismiss a deliberate alert

Open the alert on the Security tab under Code scanning, choose Dismiss alert, pick a reason and write a comment that says why the code is intentional.
A dismissed alert no longer blocks.

## Remove the ruleset

```bash
gh api -X DELETE repos/paragon-stats/github-actions/rulesets/<id>
```
