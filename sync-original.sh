#!/usr/bin/env bash
#
# sync-original.sh
#
# Updates the `original` branch of home-assistant-alexa-extended with the
# pristine `alexa` component taken from a given Home Assistant core release tag.
#
# The `original` branch is meant to track the upstream core code verbatim (no
# custom modifications). After running this script you can merge `original`
# into `main` to bring the blocker feature up to date.
#
# Usage:
#   ./sync-original.sh 2026.6.3
#
# Requirements: git, a clean working tree on the repo you run this from.

set -euo pipefail

# ---- Configuration -----------------------------------------------------------
CORE_VERSION="${1:-}"
CORE_REPO="https://github.com/home-assistant/core.git"
COMPONENT_PATH="homeassistant/components/alexa"   # path inside the core repo
TARGET_PATH="custom_components/alexa"             # path inside this repo
ORIGINAL_BRANCH="original"

# ---- Argument check ----------------------------------------------------------
if [[ -z "$CORE_VERSION" ]]; then
  echo "Error: missing Home Assistant core version."
  echo "Usage: $0 <core-version>   (e.g. $0 2026.6.3)"
  exit 1
fi

# ---- Pre-flight checks -------------------------------------------------------
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Error: working tree is not clean. Commit or stash your changes first."
  exit 1
fi

# ---- Remember the current branch and restore it on exit ----------------------
PREVIOUS_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
  # Return to the branch we started from, unless we never left it.
  CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
  if [[ -n "$PREVIOUS_BRANCH" && "$CURRENT_BRANCH" != "$PREVIOUS_BRANCH" ]]; then
    echo ">> Returning to branch '$PREVIOUS_BRANCH'..."
    git checkout "$PREVIOUS_BRANCH"
  fi
}
trap cleanup EXIT

# ---- Switch to the original branch -------------------------------------------
echo ">> Checking out branch '$ORIGINAL_BRANCH'..."
git checkout "$ORIGINAL_BRANCH"
git pull --ff-only 2>/dev/null || true

# ---- Fetch only the alexa component from the requested core tag --------------

echo ">> Fetching '$COMPONENT_PATH' from core tag '$CORE_VERSION' (sparse, blobless)..."
git clone --no-checkout --filter=blob:none --depth 1 \
  --branch "$CORE_VERSION" "$CORE_REPO" "$TMP_DIR/core"

git -C "$TMP_DIR/core" sparse-checkout init --cone
git -C "$TMP_DIR/core" sparse-checkout set "$COMPONENT_PATH"
git -C "$TMP_DIR/core" checkout

SRC="$TMP_DIR/core/$COMPONENT_PATH"
if [[ ! -d "$SRC" ]]; then
  echo "Error: '$COMPONENT_PATH' not found in core tag '$CORE_VERSION'."
  exit 1
fi

# ---- Replace the target component verbatim -----------------------------------
echo ">> Replacing '$TARGET_PATH' with the pristine core component..."
rm -rf "$TARGET_PATH"
mkdir -p "$TARGET_PATH"
# Copy contents only (not the directory itself), excluding any VCS metadata.
cp -a "$SRC/." "$TARGET_PATH/"

# ---- Stage, show, and commit -------------------------------------------------
git add "$TARGET_PATH"

if git diff --cached --quiet; then
  echo ">> No changes: '$ORIGINAL_BRANCH' is already at core $CORE_VERSION."
  exit 0
fi

echo ">> Changes staged:"
git diff --cached --stat

git commit -m "Updated code to $CORE_VERSION"

echo ""
echo ">> Branch '$ORIGINAL_BRANCH' now tracks core $CORE_VERSION."
echo ">> Next steps:"
echo "     git push origin $ORIGINAL_BRANCH"
echo "     git merge $ORIGINAL_BRANCH   # from your feature branch, to bring in the update"
# The EXIT trap will now return to '$PREVIOUS_BRANCH'.