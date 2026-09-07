#!/usr/bin/env bash
# check-version.sh [expected-version]
#
# The version lives in four places: package.json, marketplace.json (metadata and
# the plugin entry) and plugin.json. Nothing in npm or Claude Code keeps them in
# step, so this does. CI passes the git tag as the expected version.
set -euo pipefail

EXPECTED="${1:-}"

VERSIONS="$(python3 - <<'PY'
import json
pkg = json.load(open("package.json"))
mp = json.load(open(".claude-plugin/marketplace.json"))
pl = json.load(open("plugins/legacy-context/.claude-plugin/plugin.json"))
print(pkg.get("version", "MISSING"))
print(mp.get("metadata", {}).get("version", "MISSING"))
print(mp["plugins"][0].get("version", "MISSING"))
print(pl.get("version", "MISSING"))
PY
)"

# Split on whitespace into positional parameters. `readarray` would be tidier but
# it needs bash 4; macOS still ships bash 3.2, and this script has to run there.
# Version strings never contain whitespace, so word splitting is safe here.
# shellcheck disable=SC2086
set -- $VERSIONS

if [ "$#" -ne 4 ]; then
  echo "ERROR: expected 4 version fields, got $#" >&2
  exit 1
fi

printf 'package.json                        : %s\n' "$1"
printf 'marketplace.json metadata.version   : %s\n' "$2"
printf 'marketplace.json plugins[0].version : %s\n' "$3"
printf 'plugin.json      version            : %s\n' "$4"

VERSION="$1"
for v in "$@"; do
  if [ "$v" != "$VERSION" ]; then
    echo "ERROR: versions disagree" >&2
    exit 1
  fi
done

if [ -n "$EXPECTED" ] && [ "$EXPECTED" != "$VERSION" ]; then
  echo "ERROR: expected $EXPECTED but the manifests say $VERSION" >&2
  exit 1
fi

# Manifests parse.
python3 -c "import json;[json.load(open(p)) for p in ['package.json','.claude-plugin/marketplace.json','plugins/legacy-context/.claude-plugin/plugin.json']]"

# Shipped shell scripts parse.
for s in plugins/legacy-context/skills/*/scripts/*.sh; do bash -n "$s"; done

# Every skill directory has a SKILL.md with frontmatter and a name field.
fail=0
for dir in plugins/legacy-context/skills/*/; do
  skill="${dir}SKILL.md"
  if [ ! -f "$skill" ]; then
    echo "ERROR: $dir has no SKILL.md" >&2; fail=1; continue
  fi
  if [ "$(head -1 "$skill")" != "---" ]; then
    echo "ERROR: $skill has no frontmatter" >&2; fail=1
  fi
  declared="$(sed -n '2,10p' "$skill" | sed -n 's/^name: *//p' | head -1)"
  expected="$(basename "$dir")"
  if [ "$declared" != "$expected" ]; then
    echo "ERROR: $skill declares name '$declared' but lives in '$expected'" >&2; fail=1
  fi
done
[ "$fail" -eq 0 ] || exit 1

# The npm package must actually contain the skills.
if ! grep -q '"plugins/"' package.json; then
  echo "ERROR: package.json files[] does not ship plugins/" >&2
  exit 1
fi

echo "check: ok (${VERSION}, $(ls -d plugins/legacy-context/skills/*/ | wc -l | tr -d ' ') skills)"
