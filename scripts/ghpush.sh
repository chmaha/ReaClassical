#!/bin/zsh
set -e

error_exit() {
    echo "Error: $1 failed!" >&2
    exit 1
}

echo "Running ReaPack index update..."
reapack-index || error_exit "reapack-index"

# Check if index.xml has changes
if git diff --quiet index.xml && git diff --cached --quiet index.xml; then
    echo "No changes in index.xml. Skipping commit and push."
    exit 0
fi

echo "Pruning index.xml..."
ruby scripts/prune_index.rb || error_exit "prune_index.rb"

echo "Adding index.xml to git..."
git add index.xml || error_exit "git add"

echo "Committing changes..."
git commit -m "Add new version to index.xml and prune" || error_exit "git commit"

echo "Pushing to GitHub..."
git push || error_exit "git push"

echo "Updating changelog..."
ruby scripts/changelog-update.rb || error_exit "changelog-update.rb"

echo "All done!"
