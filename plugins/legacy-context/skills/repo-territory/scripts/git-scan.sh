#!/usr/bin/env bash
# git-scan.sh - deterministic git-history signals for the territory map.
#
# Usage:
#   git-scan.sh dirs      [path]    top N most-changed directories
#   git-scan.sh files     [path]    top N most-changed files
#   git-scan.sh quarters  [path]    full quarter matrix for the globally top N directories
#   git-scan.sh cochange  [path]    directory pairs changed in the same commits
#   git-scan.sh hub       [path]    files that co-change with many different areas
#   git-scan.sh alive < paths       which paths still exist at HEAD
#
# Environment:
#   SINCE="12 months ago"   time window
#   TOP=10                  how many rows / how many directories in the matrix
#   DEPTH=2                 directory levels to show BELOW the scope path (see note)
#   MAXFILES=100            commits touching more files are skipped (mass rename/reformat)
#   NOISE="regex"           extra noise filter, appended to the default one
#
# DEPTH is relative to the scope, not to the repo root. `dirs .` with DEPTH=2 yields
# nodes like src/payments; `dirs src/ui` with DEPTH=2 yields src/ui/<a>/<b>. Without
# this, scoping a scan would collapse every path into one useless row.
#
# Output is TSV so it pastes straight into an artifact and stays easy to post-process.

set -uo pipefail

SINCE="${SINCE:-12 months ago}"
TOP="${TOP:-10}"
DEPTH="${DEPTH:-2}"
MAXFILES="${MAXFILES:-100}"

DEFAULT_NOISE='(^|/)(package-lock\.json|pnpm-lock\.yaml|yarn\.lock|poetry\.lock|Cargo\.lock|go\.sum|composer\.lock|Gemfile\.lock|\.env[^/]*)$'
DEFAULT_NOISE="$DEFAULT_NOISE"'|(^|/)(node_modules|dist|build|out|vendor|target|__snapshots__|\.venv|coverage)/'
DEFAULT_NOISE="$DEFAULT_NOISE"'|\.(snap|lock|min\.js|min\.css|svg|png|jpg|jpeg|gif|ico|woff2?|map)$'
DEFAULT_NOISE="$DEFAULT_NOISE"'|(^|/)(i18n|locales?|translations)/|\.(po|mo)$'
DEFAULT_NOISE="$DEFAULT_NOISE"'|\.generated\.|_pb2\.py$|\.pb\.go$|\.g\.dart$|\.d\.ts$'

NOISE_RE="$DEFAULT_NOISE"
if [ -n "${NOISE:-}" ]; then NOISE_RE="$NOISE_RE|$NOISE"; fi

CMD="${1:-}"
SCOPE="${2:-.}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: run this inside a git repository." >&2
  exit 1
fi

if [ "$(git rev-parse --is-shallow-repository 2>/dev/null)" = "true" ]; then
  echo "Warning: shallow clone - history is truncated. Record this as a limitation of the map." >&2
fi

# Path segments in the scope, so DEPTH can mean "levels below the scope".
scope_clean="${SCOPE#./}"
scope_clean="${scope_clean%/}"
if [ "$scope_clean" = "." ] || [ -z "$scope_clean" ]; then
  SCOPE_SEGMENTS=0
else
  SCOPE_SEGMENTS=$(printf '%s' "$scope_clean" | tr -cd '/' | wc -c)
  SCOPE_SEGMENTS=$((SCOPE_SEGMENTS + 1))
fi
EFFECTIVE_DEPTH=$((SCOPE_SEGMENTS + DEPTH))
if [ "$SCOPE_SEGMENTS" -gt 0 ]; then
  echo "Note: scope '$scope_clean' - grouping paths at depth $EFFECTIVE_DEPTH (DEPTH=$DEPTH below the scope)." >&2
fi

# Raw stream: '---<sha>' starts a commit, then its file paths.
raw_log() {
  git log --since="$SINCE" --no-merges --pretty=format:'---%H' --name-only -- "$SCOPE" 2>/dev/null
}

# Collapses a file path into a directory node of depth `depth`.
to_dir_awk='function todir(p,   n,i,out,a,cnt) {
  cnt = split(p, a, "/");
  if (cnt == 1) return "(root)";
  n = (cnt - 1 < depth) ? cnt - 1 : depth;
  out = a[1];
  for (i = 2; i <= n; i++) out = out "/" a[i];
  return out;
}'

case "$CMD" in

  files)
    raw_log \
      | grep -v '^---' | grep -v '^$' \
      | grep -Ev "$NOISE_RE" \
      | sort | uniq -c | sort -rn | head -n "$TOP" \
      | awk '{c=$1; $1=""; sub(/^ /,""); print c "\t" $0}'
    ;;

  dirs)
    raw_log \
      | grep -v '^---' | grep -v '^$' \
      | grep -Ev "$NOISE_RE" \
      | awk -v depth="$EFFECTIVE_DEPTH" "$to_dir_awk"' {print todir($0)}' \
      | sort | uniq -c | sort -rn | head -n "$TOP" \
      | awk '{c=$1; $1=""; sub(/^ /,""); print c "\t" $0}'
    ;;

  quarters)
    # Pick the globally most active directories FIRST, then print every quarter for
    # each of them - including zeros. Taking a separate top N per quarter would let a
    # year-round area drop out of one quarter's ranking and look seasonal.
    git log --since="$SINCE" --no-merges --date=format:'%Y-%m' \
        --pretty=format:'---%ad' --name-only -- "$SCOPE" 2>/dev/null \
      | grep -Ev "$NOISE_RE" \
      | awk -v depth="$EFFECTIVE_DEPTH" -v top="$TOP" "$to_dir_awk"'
        /^---/ {
          ym = substr($0, 4); split(ym, parts, "-");
          q = parts[1] "-Q" int((parts[2] + 2) / 3);
          quarters[q] = 1;
          next
        }
        NF == 0 { next }
        {
          dir = todir($0);
          cnt[q SUBSEP dir]++;
          total[dir]++;
        }
        END {
          # Selection sort over totals - portable (no gawk asorti), and top is small.
          nd = 0; for (key in total) { nd++; name[nd] = key }
          if (nd == 0) exit;
          limit = (top < nd) ? top : nd;
          for (i = 1; i <= limit; i++) {
            best = i;
            for (j = i + 1; j <= nd; j++)
              if (total[name[j]] > total[name[best]]) best = j;
            tmp = name[i]; name[i] = name[best]; name[best] = tmp;
          }
          nq = 0; for (q2 in quarters) { nq++; qs[nq] = q2 }
          for (i = 1; i <= nq; i++)            # ascending quarter order
            for (j = i + 1; j <= nq; j++)
              if (qs[j] < qs[i]) { tmp = qs[i]; qs[i] = qs[j]; qs[j] = tmp }
          for (i = 1; i <= limit; i++) {
            dir = name[i];
            line = dir "\t" total[dir];
            for (j = 1; j <= nq; j++) {
              k = qs[j] SUBSEP dir;
              line = line "\t" qs[j] ":" (k in cnt ? cnt[k] : 0)
            }
            print line
          }
        }'
    ;;

  cochange)
    raw_log \
      | grep -Ev "$NOISE_RE" \
      | awk -v depth="$EFFECTIVE_DEPTH" -v maxfiles="$MAXFILES" "$to_dir_awk"'
        function flush(   i, j, n, arr, tmp, a, b) {
          n = 0; for (d in seen) { n++; arr[n] = d }
          if (n < 2 || nfiles > maxfiles) { delete seen; nfiles = 0; return }
          for (i = 1; i <= n; i++) for (j = i + 1; j <= n; j++) {
            a = arr[i]; b = arr[j];
            if (a > b) { tmp = a; a = b; b = tmp }
            pair[a " + " b]++
          }
          delete seen; nfiles = 0
        }
        /^---/ { flush(); next }
        NF == 0 { next }
        { seen[todir($0)] = 1; nfiles++ }
        END { flush(); for (p in pair) print pair[p] "\t" p }' \
      | sort -rn | head -n "$TOP"
    ;;

  hub)
    # Exploratory signal, not proof of an architectural hub: it counts how many
    # distinct areas a file has ever shared a commit with. Verify before concluding.
    raw_log \
      | grep -Ev "$NOISE_RE" \
      | awk -v depth="$EFFECTIVE_DEPTH" -v maxfiles="$MAXFILES" "$to_dir_awk"'
        function flush(   f, d) {
          if (nfiles <= maxfiles)
            for (f in files) for (d in dirs) link[f SUBSEP d] = 1
          delete files; delete dirs; nfiles = 0
        }
        /^---/ { flush(); next }
        NF == 0 { next }
        { files[$0] = 1; dirs[todir($0)] = 1; nfiles++ }
        END {
          flush();
          for (k in link) { split(k, a, SUBSEP); reach[a[1]]++ }
          for (f in reach) if (reach[f] > 1) print reach[f] "\t" f
        }' \
      | sort -rn | head -n "$TOP"
    ;;

  alive)
    while IFS= read -r p; do
      [ -z "$p" ] && continue
      if git ls-files --error-unmatch "$p" >/dev/null 2>&1 || [ -d "$p" ]; then
        printf 'ALIVE\t%s\n' "$p"
      else
        last=$(git log -1 --pretty=format:'%h %ad' --date=short -- "$p" 2>/dev/null)
        printf 'GONE\t%s\t(last commit: %s)\n' "$p" "${last:-none found}"
      fi
    done
    ;;

  *)
    sed -n '2,24p' "$0"
    exit 1
    ;;
esac
