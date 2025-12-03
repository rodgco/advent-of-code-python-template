#!/bin/bash
# Script to update project files from the template repository
#
# SETUP (one-time):
#     curl -sSL https://raw.githubusercontent.com/rodgco/advent-of-code-python-template/main/scripts/install.sh | sh
#
# USAGE (after setup):
#     aoc-update [--dry-run] [--branch BRANCH]
#
# DIRECT USAGE (without setup):
#     curl -sSL https://raw.githubusercontent.com/rodgco/advent-of-code-python-template/main/scripts/update.sh | sh [--dry-run] [--branch BRANCH]
#
# OPTIONS:
#     --dry-run      Show what would be updated without making changes
#     --branch       Template repository branch to pull from (default: main)
#
# Note: This script is NOT included in the template sync configuration to avoid
# self-update issues when piping from curl. Always use the latest version from
# the template repository.

set -e

TEMPLATE_REPO="https://github.com/rodgco/advent-of-code-python-template.git"
BRANCH="main"
DRY_RUN=false
CONFIG_FILE=".template-sync"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --branch)
            BRANCH="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Create temporary directory
TEMP_DIR=$(mktemp -d -t aoc_template.XXXXXX)
trap "rm -rf $TEMP_DIR" EXIT

echo "Cloning template repository to $TEMP_DIR..."
git clone --depth 1 --branch "$BRANCH" "$TEMPLATE_REPO" "$TEMP_DIR"

# Check if config file exists in template
if [ ! -f "$TEMP_DIR/$CONFIG_FILE" ]; then
    echo "⚠️  Config file not found: $CONFIG_FILE"
    echo "Expected to find a list of files/directories to sync in the template repo."
    exit 1
fi

echo ""
echo "Reading sync configuration from $CONFIG_FILE..."
echo ""
echo "Updating files from template ($BRANCH branch)..."
echo ""

UPDATED_COUNT=0

# Function to update a file
update_file() {
    local source="$1"
    local dest="$2"
    local filename=$(basename "$dest")

    if [ ! -f "$source" ]; then
        echo "⚠️  Source file not found: $source"
        return
    fi

    if [ -f "$dest" ] && cmp -s "$source" "$dest"; then
        echo "✓ Already up to date: $filename"
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "→ Would update: $filename"
    else
        mkdir -p "$(dirname "$dest")"
        cp -p "$source" "$dest"
        echo "✓ Updated: $filename"
    fi

    ((UPDATED_COUNT++)) || true
}

# Function to update a directory
update_dir() {
    local source="$1"
    local dest="$2"
    local dirname=$(basename "$dest")

    if [ ! -d "$source" ]; then
        echo "⚠️  Source directory not found: $source"
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "→ Would update: $dirname/"
    else
        rm -rf "$dest"
        cp -r "$source" "$dest"
        echo "✓ Updated: $dirname/"
    fi

    ((UPDATED_COUNT++)) || true
}

# Read and process each line from config file
while IFS= read -r line || [ -n "$line" ]; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^# ]] && continue

    # Remove leading/trailing whitespace
    line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    source_path="$TEMP_DIR/$line"
    dest_path="$PROJECT_ROOT/$line"

    # Check if it's a directory (ends with /)
    if [[ "$line" == */ ]]; then
        # Remove trailing slash for actual path
        source_path="${source_path%/}"
        dest_path="${dest_path%/}"
        update_dir "$source_path" "$dest_path"
    else
        update_file "$source_path" "$dest_path"
    fi
done < "$TEMP_DIR/$CONFIG_FILE"

echo ""
if [ "$DRY_RUN" = true ]; then
    echo "Would update $UPDATED_COUNT item(s)"
else
    echo "✨ Update complete! Updated $UPDATED_COUNT item(s)"
    echo "Consider reviewing changes with: git diff"
fi
