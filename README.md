# github-actions

Reusable composite Actions shared across the `paragon-stats` org.

One implementation per concern, called from every repo that needs it, so the
same rule cannot drift between repos written in different languages.

## Actions

| Action | Purpose |
| --- | --- |
| [`check-commit-message`](check-commit-message/) | Validate a commit subject follows Conventional Commits, and that release-triggering types touch product code. |
| [`branch-name`](branch-name/) | Validate a branch name follows `<type>/<issue#>-<short-kebab-summary>`. |

## Usage

Pin by tag:

```yaml
- uses: paragon-stats/github-actions/branch-name@v1
  with:
    branch: ${{ github.event.pull_request.head.ref }}
```

```yaml
- uses: paragon-stats/github-actions/check-commit-message@v1
  with:
    message-file: /tmp/commit-msg.txt
    changed-paths: ${{ steps.changed.outputs.paths }}
```

Every input has a default, so a repo only passes what differs from it. The
accepted type set lives in the `types` input; `check-commit-message` also takes
`product-path`, which is `src/` by default and must be set by repos that keep
product code elsewhere.

## Design

Composite bash, not container actions: these need only `bash`, `grep`, and
`sed`, all present on every runner. An image would add supply-chain surface for
nothing. Container actions are reserved for tools absent from the runner, and
are built `FROM scratch` around a single static binary when they are needed.

## License

Apache-2.0.
