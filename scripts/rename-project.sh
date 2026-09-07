#!/usr/bin/env bash
# rename-project.sh <new-name> [env-prefix]
#
# Swaps the project name everywhere it appears: package name, marketplace name,
# repository URLs, the consumer-side manifest filename, the installer's log
# prefix and its environment variables.
#
# Deliberately does NOT touch the plugin name (`legacy-context`) or the skill
# directories - those name the content, not the project.
#
#   ./rename-project.sh wide-scan WS
#   ./rename-project.sh repo-bearings BRG
#
# Run it from the repo root, before the first push.
set -euo pipefail

NEW="${1:?usage: rename-project.sh <new-name> [env-prefix]}"
PREFIX="${2:-$(echo "$NEW" | tr 'a-z-' 'A-Z_' | cut -c1-3)}"

OLD="wide-scan"
OLD_PREFIX="WS"

[[ "$NEW" =~ ^[a-z0-9][a-z0-9-]*$ ]] || {
  echo "ERROR: '$NEW' must be lowercase letters, digits and hyphens (npm rules)." >&2
  exit 1; }

echo "$OLD -> $NEW    ${OLD_PREFIX}_* -> ${PREFIX}_*"

FILES=$(git ls-files 2>/dev/null || find . -type f -not -path "./.git/*" -not -path "./node_modules/*")

for f in $FILES; do
  case "$f" in
    LICENSE|*.tgz) continue ;;
  esac
  python3 - "$f" "$OLD" "$NEW" "$OLD_PREFIX" "$PREFIX" <<'PY'
import sys, pathlib
path, old, new, old_prefix, prefix = sys.argv[1:6]
p = pathlib.Path(path)
try:
    text = p.read_text()
except UnicodeDecodeError:
    sys.exit(0)
out = text.replace(old, new).replace(f"{old_prefix}_", f"{prefix}_")
if out != text:
    p.write_text(out)
    print(f"  {path}")
PY
done

echo
echo "Done. Verify with:"
echo "  bash scripts/check-version.sh"
echo "  grep -rn '$OLD' --exclude-dir=.git . || echo 'no leftovers'"
