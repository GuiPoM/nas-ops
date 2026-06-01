#!/bin/bash
# install.sh — Install nas-ops scripts to /usr/local/bin
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/GuiPoM/nas-ops/main/install.sh)

set -euo pipefail

# Redirect stdin from /dev/tty to avoid issues when piped from curl
exec < /dev/tty

REPO="GuiPoM/nas-ops"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
INSTALL_DIR="/usr/local/bin"

SCRIPTS=(
    "nas-system-update"
    "nas-system-upgrade"
    "nas-docker-pull"
    "nas-docker-up"
    "nas-docker-prune"
    "nas-update"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

echo -e "${BOLD}======================================${RESET}"
echo -e "${BOLD}        nas-ops — Installer           ${RESET}"
echo -e "${BOLD}======================================${RESET}"
echo ""

# Check root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Error: this script must be run as root.${RESET}"
    exit 1
fi

# Check dependencies
echo -e "${CYAN}Checking dependencies...${RESET}"
for cmd in curl docker apt-get; do
    if type "$cmd" > /dev/null 2>&1 || [ -x "/usr/bin/$cmd" ] || [ -x "/bin/$cmd" ]; then
        echo -e "  ${GREEN}✅ ${cmd}${RESET}"
    else
        echo -e "  ${YELLOW}⚠ ${cmd} not found — some scripts may not work${RESET}"
    fi
done
echo ""

# Download and install scripts
echo -e "${CYAN}Installing scripts to ${INSTALL_DIR}...${RESET}"
for script in "${SCRIPTS[@]}"; do
    if curl -fsSL "${BASE_URL}/${script}" -o "${INSTALL_DIR}/${script}"; then
        chmod +x "${INSTALL_DIR}/${script}"
        echo -e "  ${GREEN}✅ ${script}${RESET}"
    else
        echo -e "  ${RED}❌ ${script} — Failed${RESET}"
        exit 1
    fi
done

echo ""
echo -e "${GREEN}✅ Installation complete.${RESET}"
echo ""
echo -e "Available commands:"
for script in "${SCRIPTS[@]}"; do
    echo -e "  ${CYAN}${script}${RESET}"
done
echo ""
echo -e "Run ${BOLD}nas-update${RESET} to get started."
