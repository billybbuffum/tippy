#!/usr/bin/env bash
# Keeps the media the UI smoke workflow attaches to pull request comments
# on the orphan `pr-media` branch, one directory per pull request (GitHub
# only renders images it hosts itself in a private repo). The branch is
# rewritten as a single commit on every run, with this PR's directory
# replaced and the others kept, so it never grows past the current set of
# open pull requests. Used by .github/workflows/ui-smoke.yml.
#
#   scripts/ui-smoke-publish.sh put <dir> <name>     replace <name>/ on the branch with <dir>'s files
#   scripts/ui-smoke-publish.sh remove <name>        drop <name>/ (the pull request was closed)
#
# Needs GH_TOKEN (or GITHUB_TOKEN) with contents: write, and
# GITHUB_REPOSITORY. `put` prints the base URL of the directory, in the form
# GitHub renders inline: https://github.com/<owner>/<repo>/blob/pr-media/<name>
# (append /<file>?raw=true).
set -euo pipefail

COMMAND=${1:?usage: ui-smoke-publish.sh put <dir> <name> | remove <name>}
case "$COMMAND" in
  put)
    DIR=${2:?source directory}
    NAME=${3:?name on the branch}
    [ -d "$DIR" ] || { echo "error: $DIR is not a directory" >&2; exit 1; }
    DIR=$(cd "$DIR" && pwd)
    ;;
  remove)
    DIR=""
    NAME=${2:?name on the branch}
    ;;
  *) echo "error: unknown command $COMMAND" >&2; exit 1 ;;
esac
case "$NAME" in */*|.*|"") echo "error: bad name $NAME" >&2; exit 1 ;; esac
REPO=${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is not set}
TOKEN=${GH_TOKEN:-${GITHUB_TOKEN:?GH_TOKEN is not set}}
BRANCH=pr-media

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

for attempt in 1 2 3; do
  rm -rf "$WORK/repo"
  mkdir "$WORK/repo"
  cd "$WORK/repo"
  git init -q
  git config user.name "github-actions[bot]"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  git remote add origin "https://x-access-token:${TOKEN}@github.com/${REPO}.git"
  OLD=""
  if git fetch -q --depth 1 origin "$BRANCH" 2> /dev/null; then
    OLD=$(git rev-parse FETCH_HEAD)
    git checkout -q FETCH_HEAD -- .
  fi
  # Files from the first version of this branch (one GIF per PR at the
  # top level) are dropped as they are met.
  rm -f ./*.gif
  cat > README.md <<'EOF'
# pr-media

Media the UI smoke workflow (`.github/workflows/ui-smoke.yml`) attaches to
pull request comments: one directory per open pull request (`pr-<n>/`,
one GIF per scenario), replaced on every run and removed when the pull
request closes. This branch is rewritten as a single commit each time, so
it holds no history and never grows past the current files. Do not base
work on it.
EOF
  rm -rf "./$NAME"
  if [ -n "$DIR" ]; then
    mkdir -p "./$NAME"
    cp "$DIR"/* "./$NAME/" 2> /dev/null || true
  fi
  git add -A
  if git diff --cached --quiet && [ -n "$OLD" ]; then
    echo "nothing to change on $BRANCH" >&2
    break
  fi
  git commit -q -m "UI smoke media: $COMMAND $NAME" -m "The branch is always one commit; see README.md."
  if [ -n "$OLD" ]; then
    git push -q --force-with-lease="refs/heads/$BRANCH:$OLD" origin "HEAD:refs/heads/$BRANCH" && break
  else
    git push -q origin "HEAD:refs/heads/$BRANCH" && break
  fi
  echo "push rejected (attempt $attempt), retrying" >&2
  sleep 3
  [ "$attempt" -lt 3 ] || { echo "error: could not push to $BRANCH" >&2; exit 1; }
done

if [ "$COMMAND" = put ]; then
  echo "https://github.com/${REPO}/blob/${BRANCH}/${NAME}"
fi
