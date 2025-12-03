#!/bin/bash
# Installation script for Advent of Code Python Template
#
# Usage (from the project root after cloning):
#     ./install.sh [OPTIONS]
#
# This script:
# 1. Sets up the 'aoc-update' alias for easy project updates
# 2. Installs uv (if not already installed)
# 3. Installs project dependencies via uv
#
# Requirements:
#     - Python 3.12 or higher
#     - curl or wget (for downloading uv)
#
# Options:
#     --help         Show this help message

set -e

SHELL_RC=""
ALIAS_CMD="alias aoc-update='curl -sSL https://raw.githubusercontent.com/rodgco/advent-of-code-python-template/main/scripts/update.sh | sh'"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_MIN_VERSION="3.12"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            echo "Installation script for Advent of Code Python Template"
            echo ""
            echo "Usage: ./install.sh [OPTIONS]"
            echo ""
            echo "This script sets up your project by:"
            echo "  1. Installing uv (if not already installed)"
            echo "  2. Setting up the aoc-update alias"
            echo "  3. Installing project dependencies"
            echo ""
            echo "Options:"
            echo "  --help   Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Detect which shell config file to use
detect_shell_rc() {
    if [ -n "$ZSH_VERSION" ]; then
        SHELL_RC="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        SHELL_RC="$HOME/.bashrc"
    else
        # Fallback: try to detect from $SHELL environment variable
        if [[ "$SHELL" == *"zsh"* ]]; then
            SHELL_RC="$HOME/.zshrc"
        elif [[ "$SHELL" == *"bash"* ]]; then
            SHELL_RC="$HOME/.bashrc"
        else
            return 1
        fi
    fi
    return 0
}

# Check Python version
check_python_version() {
    local python_cmd="$1"
    local version=$($python_cmd -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')

    # Compare versions: convert "3.14" to "314" for numeric comparison
    local version_num=${version/./}
    local min_version_num=${PYTHON_MIN_VERSION/./}

    if [ "$version_num" -lt "$min_version_num" ]; then
        return 1
    fi
    return 0
}

# Setup alias
setup_alias() {
    if ! detect_shell_rc; then
        echo "⚠️  Could not detect your shell configuration file"
        echo "Please add this line manually to your shell rc file (.bashrc or .zshrc):"
        echo ""
        echo "$ALIAS_CMD"
        return 1
    fi

    # Check if alias already exists
    if grep -q "alias aoc-update=" "$SHELL_RC" 2>/dev/null; then
        echo "✓ aoc-update alias already exists in $SHELL_RC"
        return 0
    fi

    # Add the alias
    echo "" >> "$SHELL_RC"
    echo "# Advent of Code update alias" >> "$SHELL_RC"
    echo "$ALIAS_CMD" >> "$SHELL_RC"

    echo "✓ Added aoc-update alias to $SHELL_RC"
    return 0
}

# Check and install uv if needed
install_uv_if_needed() {
    if command -v uv &> /dev/null; then
        echo "✓ uv is already installed"
        return 0
    fi

    echo "ℹ️  uv not found, installing..."

    # Try to detect the system and architecture
    if command -v curl &> /dev/null; then
        curl -LsSf https://astral.sh/uv/install.sh | sh
    elif command -v wget &> /dev/null; then
        wget -qO- https://astral.sh/uv/install.sh | sh
    else
        echo "⚠️  curl or wget not found, cannot install uv automatically"
        echo "Please install uv manually from https://github.com/astral-sh/uv"
        return 1
    fi

    # Add uv to PATH for this session
    export PATH="$HOME/.local/bin:$PATH"

    if ! command -v uv &> /dev/null; then
        echo "⚠️  uv installation may have failed. Please verify installation."
        return 1
    fi

    echo "✓ uv installed successfully"
    return 0
}

# Initialize Python environment using uv
setup_environment() {
    if [ ! -f "$PROJECT_ROOT/pyproject.toml" ]; then
        echo "ℹ️  No pyproject.toml found in $PROJECT_ROOT"
        echo "Skipping environment setup"
        return 0
    fi

    echo ""
    echo "Setting up Python environment..."

    # Check Python version first
    if ! check_python_version "python3"; then
        echo "⚠️  Python 3.12+ is required, but $(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))') is installed"
        return 1
    fi

    # Install uv if needed
    if ! install_uv_if_needed; then
        return 1
    fi

    # Use uv to set up environment
    echo "✓ Using uv for environment setup"
    uv sync
    if [ -f "$PROJECT_ROOT/requirements.txt" ]; then
        uv add -r requirements.txt || true
    fi
    echo "✓ Environment setup complete"
    return 0
}

# Main
echo "Installing Advent of Code Python Template setup..."
echo ""

if ! setup_alias; then
    echo "⚠️  Failed to setup alias, but continuing..."
fi

if ! setup_environment; then
    echo "⚠️  Failed to setup environment"
    exit 1
fi

echo ""
echo "✨ Setup complete!"
echo ""
echo "You can now use: aoc-update [--dry-run] [--branch BRANCH]"
echo ""
echo "To activate the alias, either:"
echo "  1. Run: source $SHELL_RC"
echo "  2. Open a new terminal"
