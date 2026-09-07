#!/usr/bin/env node
/**
 * uninstall.mjs - removes exactly the paths recorded in .wide-scan.json.
 *
 * `npm uninstall` clears node_modules/ but knows nothing about the files the
 * installer scattered into .agents/, .claude/ and .cursor/. Without this step
 * those files outlive the dependency and nobody remembers which are still needed.
 *
 * Anything not listed in the manifest is left untouched, including your own
 * skills sitting in the same directories.
 *
 *   node scripts/uninstall.mjs            remove
 *   WS_DRY_RUN=1 node scripts/uninstall.mjs   show what would go
 */

import fs from "node:fs";
import path from "node:path";

const MANIFEST_NAME = ".wide-scan.json";
const DRY = process.env.WS_DRY_RUN === "1";
const log = (msg) => console.log(`[wide-scan] ${msg}`);

function findProjectRoot() {
  const initCwd = process.env.INIT_CWD;
  let dir = initCwd && fs.existsSync(initCwd) ? path.resolve(initCwd) : process.cwd();
  // The manifest lives at the project root; walk up until we find it.
  while (dir !== path.dirname(dir)) {
    if (fs.existsSync(path.join(dir, MANIFEST_NAME))) return dir;
    dir = path.dirname(dir);
  }
  return initCwd ? path.resolve(initCwd) : process.cwd();
}

/** Walk upward from a removed path, deleting directories we emptied. */
function pruneEmptyParents(root, startPath) {
  let dir = path.dirname(startPath);
  while (dir.startsWith(root + path.sep)) {
    let entries;
    try {
      entries = fs.readdirSync(dir);
    } catch {
      return;
    }
    if (entries.length > 0) return;
    if (!DRY) fs.rmdirSync(dir);
    dir = path.dirname(dir);
  }
}

function main() {
  const root = findProjectRoot();
  const manifestPath = path.join(root, MANIFEST_NAME);

  if (!fs.existsSync(manifestPath)) {
    log(`No ${MANIFEST_NAME} found - nothing installed by this package here.`);
    return;
  }

  let manifest;
  try {
    manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  } catch {
    log(`ERROR: ${MANIFEST_NAME} is corrupt. Refusing to guess which files are mine.`);
    log("Inspect and remove them by hand, then delete the manifest.");
    process.exitCode = 1;
    return;
  }

  if (!Array.isArray(manifest.paths)) {
    log(`ERROR: ${MANIFEST_NAME} has no paths array. Nothing removed.`);
    process.exitCode = 1;
    return;
  }

  let removed = 0;
  let missing = 0;

  for (const rel of manifest.paths) {
    const target = path.resolve(root, rel);
    if (!target.startsWith(root + path.sep)) {
      log(`Skipping ${rel} - outside the project root.`);
      continue;
    }
    const present = fs.existsSync(target) || (() => {
      try {
        return fs.lstatSync(target).isSymbolicLink();
      } catch {
        return false;
      }
    })();

    if (!present) {
      missing += 1;
      continue;
    }
    if (!DRY) fs.rmSync(target, { recursive: true, force: true });
    pruneEmptyParents(root, target);
    removed += 1;
    log(`${DRY ? "would remove" : "removed"} ${rel}`);
  }

  if (!DRY) fs.rmSync(manifestPath, { force: true });

  log(
    `${DRY ? "[dry run] " : ""}v${manifest.version}: ${removed} path(s) removed` +
      (missing > 0 ? `, ${missing} already gone` : "") +
      `. Manifest ${DRY ? "kept" : "deleted"}.`
  );
}

main();
