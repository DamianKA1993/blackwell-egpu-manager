#!/usr/bin/env bash
set -e

# ==============================================================================
# iGPU / Blackwell eGPU Universal Manager - Uninstaller
# Supports: CLI backend, KDE Plasma, GNOME Shell & Universal Tray Applet
# ==============================================================================

if [ "$EUID" -eq 0 ]; then
  echo "[-] Error: Run this script as a normal user (without sudo)."
  echo "    The script will request root privileges when necessary."
  exit 1
fi

PLASMA_APPLET_DIR="$HOME/.local/share/plasma/plasmoids/com.github.blackwellegpu"
GNOME_EXTENSION_DIR="$HOME/.local/share/gnome-shell/extensions/blackwell-egpu@com.github.blackwellegpu"
TRAY_BIN="/usr/local/bin/blackwell-tray.py"
AUTOSTART_FILE="$HOME/.config/autostart/blackwell-tray.desktop"

echo "=== 1. Removing CLI backend and sudoers permissions ==="
if [ -f "/usr/local/bin/blackwell-egpu" ]; then
    sudo rm -f "/usr/local/bin/blackwell-egpu"
    echo "[+] Removed /usr/local/bin/blackwell-egpu"
fi

if [ -f "/etc/sudoers.d/blackwell-egpu" ]; then
    sudo rm -f "/etc/sudoers.d/blackwell-egpu"
    echo "[+] Removed /etc/sudoers.d/blackwell-egpu"
fi

echo "=== 2. Managing udev rules ==="
if [ -f "/etc/udev/rules.d/99-blackwell-egpu.rules" ]; then
    echo "----------------------------------------------------------------------"
    echo "[i] NOTICE: Custom udev rules (/etc/udev/rules.d/99-blackwell-egpu.rules)"
    echo "    prevent PCIe bus race conditions and driver stalls on USB4/TB4."
    echo ""
    echo "    If you plan to update or reinstall the program, press [Enter] to keep these rules."
    echo ""
    echo "    IF YOU WANT TO COMPLETELY REMOVE THE PROGRAM, TYPE 'Y' AND PRESS [ENTER]."
    echo "----------------------------------------------------------------------"
    read -r -p "Remove udev rules? [y/N]: " UDEV_REMOVE_CHOICE
    UDEV_REMOVE_CHOICE=${UDEV_REMOVE_CHOICE:-N}

    if [[ "$UDEV_REMOVE_CHOICE" =~ ^[Yy]$ ]]; then
        sudo rm -f "/etc/udev/rules.d/99-blackwell-egpu.rules"
        sudo udevadm control --reload-rules
        echo "[+] Removed udev rules and reloaded subsystem configuration."
    else
        echo "[*] Kept udev rules for future reinstallation."
    fi
else
    echo "[*] No custom udev rules found."
fi

# Clean up temporary flags and cache directory
rm -f /tmp/egpu_allow /tmp/egpu_wait
rm -rf /tmp/blackwell_egpu

echo "=== 3. Removing GUI Components ==="

# 3a. Universal System Tray Applet
TRAY_FOUND=false
if [ -f "$TRAY_BIN" ] || [ -f "$AUTOSTART_FILE" ] || pgrep -f blackwell-tray.py >/dev/null 2>&1; then
    TRAY_FOUND=true
    echo "[+] Terminating Universal Tray process..."
    pkill -f blackwell-tray.py || true

    if [ -f "$TRAY_BIN" ]; then
        sudo rm -f "$TRAY_BIN"
        echo "[+] Removed executable: $TRAY_BIN"
    fi

    if [ -f "$AUTOSTART_FILE" ]; then
        rm -f "$AUTOSTART_FILE"
        echo "[+] Removed autostart entry: $AUTOSTART_FILE"
    fi
fi

if [ "$TRAY_FOUND" = false ]; then
    echo "[*] Universal Tray applet was not detected."
fi

# 3b. KDE Plasma 6 Applet
if [ -d "$PLASMA_APPLET_DIR" ]; then
    rm -rf "$PLASMA_APPLET_DIR"
    echo "[+] Removed Plasma applet: $PLASMA_APPLET_DIR"

    # Clear QML / Plasma cache
    rm -rf "$HOME/.cache/plasma"* "$HOME/.cache/qmlcache"*
    echo "[+] Cleared Plasma cache."

    read -r -p "Restart Plasmashell to refresh UI components? [Y/n]: " RESTART_CHOICE
    RESTART_CHOICE=${RESTART_CHOICE:-Y}
    if [[ "$RESTART_CHOICE" =~ ^[Yy]$ ]]; then
        killall plasmashell 2>/dev/null || true
        sleep 1
        nohup plasmashell >/dev/null 2>&1 &
        echo "[+] Plasmashell restarted."
    fi
else
    echo "[*] Plasma applet was not found in user directory."
fi

# 3c. GNOME Shell Extension
if [ -d "$GNOME_EXTENSION_DIR" ]; then
    if command -v gnome-extensions &>/dev/null; then
        gnome-extensions disable "blackwell-egpu@com.github.blackwellegpu" 2>/dev/null || true
    fi
    rm -rf "$GNOME_EXTENSION_DIR"
    echo "[+] Removed GNOME Shell extension: $GNOME_EXTENSION_DIR"
else
    echo "[*] GNOME Shell extension was not found in user directory."
fi

echo -e "\n[+] Uninstallation completed successfully!"
