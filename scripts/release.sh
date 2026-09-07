#!/usr/bin/env bash
# release.sh <new-version>
#
# Bumps the version everywhere, validates, commits, tags and pushes. The tag push
# is the trigger: it fires both workflows (GitHub Release + npm publish).
#
#   ./scripts/release.sh 1.1.0
#
set -euo pipefail

VERSION="${1:?usage: release.sh <new-version>   e.g. release.sh 1.1.0}"

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "ERROR: '$VERSION' is not semver (X.Y.Z)" >&2; exit 1; }

[ -z "$(git status --porcelain)" ] || {
  echo "ERROR: working tree is dirty - commit or stash first" >&2
  git status --short; exit 1; }

git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null && {
  echo "ERROR: tag v$VERSION already exists" >&2; exit 1; } || true

grep -q "^## \[$VERSION\]" CHANGELOG.md || {
  echo "ERROR: CHANGELOG.md has no '## [$VERSION]' section." >&2
  echo "Release notes are generated from it - write the entry first." >&2
  exit 1; }

python3 - "$VERSION" <<'PY'
import json, pathlib, sys
version = sys.argv[1]

p = pathlib.Path("package.json")
d = json.loads(p.read_text()); d["version"] = version
p.write_text(json.dumps(d, indent=2) + "\n")

m = pathlib.Path(".claude-plugin/marketplace.json")
d = json.loads(m.read_text())
d.setdefault("metadata", {})["version"] = version
for entry in d["plugins"]:
    entry["version"] = version
m.write_text(json.dumps(d, indent=2) + "\n")

pl = pathlib.Path("plugins/legacy-context/.claude-plugin/plugin.json")
d = json.loads(pl.read_text()); d["version"] = version
pl.write_text(json.dumps(d, indent=2) + "\n")

print(f"bumped to {version}")
PY

bash scripts/check-version.sh "$VERSION"

git add package.json .claude-plugin/marketplace.json \
        plugins/legacy-context/.claude-plugin/plugin.json CHANGELOG.md
git commit -m "release: v$VERSION"
git tag -a "v$VERSION" -m "wide-scan v$VERSION"
git push origin HEAD
git push origin "v$VERSION"

echo
echo "Pushed v$VERSION. Two workflows are now running:"
echo "  release  -> GitHub Release with notes from CHANGELOG.md"
echo "  publish  -> npm publish to GitHub Packages"
echo
echo "Verify:  gh release list && gh api /user/packages/npm/wide-scan/versions --jq '.[].name'"
