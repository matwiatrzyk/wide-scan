#!/usr/bin/env node
/**
 * install.mjs - lays the toolkit's artifacts out where each agent actually reads them.
 *
 * npm unpacks this package into node_modules/, which no agent looks at. This script
 * moves the artifacts to the directories the tools scan:
 *
 *   .agents/skills/<name>/    canonical copy - read natively by Cursor and Codex
 *   .claude/skills/<name>     symlink to the canonical copy - Claude Code only reads .claude/
 *   .claude/commands/*.md     slash commands (Claude Code syntax)
 *   .cursor/commands/*.md     same files, for Cursor's command palette
 *
 * Every path it writes is recorded in .wide-scan.json so that a later
 * install can replace exactly what it put there, and uninstall.mjs can remove it
 * without guessing. Files it did not create are never touched.
 *
 * Environment:
 *   WS_SKIP=1              skip installation entirely
 *   WS_DRY_RUN=1           print what would happen, write nothing
 *   WS_TARGETS=agents,claude,cursor    override the default target set
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const PKG_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const MANIFEST_NAME = ".wide-scan.json";
const ALL_TARGETS = ["agents", "claude", "cursor"];

const DRY = process.env.WS_DRY_RUN === "1";
const log = (msg) => console.log(`[wide-scan] ${msg}`);

// --- where does the consumer project live? --------------------------------

function findProjectRoot() {
  // npm sets INIT_CWD to the directory the user ran `npm install` from.
  const initCwd = process.env.INIT_CWD;
  if (initCwd && fs.existsSync(initCwd)) return path.resolve(initCwd);

  // Fallback: climb out of node_modules.
  let dir = PKG_ROOT;
  while (dir !== path.dirname(dir)) {
    if (path.basename(dir) === "node_modules") return path.dirname(dir);
    dir = path.dirname(dir);
  }
  return process.cwd();
}

// --- manifest -------------------------------------------------------------

function readManifest(root) {
  const file = path.join(root, MANIFEST_NAME);
  if (!fs.existsSync(file)) return null;
  try {
    const data = JSON.parse(fs.readFileSync(file, "utf8"));
    if (!Array.isArray(data.paths)) return null;
    return data;
  } catch {
    // A manifest we cannot read is a manifest we must not act on. Leaving the
    // files in place is recoverable; deleting paths we guessed at is not.
    log(`WARNING: ${MANIFEST_NAME} is unreadable - leaving previous files alone.`);
    return null;
  }
}

function writeManifest(root, version, paths, targets) {
  const body = {
    package: "@matwiatrzyk/wide-scan",
    version,
    installedAt: new Date().toISOString(),
    targets,
    paths: paths.map((p) => path.relative(root, p).split(path.sep).join("/")).sort(),
  };
  if (DRY) return;
  fs.writeFileSync(path.join(root, MANIFEST_NAME), JSON.stringify(body, null, 2) + "\n");
}

// --- filesystem helpers ---------------------------------------------------

function removeRecorded(root, manifest) {
  if (!manifest) return 0;
  let removed = 0;
  for (const rel of manifest.paths) {
    const target = path.join(root, rel);
    if (!target.startsWith(root + path.sep)) continue; // refuse to escape the project
    if (!fs.existsSync(target) && !isSymlink(target)) continue;
    if (!DRY) fs.rmSync(target, { recursive: true, force: true });
    removed += 1;
  }
  return removed;
}

function isSymlink(p) {
  try {
    return fs.lstatSync(p).isSymbolicLink();
  } catch {
    return false;
  }
}

function exists(p) {
  return fs.existsSync(p) || isSymlink(p);
}

function copyDir(src, dest) {
  if (DRY) return;
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.cpSync(src, dest, { recursive: true });
  // Skills ship bash helpers; they are useless without the execute bit.
  const scripts = path.join(dest, "scripts");
  if (fs.existsSync(scripts)) {
    for (const f of fs.readdirSync(scripts)) {
      if (f.endsWith(".sh")) fs.chmodSync(path.join(scripts, f), 0o755);
    }
  }
}

function copyFile(src, dest) {
  if (DRY) return;
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.copyFileSync(src, dest);
}

/** Symlink when the OS allows it, copy when it does not (Windows without dev mode). */
function linkOrCopy(src, dest) {
  if (DRY) return "link";
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  const rel = path.relative(path.dirname(dest), src);
  try {
    fs.symlinkSync(rel, dest, "junction");
    return "link";
  } catch {
    fs.cpSync(src, dest, { recursive: true });
    return "copy";
  }
}

// --- main -----------------------------------------------------------------

function main() {
  if (process.env.WS_SKIP === "1") {
    log("WS_SKIP=1 - skipping installation.");
    return;
  }

  const root = findProjectRoot();

  // Running `npm install` inside the toolkit repo itself must not install the
  // toolkit into the toolkit. Same guard covers CI builds of this package.
  if (path.resolve(root) === PKG_ROOT) {
    log("Running inside the source repo - nothing to install.");
    return;
  }

  const pkg = JSON.parse(fs.readFileSync(path.join(PKG_ROOT, "package.json"), "utf8"));
  const targets = (process.env.WS_TARGETS ?? ALL_TARGETS.join(","))
    .split(",")
    .map((t) => t.trim())
    .filter((t) => ALL_TARGETS.includes(t));

  if (targets.length === 0) {
    log(`No valid targets in WS_TARGETS. Valid: ${ALL_TARGETS.join(", ")}`);
    return;
  }

  const srcSkills = path.join(PKG_ROOT, "plugins", "legacy-context", "skills");
  const srcCommands = path.join(PKG_ROOT, "plugins", "legacy-context", "commands");

  if (!fs.existsSync(srcSkills)) {
    log("ERROR: the package is missing plugins/legacy-context/skills - not installing.");
    process.exitCode = 1;
    return;
  }

  const previous = readManifest(root);
  if (previous) {
    const n = removeRecorded(root, previous);
    if (n > 0) log(`Removed ${n} path(s) from v${previous.version}.`);
  }

  const written = [];
  const skipped = [];

  const skillNames = fs
    .readdirSync(srcSkills, { withFileTypes: true })
    .filter((e) => e.isDirectory() && fs.existsSync(path.join(srcSkills, e.name, "SKILL.md")))
    .map((e) => e.name);

  // 1. Canonical copy. Cursor and Codex read .agents/skills/ natively, so one
  //    real copy serves both and there is nothing to keep in sync.
  const wantsAgents = targets.includes("agents") || targets.includes("cursor");
  if (wantsAgents) {
    for (const name of skillNames) {
      const dest = path.join(root, ".agents", "skills", name);
      if (exists(dest)) {
        skipped.push(dest);
        continue;
      }
      copyDir(path.join(srcSkills, name), dest);
      written.push(dest);
    }
  }

  // 2. Claude Code only scans .claude/skills/, so point it at the canonical copy.
  if (targets.includes("claude")) {
    for (const name of skillNames) {
      const dest = path.join(root, ".claude", "skills", name);
      if (exists(dest)) {
        skipped.push(dest);
        continue;
      }
      const canonical = path.join(root, ".agents", "skills", name);
      if (wantsAgents && exists(canonical)) {
        linkOrCopy(canonical, dest);
      } else {
        copyDir(path.join(srcSkills, name), dest);
      }
      written.push(dest);
    }
  }

  // 3. Commands. The files use Claude Code's slash-command frontmatter
  //    ($ARGUMENTS, argument-hint); elsewhere they degrade to plain prompts.
  if (fs.existsSync(srcCommands)) {
    const commandDirs = [];
    if (targets.includes("claude")) commandDirs.push(path.join(root, ".claude", "commands"));
    if (targets.includes("cursor")) commandDirs.push(path.join(root, ".cursor", "commands"));

    for (const dir of commandDirs) {
      for (const file of fs.readdirSync(srcCommands).filter((f) => f.endsWith(".md"))) {
        const dest = path.join(dir, file);
        if (exists(dest)) {
          skipped.push(dest);
          continue;
        }
        copyFile(path.join(srcCommands, file), dest);
        written.push(dest);
      }
    }
  }

  writeManifest(root, pkg.version, written, targets);

  const rel = (p) => path.relative(root, p).split(path.sep).join("/");
  log(`${DRY ? "[dry run] " : ""}v${pkg.version} → ${rel(root) || "."} (targets: ${targets.join(", ")})`);
  log(`${written.length} path(s) installed, ${skillNames.length} skill(s).`);
  if (skipped.length > 0) {
    log(`Left alone (already present, not ours): ${skipped.map(rel).join(", ")}`);
  }
  log(`Manifest: ${MANIFEST_NAME}. Remove everything with: npm run uninstall:artifacts`);
}

main();
