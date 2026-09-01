#!/usr/bin/env bash
set -e

# ==============================================================================
# iGPU / Blackwell eGPU Universal Manager - CLI & Multi-Desktop Installer
# ==============================================================================

if [ "$EUID" -eq 0 ]; then
  echo "[-] Error: Run this script as a normal user (without sudo)."
  echo "    The installer will request root privileges when necessary."
  exit 1
fi

CURRENT_USER="$USER"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_SRC="$SCRIPT_DIR/blackwell-egpu"

# Ścieżki źródłowe
PLASMA_SRC="$SCRIPT_DIR/plasma-applet/com.github.blackwellegpu"
GNOME_SRC="$SCRIPT_DIR/gnome-applet/blackwell-egpu@com.github.blackwellegpu"
TRAY_SRC="$SCRIPT_DIR/universal-applet/blackwell-tray.py"
UDEV_SRC="$SCRIPT_DIR/udev/99-blackwell-egpu.rules"

# Ścieżki docelowe w systemie
PLASMA_DEST="$HOME/.local/share/plasma/plasmoids/com.github.blackwellegpu"
GNOME_DEST="$HOME/.local/share/gnome-shell/extensions/blackwell-egpu@com.github.blackwellegpu"
TRAY_BIN="/usr/local/bin/blackwell-tray.py"
AUTOSTART_FILE="$HOME/.config/autostart/blackwell-tray.desktop"
UDEV_RULE_FILE="/etc/udev/rules.d/99-blackwell-egpu.rules"

UDEV_NEWLY_INSTALLED=false

# 1. Weryfikacja plików bazowych
if [ ! -f "$BACKEND_SRC" ]; then
    echo "[-] Error: File '$BACKEND_SRC' not found."
    exit 1
fi

if [ ! -f "$UDEV_SRC" ]; then
    echo "[-] Error: File '$UDEV_SRC' not found."
    exit 1
fi

echo "=== 1. Checking NVIDIA Open kernel module ==="
if ! pacman -Qs "nvidia-open" >/dev/null 2>&1 && ! modinfo nvidia 2>/dev/null | grep -iq "license.*dual"; then
    echo "----------------------------------------------------------------------"
    echo "[!] WARNING: NVIDIA Open kernel module not detected!"
    echo "    Blackwell GPUs (RTX 50xx) require open-source kernel modules."
    echo "    Install: 'nvidia-open-dkms' (or 'nvidia-open') and kernel headers."
    echo "----------------------------------------------------------------------"
    read -r -p "Press [Enter] to continue anyway, or Ctrl+C to abort..."
else
    echo "[+] Detected NVIDIA Open kernel module."
fi

echo "=== 2. Copying CLI backend to /usr/local/bin/blackwell-egpu ==="
sudo cp "$BACKEND_SRC" /usr/local/bin/blackwell-egpu
sudo chmod +x /usr/local/bin/blackwell-egpu
echo "[+] Installed /usr/local/bin/blackwell-egpu"

echo "=== 3. Configuring sudoers permissions ==="
echo "$CURRENT_USER ALL=(ALL) NOPASSWD: /usr/local/bin/blackwell-egpu" | sudo tee "/etc/sudoers.d/blackwell-egpu" > /dev/null
sudo chmod 0440 "/etc/sudoers.d/blackwell-egpu"
echo "[+] Configured /etc/sudoers.d/blackwell-egpu"

echo "=== 4. Configuring udev rules ==="
install_udev_rule() {
    sudo cp "$UDEV_SRC" "$UDEV_RULE_FILE"
    sudo chmod 644 "$UDEV_RULE_FILE"
    sudo udevadm control --reload-rules
}

if [ -f "$UDEV_RULE_FILE" ]; then
    echo "[+] Existing udev rules detected. Updating rules automatically..."
    install_udev_rule
    echo "[+] Udev rules updated successfully."
else
    read -r -p "Install udev rules to prevent automatic driver attachment on USB4/TB? [Y/n]: " UDEV_CHOICE
    UDEV_CHOICE=${UDEV_CHOICE:-Y}

    if [[ "$UDEV_CHOICE" =~ ^[Yy]$ ]]; then
        install_udev_rule
        UDEV_NEWLY_INSTALLED=true
        echo "[+] Udev rules installed successfully."
    else
        echo "[*] Skipped udev rules installation."
    fi
fi

# Funkcje pomocnicze instalacji i czyszczenia
remove_plasma() {
    echo "[+] Removing KDE Plasma applet..."
    rm -rf "$PLASMA_DEST"
    rm -rf "$HOME/.cache/plasma"* "$HOME/.cache/qmlcache"*
}

remove_gnome() {
    echo "[+] Removing GNOME Shell extension..."
    if command -v gnome-extensions &>/dev/null; then
        gnome-extensions disable "blackwell-egpu@com.github.blackwellegpu" 2>/dev/null || true
    fi
    rm -rf "$GNOME_DEST"
}

remove_tray() {
    echo "[+] Removing Universal Tray applet..."
    pkill -f blackwell-tray.py || true
    sudo rm -f "$TRAY_BIN"
    rm -f "$AUTOSTART_FILE"
}

install_tray() {
    echo "[+] Checking PySide6 dependency..."
    if ! python3 -c "import PySide6" >/dev/null 2>&1; then
        PKG_NAME="python3-pyside6"
        [ -x "$(command -v pacman)" ] && PKG_NAME="python-pyside6"

        echo "----------------------------------------------------------------------"
        echo "[!] MISSING DEPENDENCY: PySide6 library is required for Universal Tray."
        echo "    Missing package: '$PKG_NAME'"
        echo "----------------------------------------------------------------------"
        read -r -p "Press [Enter] to acknowledge..."

        read -r -p "Install '$PKG_NAME' automatically now? [y/N]: " DEP_CHOICE
        DEP_CHOICE=${DEP_CHOICE:-N}
        if [[ "$DEP_CHOICE" =~ ^[Yy]$ ]]; then
            if command -v pacman &>/dev/null; then
                sudo pacman -S --needed --noconfirm python-pyside6
            elif command -v apt-get &>/dev/null; then
                sudo apt-get update -qq && sudo apt-get install -y python3-pyside6
            elif command -v dnf &>/dev/null; then
                sudo dnf install -y python3-pyside6
            elif command -v zypper &>/dev/null; then
                sudo zypper install -y python3-pyside6
            else
                echo "[-] Package manager not supported for auto-install. Install PySide6 manually."
                return 1
            fi
        else
            echo "[-] Skipping dependency installation. Aborting Universal Tray setup."
            return 1
        fi
    fi

    sudo cp "$TRAY_SRC" "$TRAY_BIN"
    sudo chmod +x "$TRAY_BIN"

    mkdir -p "$(dirname "$AUTOSTART_FILE")"
    cat << 'EOF' > "$AUTOSTART_FILE"
[Desktop Entry]
Type=Application
Name=Blackwell eGPU Tray
Comment=Status notifier and tray controller for Blackwell eGPU
Exec=/usr/local/bin/blackwell-tray.py
Icon=video-display
Terminal=false
Categories=Utility;System;
StartupNotify=false
X-GNOME-Autostart-enabled=true
EOF
    chmod 644 "$AUTOSTART_FILE"

    pkill -f blackwell-tray.py || true
    sleep 0.5
    nohup "$TRAY_BIN" >/dev/null 2>&1 &
    echo "[+] Universal Tray installed, started, and added to autostart."
}

echo "=== 5. GUI Integration & Applet Selection ==="
CURRENT_DESKTOP_ENV="${XDG_CURRENT_DESKTOP:-$DESKTOP_SESSION}"

if [[ "$CURRENT_DESKTOP_ENV" =~ [Kk][Dd][Ee] ]]; then
    echo "[+] Detected Desktop Environment: KDE Plasma"
    echo "Select GUI integration option:"
    echo "  1) Native KDE Plasma 6 Applet (Plasmoid widget) [Default]"
    echo "  2) Universal System Tray Applet (PySide6 / Standalone)"
    echo "  3) Skip GUI installation (CLI only)"
    read -r -p "Enter choice [1-3] (default: 1): " GUI_CHOICE
    GUI_CHOICE=${GUI_CHOICE:-1}
    [ "$GUI_CHOICE" -eq 1 ] && CHOSEN="kde"
    [ "$GUI_CHOICE" -eq 2 ] && CHOSEN="tray"
    [ "$GUI_CHOICE" -eq 3 ] && CHOSEN="skip"

elif [[ "$CURRENT_DESKTOP_ENV" =~ [Gg][Nn][Oo][Mm][Ee] ]]; then
    echo "[+] Detected Desktop Environment: GNOME Shell"
    echo "Select GUI integration option:"
    echo "  1) Native GNOME Shell Extension [Default]"
    echo "  2) Skip GUI installation (CLI only)"
    read -r -p "Enter choice [1-2] (default: 1): " GUI_CHOICE
    GUI_CHOICE=${GUI_CHOICE:-1}
    [ "$GUI_CHOICE" -eq 1 ] && CHOSEN="gnome"
    [ "$GUI_CHOICE" -eq 2 ] && CHOSEN="skip"

else
    echo "[!] Detected Desktop Environment: ${CURRENT_DESKTOP_ENV:-Generic/X11/Wayland}"
    echo "    No native shell extension available for this desktop."
    echo "    The Universal System Tray Applet (PySide6) will be used."
    echo ""
    echo "Select GUI integration option:"
    echo "  1) Universal System Tray Applet (PySide6 / Standalone) [Default]"
    echo "  2) Skip GUI installation (CLI only)"
    read -r -p "Enter choice [1-2] (default: 1): " GUI_CHOICE
    GUI_CHOICE=${GUI_CHOICE:-1}
    [ "$GUI_CHOICE" -eq 1 ] && CHOSEN="tray"
    [ "$GUI_CHOICE" -eq 2 ] && CHOSEN="skip"
fi

# Obsługa kolizji z wcześniej zainstalowanymi apletami
if [ "$CHOSEN" != "kde" ] && [ -d "$PLASMA_DEST" ]; then
    read -r -p "Notice: Existing KDE Plasma applet found. Remove it? [y/N]: " RM_PL
    [[ "$RM_PL" =~ ^[Yy]$ ]] && remove_plasma
fi
if [ "$CHOSEN" != "gnome" ] && [ -d "$GNOME_DEST" ]; then
    read -r -p "Notice: Existing GNOME Extension found. Remove it? [y/N]: " RM_GN
    [[ "$RM_GN" =~ ^[Yy]$ ]] && remove_gnome
fi
if [ "$CHOSEN" != "tray" ] && { [ -f "$TRAY_BIN" ] || [ -f "$AUTOSTART_FILE" ]; }; then
    read -r -p "Notice: Existing Universal Tray applet found. Remove it? [y/N]: " RM_TR
    [[ "$RM_TR" =~ ^[Yy]$ ]] && remove_tray
fi

# Instalacja wybranego apletu
case "$CHOSEN" in
    kde)
        mkdir -p "$(dirname "$PLASMA_DEST")"
        rm -rf "$PLASMA_DEST"
        cp -r "$PLASMA_SRC" "$PLASMA_DEST"

        read -r -p "Enable multi-language auto-detection? [Y/n]: " LOCALE_CHOICE
        LOCALE_CHOICE=${LOCALE_CHOICE:-Y}
        if [[ "$LOCALE_CHOICE" =~ ^[Nn]$ ]]; then
            sed -i 's/var enabled = true;/var enabled = false;/' "$PLASMA_DEST/contents/ui/i18n.js"
            echo "[*] Translations disabled. Defaulting to English."
        fi

        rm -rf "$HOME/.cache/plasma"* "$HOME/.cache/qmlcache"*
        read -r -p "Restart Plasmashell to load applet? [Y/n]: " RESTART_CHOICE
        RESTART_CHOICE=${RESTART_CHOICE:-Y}
        if [[ "$RESTART_CHOICE" =~ ^[Yy]$ ]]; then
            killall plasmashell 2>/dev/null || true
            sleep 1
            nohup plasmashell >/dev/null 2>&1 &
        fi
        echo "[+] KDE Plasma applet deployed."
        ;;

    gnome)
        mkdir -p "$(dirname "$GNOME_DEST")"
        rm -rf "$GNOME_DEST"
        cp -r "$GNOME_SRC" "$GNOME_DEST"

        if command -v gnome-extensions &>/dev/null; then
            gnome-extensions enable "blackwell-egpu@com.github.blackwellegpu" 2>/dev/null || true
        fi
        echo "[+] GNOME Shell extension deployed and enabled."
        echo "[*] Note: On Wayland, you may need to log out and log back in to load new GNOME extensions."
        ;;

    tray)
        install_tray || echo "[!] Universal Tray installation skipped."
        ;;

    skip)
        echo "[*] Skipping GUI applet installation. CLI backend is fully operational."
        ;;
esac

echo ""
if [ "$UDEV_NEWLY_INSTALLED" = true ]; then
    echo "======================================================================"
    echo "[!] IMPORTANT SETUP NOTICE"
    echo "    Custom udev rules were installed for the first time."
    echo "    A system reboot is strongly recommended before connecting your eGPU."
    echo "======================================================================"

    read -r -p "Reboot system now? [y/N]: " REBOOT_CHOICE
    REBOOT_CHOICE=${REBOOT_CHOICE:-N}
    if [[ "$REBOOT_CHOICE" =~ ^[Yy]$ ]]; then
        echo "[*] Rebooting system..."
        sudo reboot
    else
        echo -e "\n[+] Installation completed! Please remember to reboot before attaching eGPU."
    fi
else
    echo "[+] Installation/Update completed successfully!"
fi
