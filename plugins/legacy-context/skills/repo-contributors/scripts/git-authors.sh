#!/usr/bin/env bash
# git-authors.sh - who actually worked on an area, and on what kind of problem.
#
# Usage:
#   git-authors.sh top     <path>          contributor ranking for the area
#   git-authors.sh topics  <path> [name]   commit subjects per author (classification input)
#   git-authors.sh recent  <path>          recent commits: sha, date, author, subject
#   git-authors.sh spread  <path>          knowledge concentration / bus factor signal
#
# Environment:
#   SINCE="12 months ago"  time window
#   TOP=8                  how many authors / rows
#   BOTS="regex"           extra author filter, appended to the default one
#
# The bot filter is applied to the AUTHOR FIELD ONLY. Filtering whole log lines would
# silently drop a human's commit whose subject happens to mention copilot, automation
# or a bot name - a silent failure that looks like valid data.
#
# Author identity uses %aN, so .mailmap consolidates the same person appearing under
# several names or addresses.

set -uo pipefail

SINCE="${SINCE:-12 months ago}"
TOP="${TOP:-8}"
DEFAULT_BOTS='\[bot\]|dependabot|renovate|greenkeeper|snyk|github-action|semantic-release|crowdin|weblate|transifex|noreply@|^claude$|^codex$|^copilot$|automation|ci-bot|release-bot'
BOTS_RE="$DEFAULT_BOTS"
if [ -n "${BOTS:-}" ]; then BOTS_RE="$BOTS_RE|$BOTS"; fi
# Passed through the environment, not -v: awk's -v processes backslash escapes and
# would turn \[bot\] into a character class.
export BOTS_RE

CMD="${1:-}"
SCOPE="${2:-.}"
WHO="${3:-}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: run this inside a git repository." >&2
  exit 1
fi

# git's --author is a regex, so names containing (), [], ., +, * silently match
# nothing. Escape them before passing the name through.
escape_re() {
  printf '%s' "$1" | sed 's/[][\.^$*+?(){}|\\]/\\&/g'
}

# Drops rows whose Nth tab-separated field looks like a bot.
drop_bots() {
  awk -F'\t' -v f="$1" 'BEGIN { re = ENVIRON["BOTS_RE"] } tolower($f) !~ re'
}

authors_ranked() {
  git log --since="$SINCE" --no-merges --pretty=format:'%aN' -- "$SCOPE" 2>/dev/null \
    | drop_bots 1 \
    | sort | uniq -c | sort -rn
}

case "$CMD" in

  top)
    authors_ranked | head -n "$TOP" \
      | awk '{c=$1; $1=""; sub(/^ /,""); print c "\t" $0}'
    ;;

  topics)
    if [ -n "$WHO" ]; then
      git log --since="$SINCE" --no-merges --author="$(escape_re "$WHO")" \
          --pretty=format:'%aN%x09%s' -- "$SCOPE" 2>/dev/null \
        | drop_bots 1 | head -n 40
    else
      # A sample of subjects per top author - raw input for thematic classification.
      authors_ranked | head -n "$TOP" | sed 's/^ *[0-9]* //' \
        | while IFS= read -r a; do
            printf '### %s\n' "$a"
            git log --since="$SINCE" --no-merges --author="$(escape_re "$a")" \
              --pretty=format:'  %ad %s' --date=short -- "$SCOPE" 2>/dev/null | head -n 15
            printf '\n\n'
          done
    fi
    ;;

  recent)
    git log --since="$SINCE" --no-merges --date=short \
        --pretty=format:'%h%x09%ad%x09%aN%x09%s' -- "$SCOPE" 2>/dev/null \
      | drop_bots 3 | head -n "$TOP"
    ;;

  spread)
    authors_ranked \
      | awk -v scope="$SCOPE" '
        { n++; total += $1; if (n == 1) { top = $1; sub(/^ *[0-9]+ */, ""); name = $0 } }
        END {
          if (total == 0) { print "no human commits in window for " scope; exit }
          printf "area\t%s\n", scope
          printf "unique authors\t%d\n", n
          printf "commits\t%d\n", total
          printf "top author\t%s (%d commits, %.0f%%)\n", name, top, top * 100 / total
          printf "signal\t%s\n", (top * 100 / total >= 60 ? \
            "concentrated - bus factor risk, one person holds most of the context" : \
            "distributed - likely nobody holds the full picture; read PRs too")
        }'
    ;;

  *)
    sed -n '2,22p' "$0"
    exit 1
    ;;
esac
