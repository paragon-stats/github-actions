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

Pin at the granularity you want. `@latest`, `@vX`, and `@vX.Y` float to the
newest matching release (moved automatically on every release); `@vX.Y.Z` and
commit SHAs never move. Strictest wins for supply-chain caution: the org's own
repos pin `@<full-sha>  # vX.Y.Z`.

| Ref | Moves | You get |
| --- | --- | --- |
| `@<sha>  # vX.Y.Z` | never | exactly that commit (org house style) |
| `@vX.Y.Z` | never | exactly that release |
| `@vX.Y` | on patches | bug fixes only |
| `@vX` | on minors + patches | new features, no breaking changes |
| `@latest` | on every release | everything, including majors |

```yaml
- uses: paragon-stats/github-actions/branch-name@v2
  with:
    branch: ${{ github.event.pull_request.head.ref }}
```

```yaml
- uses: paragon-stats/github-actions/check-commit-message@v2
  with:
    message-file: /tmp/commit-msg.txt
    changed-paths: ${{ steps.changed.outputs.paths }}
```

Every input has a default, so a repo only passes what differs from it.
`check-commit-message` takes `product-path`, which is `src/` by default and must
be set by repos that keep product code elsewhere.

## Commit types

[`commit-types.txt`](commit-types.txt) is the org's single source of truth for
the accepted Conventional Commit types and the version bump each one triggers:

```
feat        minor
fix         patch
perf        patch
security    patch
revert      patch
```

...and `none` for `docs`, `chore`, `ci`, `refactor`, `test`, `style`, `build`.

Both actions read it when their `types` input is empty, so the list lives in one
tagged artifact instead of being restated per repo. Consumers declare their own
release config natively and diff it against this file in CI, so drift fails the
build rather than shipping.

Every type whose bump is not `none` must touch `product-path` -
`check-commit-message` derives that guard from the bump column, so a
workflow-hardening `security:` commit or a `perf:` tweak to CI that changes
nothing under `src/` cannot cut a release. A consequence: `revert(ci):` is
invalid - reverting a CI change is written as a `ci:` commit, and `revert` is
reserved for reverting product code. A repo that overrides `types` must
override `release-triggering-types` too - enforced with exit 2, since a bare
list carries no bump data. Patterns that do not compile also exit 2: a guard
never fails open on a typo'd regex.

Git's generated subjects (`Merge `, `Revert `, `fixup!`, `squash!`) are exempt
by default. A repo that wants hand-written `revert(scope):` subjects instead of
git's `Revert "…"` narrows `exempt-pattern` to drop `Revert `.

## Consumer notes

- A vendored copy of `check-commit-message.sh` (for a git hook) must vendor
  `commit-types.txt` beside it, or set `TYPES_FILE` to point at it.
- Vendoring from a Windows clone (`core.filemode=false`) records the script
  `100644`; run `git update-index --chmod=+x` on the vendored copy or invoke it
  via `bash`. The action path already invokes via `bash`.
- Consumers that delete their native validators depend on this repo's test
  matrix as their only coverage of commit validation. Removing matrix cases is
  a breaking change.

## Design

Composite bash, not container actions: these need only `bash`, `grep`, and
`sed`, all present on every runner. An image would add supply-chain surface for
nothing. Container actions are reserved for tools absent from the runner, and
are built `FROM scratch` around a single static binary when they are needed.

## License

Apache-2.0.
