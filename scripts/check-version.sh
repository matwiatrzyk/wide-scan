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

readarray -t V <<<"$VERSIONS"
printf 'package.json                        : %s\n' "${V[0]}"
printf 'marketplace.json metadata.version   : %s\n' "${V[1]}"
printf 'marketplace.json plugins[0].version : %s\n' "${V[2]}"
printf 'plugin.json      version            : %s\n' "${V[3]}"

for v in "${V[@]}"; do
  if [ "$v" != "${V[0]}" ]; then
    echo "ERROR: versions disagree" >&2
    exit 1
  fi
done

if [ -n "$EXPECTED" ] && [ "$EXPECTED" != "${V[0]}" ]; then
  echo "ERROR: expected $EXPECTED but the manifests say ${V[0]}" >&2
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

echo "check: ok (${V[0]}, $(ls -d plugins/legacy-context/skills/*/ | wc -l | tr -d ' ') skills)"
