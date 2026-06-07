#!/usr/bin/env bash

set -euo pipefail

# ANSI Color Codes
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
RESET="\e[0m"

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

# 4. Clone, Compile, and Install AeroDesk CLI
echo -e "${YELLOW}[*] Cloning source files...${RESET}"
TEMP_BUILD_DIR=$(mktemp -d)

# corrected URL: cloning your CLI repository instead of the Hugging Face dataset
git clone https://github.com/Maazwaheed/aerodesk-cli.git "$TEMP_BUILD_DIR" 2>/dev/null || true

BUILD_PATH="$TEMP_BUILD_DIR"
if [ ! -f "$BUILD_PATH/main.go" ] && [ -f "./main.go" ]; then
    BUILD_PATH="."
fi

echo -e "${YELLOW}[*] Building Go CLI...${RESET}"
if [ -d "$BUILD_PATH" ]; then
    cd "$BUILD_PATH"
    
    # Initialize module if it is missing in the build path
    if [ ! -f "go.mod" ]; then
        go mod init aerodesk 2>/dev/null || true
    fi
    
    # Compile
    go build -ldflags="-s -w" -o aerodesk .
    
    # Global binary placement
    if [ -w "/usr/local/bin" ]; then
        mv aerodesk /usr/local/bin/
    else
        sudo mv aerodesk /usr/local/bin/
    fi
    echo -e "${GREEN}[✔] AeroDesk binary compiled and installed to: /usr/local/bin/aerodesk${RESET}"
else
    echo -e "${RED}[!] Source files missing. Build failed.${RESET}"
    exit 1
fi

rm -rf "$TEMP_BUILD_DIR"

# 5. Clean Old Configuration Files
HYPR_CONFIG="$HOME/.config/hypr/hyprland.conf"
if [ -f "$HYPR_CONFIG" ]; then
    echo -e "${YELLOW}[*] Cleaning legacy references in hyprland.conf...${RESET}"
    sed -i '/live-wallpapers/d' "$HYPR_CONFIG"
    sed -i '/wallpaper-manager/d' "$HYPR_CONFIG"
    sed -i '/# Dynamic Live Wallpaper Manager/d' "$HYPR_CONFIG"
    echo -e "${GREEN}[✔] Legacy configs cleared.${RESET}"
fi

echo -e "${GREEN}==================================================${RESET}"
echo -e "${GREEN}      AeroDesk Migration & Installation Complete! ${RESET}"
echo -e "${GREEN}==================================================${RESET}"
echo -e "Usage:"
echo -e "  To list all backgrounds   : ${CYAN}aerodesk list${RESET}"
echo -e "  To set a background       : ${CYAN}aerodesk apply <id>${RESET}"