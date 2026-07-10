#!/bin/bash
# Prepare a manually-created worktree: symlinked dirs, user permissions, .worktreeinclude files.
# Usage: wt-setup.sh <repo_root> <worktree_path>
REPO="$1"; WT="$2"
[ -d "$REPO" ] && [ -d "$WT" ] || { echo "usage: wt-setup.sh <repo_root> <worktree_path>" >&2; exit 1; }

# Directories listed in worktree.symlinkDirectories (local settings first)
for f in "$REPO/.claude/settings.local.json" "$REPO/.claude/settings.json"; do
  [ -f "$f" ] || continue
  while IFS= read -r d; do
    if [ -n "$d" ] && [ -e "$REPO/$d" ] && [ ! -e "$WT/$d" ]; then
      ln -s "$REPO/$d" "$WT/$d" && echo "symlink: $d"
    fi
  done < <(jq -r '.worktree.symlinkDirectories[]? // empty' "$f" 2>/dev/null)
done

# User permission allowlist (gitignored, so absent from a fresh checkout)
if [ -f "$REPO/.claude/settings.local.json" ]; then
  mkdir -p "$WT/.claude"
  cp "$REPO/.claude/settings.local.json" "$WT/.claude/settings.local.json" && echo "copied: .claude/settings.local.json"
fi

# Files listed in .worktreeinclude (gitignored files needed at runtime, e.g. .env)
if [ -f "$REPO/.worktreeinclude" ]; then
  while IFS= read -r f; do
    if [ -n "$f" ] && [ -f "$REPO/$f" ] && [ ! -e "$WT/$f" ]; then
      mkdir -p "$WT/$(dirname "$f")"
      cp "$REPO/$f" "$WT/$f" && echo "copied: $f"
    fi
  done < "$REPO/.worktreeinclude"
fi
echo "setup done: $WT"
