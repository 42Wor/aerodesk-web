#!/usr/bin/env bash

set -euo pipefail

# ANSI Color Codes
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"
RESET="\033[0m"

echo -e "${CYAN}==================================================${RESET}"
echo -e "${CYAN}          AeroDesk Installer & Migrator           ${RESET}"
echo -e "${CYAN}==================================================${RESET}"

if [ "$(uname)" != "Linux" ] && [ "$(uname)" != "Darwin" ]; then
    echo -e "${RED}[!] Error: AeroDesk install.sh supports Linux and macOS systems.${RESET}"
    exit 1
fi

# 1. Dependency Check
echo -e "${YELLOW}[*] Validating Go compiler...${RESET}"
if ! command -v go &> /dev/null; then
    if command -v pacman &> /dev/null; then
        echo -e "${YELLOW}[*] Installing Go via pacman...${RESET}"
        sudo pacman -S --noconfirm go
    elif command -v brew &> /dev/null; then
        echo -e "${YELLOW}[*] Installing Go via homebrew...${RESET}"
        brew install go
    else
        echo -e "${RED}[!] Go compiler not found. Please install Go (golang) first.${RESET}"
        exit 1
    fi
fi

# 2. Setup Directory Structure
LEGACY_DIR="$HOME/.local/share/backgrounds/live-wallpapers"
NEW_DIR="$HOME/.local/share/backgrounds/aerodesk"

echo -e "${YELLOW}[*] Configuring directory systems...${RESET}"
mkdir -p "$NEW_DIR"

# 3. Migrate Existing Wallpapers
if [ -d "$LEGACY_DIR" ]; then
    echo -e "${CYAN}[~] Legacy installation directory detected: $LEGACY_DIR${RESET}"
    echo -e "${YELLOW}[*] Migrating wallpapers to AeroDesk directory...${RESET}"
    find "$LEGACY_DIR" -type f ! -name "current_wallpaper" -exec cp -p -t "$NEW_DIR" {} + 2>/dev/null || true
    rm -rf "$LEGACY_DIR"
    echo -e "${GREEN}[✔] Migrated assets and deleted old live-wallpapers directory.${RESET}"
fi

# 4. Compile and Install AeroDesk CLI
BUILD_PATH=""
TEMP_BUILD_DIR=""

if [ -f "./main.go" ]; then
    echo -e "${YELLOW}[*] Local main.go detected. Using current workspace for compilation...${RESET}"
    BUILD_PATH="."
else
    echo -e "${YELLOW}[*] Cloning source files from GitHub...${RESET}"
    TEMP_BUILD_DIR=$(mktemp -d)
    if git clone https://github.com/42Wor/aerodesk-cli.git "$TEMP_BUILD_DIR" 2>/dev/null; then
        BUILD_PATH="$TEMP_BUILD_DIR"
    else
        echo -e "${RED}[!] Error: Could not clone repository and no local main.go was found.${RESET}"
        exit 1
    fi
fi

echo -e "${YELLOW}[*] Building Go CLI...${RESET}"
ORIGINAL_DIR=$(pwd)
cd "$BUILD_PATH"

# Initialize Go module structure if absent
if [ ! -f "go.mod" ]; then
    go mod init aerodesk 2>/dev/null || true
fi

# Compile package with optimization flags
go build -ldflags="-s -w" -o aerodesk .

# Global binary placement
if [ -w "/usr/local/bin" ]; then
    mv aerodesk /usr/local/bin/
else
    echo -e "${YELLOW}[*] Elevated permissions needed to install to /usr/local/bin...${RESET}"
    sudo mv aerodesk /usr/local/bin/
fi

cd "$ORIGINAL_DIR"
if [ -n "$TEMP_BUILD_DIR" ] && [ -d "$TEMP_BUILD_DIR" ]; then
    rm -rf "$TEMP_BUILD_DIR"
fi

echo -e "${GREEN}[✔] AeroDesk binary compiled and installed to: /usr/local/bin/aerodesk${RESET}"

# 5. Clean Old Configuration Files
HYPR_CONFIG="$HOME/.config/hypr/hyprland.conf"
if [ -f "$HYPR_CONFIG" ]; then
    echo -e "${YELLOW}[*] Cleaning legacy references in hyprland.conf...${RESET}"
    # macOS-safe inline replacement pattern
    sed -i.bak -e '/live-wallpapers/d' \
               -e '/wallpaper-manager/d' \
               -e '/# Dynamic Live Wallpaper Manager/d' "$HYPR_CONFIG"
    rm -f "${HYPR_CONFIG}.bak"
    echo -e "${GREEN}[✔] Legacy configs cleared.${RESET}"
fi

echo -e "${GREEN}==================================================${RESET}"
echo -e "${GREEN}      AeroDesk Migration & Installation Complete! ${RESET}"
echo -e "${GREEN}==================================================${RESET}"
echo -e "Usage:"
echo -e "  To list all backgrounds   : ${CYAN}aerodesk list${RESET}"
echo -e "  To open setup menu        : ${CYAN}aerodesk config${RESET}"
echo -e "  To set a background       : ${CYAN}aerodesk apply <id>${RESET}"