#!/usr/bin/env bash

set -euo pipefail

# ANSI Color Codes
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

# Hardcoded domain automatically during build deployment
API_URL="https://your-vercel-domain.vercel.app"
HASH="${1:-}"

if [ -z "$HASH" ]; then
    echo -e "${RED}[!] Error: No wallpaper ID provided.${RESET}"
    echo -e "Usage: curl -sSL $API_URL/install.sh | bash -s -- <ID>"
    exit 1
fi

echo -e "${BLUE}==================================================${RESET}"
echo -e "${BLUE}      Piping Live Wallpaper Installer...          ${RESET}"
echo -e "${BLUE}==================================================${RESET}"

# Check/Install JQ (JSON Parser)
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}[*] 'jq' is missing. Installing via pacman...${RESET}"
    sudo pacman -S --noconfirm jq
fi

# Check/Install mpvpaper
if ! command -v mpvpaper &> /dev/null; then
    echo -e "${YELLOW}[*] 'mpvpaper' is missing. Installing via AUR...${RESET}"
    if command -v yay &> /dev/null; then
        yay -S --noconfirm mpvpaper
    elif command -v paru &> /dev/null; then
        paru -S --noconfirm mpvpaper
    else
        echo -e "${RED}[!] No AUR helper found. Please install 'mpvpaper' manually.${RESET}"
        exit 1
    fi
fi

# 1. Fetch JSON mapping
echo -e "${YELLOW}[*] Contacting database for asset information...${RESET}"
DATABASE=$(curl -sSL "$API_URL/wallpapers.json")
ENTRY=$(echo "$DATABASE" | jq -r ".[\"$HASH\"]")

if [ "$ENTRY" == "null" ]; then
    echo -e "${RED}[!] Error: Wallpaper ID '$HASH' does not exist in our registry.${RESET}"
    exit 1
fi

TITLE=$(echo "$ENTRY" | jq -r ".title")
URL=$(echo "$ENTRY" | jq -r ".url")
EXT=$(echo "$ENTRY" | jq -r ".format")

echo -e "${GREEN}[+] Match found: $TITLE [${EXT^^}]${RESET}"

# 2. Setup dynamic storage folder and paths
WALLPAPER_STORE="$HOME/.local/share/backgrounds/live-wallpapers"
SYMLINK_PATH="$WALLPAPER_STORE/current_wallpaper"
mkdir -p "$WALLPAPER_STORE"

# 3. Download from CDN
echo -e "${YELLOW}[*] Downloading wallpaper asset...${RESET}"
FILE_PATH="$WALLPAPER_STORE/$HASH.$EXT"
curl -L -o "$FILE_PATH" "$URL"

# 4. Generate symlink
ln -sf "$FILE_PATH" "$SYMLINK_PATH"
echo -e "${GREEN}[+] Dynamic symlink updated to: $FILE_PATH${RESET}"

# 5. Monitor configuration and Hyprland append
MONITOR=$(hyprctl monitors | grep "Monitor" | awk '{print $2}' | head -n 1)
[ -z "$MONITOR" ] && MONITOR="eDP-1"

HYPR_CONFIG="$HOME/.config/hypr/hyprland.conf"
AUTOSTART_LINE="exec-once = mpvpaper -o \"--loop-file=inf --no-audio --hwdec=auto\" $MONITOR $SYMLINK_PATH"

if [ -f "$HYPR_CONFIG" ]; then
    if grep -q "current_wallpaper" "$HYPR_CONFIG"; then
        echo -e "${GREEN}[+] Hyprland is already configured to use the dynamic symlink.${RESET}"
    else
        # Remove legacy configs from older setups to keep files clean
        sed -i 's/current_wallpaper.mp4/current_wallpaper/g' "$HYPR_CONFIG" 2>/dev/null || true
        
        if ! grep -q "current_wallpaper" "$HYPR_CONFIG"; then
            echo -e "${YELLOW}[*] Writing autostart instructions to hyprland.conf...${RESET}"
            echo -e "\n# Dynamic Live Wallpaper Manager" >> "$HYPR_CONFIG"
            echo "$AUTOSTART_LINE" >> "$HYPR_CONFIG"
        fi
    fi
fi

# 6. Apply instantly on the current screen session
if pgrep mpvpaper > /dev/null; then
    echo -e "${YELLOW}[*] Reloading mpvpaper display context...${RESET}"
    killall mpvpaper
    sleep 0.5
fi

mpvpaper -o "--loop-file=inf --no-audio --hwdec=auto" "$MONITOR" "$SYMLINK_PATH" & disown

echo -e "${GREEN}[✔] Wallpaper successfully applied: $TITLE${RESET}"
