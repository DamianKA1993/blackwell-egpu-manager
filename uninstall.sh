#!/usr/bin/env bash
set -e

# ==============================================================================
# iGPU / Blackwell eGPU Universal Manager - Passive Uninstaller (v1-global)
# Target: CachyOS / Arch Linux (KDE Plasma 6 Wayland)
# ==============================================================================

if [ "$EUID" -eq 0 ]; then
  echo "[-] Error: Run this script as a normal user (without sudo)."
  echo "    The uninstaller will prompt for root privileges when needed."
  exit 1
fi

APPLET_ID="org.cachyos.blackwellegpu"
OLD_APPLET_ID="org.cachyos.egpuswitcher"
PLASMOID_DIR="$HOME/.local/share/plasma/plasmoids/$APPLET_ID"
OLD_PLASMOID_DIR="$HOME/.local/share/plasma/plasmoids/$OLD_APPLET_ID"

QDBUS_CMD="qdbus6"
command -v qdbus6 >/dev/null 2>&1 || QDBUS_CMD="qdbus"

echo "=== 1. Removing CLI backend and permissions ==="
sudo rm -f "/usr/local/bin/blackwell-egpu"
sudo rm -f "/etc/sudoers.d/blackwell-egpu"
echo "[+] Backend binary and sudoers configuration removed."

echo "=== 2. Handling udev rules ==="
if [ -f "/etc/udev/rules.d/99-blackwell-egpu.rules" ]; then
    read -r -p "Do you want to remove eGPU udev isolation rules? [y/N]: " UDEV_REMOVE_CHOICE
    UDEV_REMOVE_CHOICE=${UDEV_REMOVE_CHOICE:-N}

    if [[ "$UDEV_REMOVE_CHOICE" =~ ^[YyTt]$ ]]; then
        sudo rm -f "/etc/udev/rules.d/99-blackwell-egpu.rules"
        sudo udevadm control --reload-rules
        echo "[+] eGPU udev rules removed."
    else
        echo "[*] Keeping /etc/udev/rules.d/99-blackwell-egpu.rules intact."
    fi
fi

# Clean up temporary allow-flag and mode file
sudo rm -f /tmp/egpu_allow /tmp/egpu_mode

echo "=== 3. Removing Plasma Applet from Panel and Disk ==="
JS_PAYLOAD=$(cat <<EOF
var allPanels = panels();
for (var i = 0; i < allPanels.length; i++) {
    var p = allPanels[i];
    var widgets = p.widgets();
    for (var j = 0; j < widgets.length; j++) {
        if (widgets[j].type === "$OLD_APPLET_ID" || widgets[j].type === "$APPLET_ID") {
            widgets[j].remove();
        }
    }
}
EOF
)

$QDBUS_CMD org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$JS_PAYLOAD" >/dev/null 2>&1 || true

rm -rf "$PLASMOID_DIR" "$OLD_PLASMOID_DIR"
echo "[+] Plasmoid directory deleted."

echo "=== 4. Refreshing KDE Plasma caches ==="
kbuildsycoca6 --noincremental >/dev/null 2>&1 || true

echo -e "\n----------------------------------------------------------------------"
echo "[+] Uninstallation complete! Running drivers and displays were untouched."
echo "[!] Recommendation: It is strongly advised to reboot the system to restore"
echo "    default kernel PCI topology and DRM display mappings cleanly."
echo "----------------------------------------------------------------------"
