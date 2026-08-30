#!/usr/bin/env bash
# check-commit-message.sh - validate a commit subject follows Conventional Commits,
# and enforce that release-triggering types touch product code.
#
# Source of truth: paragon-stats/github-actions. Consumers that need this in a git
# hook vendor a pinned copy and verify it against the tagged upstream in CI; edit
# it here, never in the copy.
#
# Inputs are environment variables so the same file serves the composite action
# and a local hook:
#   MESSAGE_FILE   path to the commit message (or PR title)   [required]
#   CHANGED_PATHS  space/newline separated changed paths      [default: empty]
#   TYPES          pipe-separated Conventional Commit types
#   PRODUCT_PATH   path prefix holding product code           [default: src/]
set -euo pipefail

MESSAGE_FILE="${MESSAGE_FILE:-}"
CHANGED_PATHS="${CHANGED_PATHS:-}"
TYPES="${TYPES:-feat|fix|docs|chore|ci|refactor|test|perf|style|build|revert}"
PRODUCT_PATH="${PRODUCT_PATH:-src/}"

if [ -z "$MESSAGE_FILE" ] || [ ! -f "$MESSAGE_FILE" ]; then
  echo "usage: MESSAGE_FILE=<file> [CHANGED_PATHS=...] check-commit-message.sh" >&2
  exit 2
fi

# First non-blank, non-comment line is the subject. The `|| true` absorbs the
# SIGPIPE head induces on a long message.
subject="$(grep -vE '^[[:space:]]*(#|$)' "$MESSAGE_FILE" | head -n 1 || true)"
# A UTF-8 BOM is plausible from Windows editors and would break the anchor below.
subject="${subject#$'\xef\xbb\xbf'}"
if [ -z "$subject" ]; then
  echo "commit message is empty" >&2
  exit 1
fi

# git's own generated subjects are not Conventional Commits.
case "$subject" in
  "Merge "*|"Revert "*|"fixup!"*|"squash!"*)
    echo "Exempt subject: $subject"
    exit 0
    ;;
esac

if ! printf '%s' "$subject" | grep -qE "^($TYPES)(\([[:alnum:]._/ -]+\))?!?: .+"; then
  {
    echo "Commit subject is not a Conventional Commit:"
    echo "  $subject"
    echo "Expected: type(scope): subject   (types: ${TYPES//|/, })"
  } >&2
  exit 1
fi

# Type is the leading run of letters. Deliberately NOT a regex re-match against
# TYPES: with a trailing .* every alternative matches at the same length, so sed
# returns the first alternative rather than the right one, misreading `feature:`
# as `feat` whenever one type is a prefix of another. The subject is already
# validated above, so the leading letters are the type.
type="${subject%%[^[:alpha:]]*}"

# Release-triggering types must change product code. Skipped when the caller
# passes no paths - including a value that is only whitespace, which is what an
# unstripped `git diff --name-only` yields when nothing is staged.
if { [ "$type" = "feat" ] || [ "$type" = "fix" ]; } && [ -n "${CHANGED_PATHS//[[:space:]]/}" ]; then
  # Normalise Windows separators; a local hook passes native paths.
  normalised="${CHANGED_PATHS//\\//}"
  # Word-splitting is intended so each path is its own line; globbing is NOT -
  # an unquoted path containing * would otherwise re-resolve against the CWD.
  set -f
  # grep must consume all input: -q exits at the first match, and on a large PR
  # the unread remainder gives printf a SIGPIPE that pipefail turns into "no
  # match", rejecting a commit that did touch product code.
  # shellcheck disable=SC2086
  if ! printf '%s\n' $normalised | grep -E "^$PRODUCT_PATH" >/dev/null; then
    {
      echo "'$type:' changes nothing under $PRODUCT_PATH (product code):"
      echo "  $subject"
      echo "feat/fix bump the version and must touch $PRODUCT_PATH."
      echo "Use ci:/chore:/docs:/test:/build:/refactor: for tooling, docs, tests, or CI."
    } >&2
    exit 1
  fi
  set +f
fi

echo "OK: $subject"
