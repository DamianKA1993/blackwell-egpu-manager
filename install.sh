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
    echo "[+] Checking GTK / AyatanaAppIndicator dependencies..."

    set +e
    python3 -c "
import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk
try:
    gi.require_version('AyatanaAppIndicator3', '0.1')
except ValueError:
    gi.require_version('AppIndicator3', '0.1')
" >/dev/null 2>&1
    GI_STATUS=$?
    set -e

    if [ $GI_STATUS -ne 0 ]; then
        echo "----------------------------------------------------------------------"
        echo "[!] MISSING DEPENDENCY: GTK3 AppIndicator libraries are required."
        echo "----------------------------------------------------------------------"

        read -r -p "Install native indicator libraries automatically now? [Y/n]: " DEP_CHOICE
        DEP_CHOICE=${DEP_CHOICE:-Y}
        if [[ "$DEP_CHOICE" =~ ^[Yy]$ ]]; then
            if command -v pacman &>/dev/null; then
                sudo pacman -S --needed --noconfirm python-gobject libayatana-appindicator gtk3
            elif command -v apt-get &>/dev/null; then
                sudo apt-get update -qq && sudo apt-get install -y python3-gi gir1.2-ayatanaappindicator3-0.1 gir1.2-gtk-3.0
            elif command -v dnf &>/dev/null; then
                sudo dnf install -y python3-gobject libayatana-appindicator-gtk3 gtk3
            elif command -v zypper &>/dev/null; then
                sudo zypper install -y python3-gobject typelib-1_0-AyatanaAppIndicator3-0_1 gtk3
            else
                echo "[-] Package manager not supported for auto-install. Please install AyatanaAppIndicator manually."
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
    echo "  2) Skip GUI installation (CLI only)"
    read -r -p "Enter choice [1-2] (default: 1): " GUI_CHOICE
    case "${GUI_CHOICE:-1}" in
        1) CHOSEN="kde" ;;
        2) CHOSEN="skip" ;;
        *) CHOSEN="kde" ;;
    esac

elif [[ "$CURRENT_DESKTOP_ENV" =~ [Gg][Nn][Oo][Mm][Ee] ]]; then
    echo "[+] Detected Desktop Environment: GNOME Shell"
    echo "Select GUI integration option:"
    echo "  1) Native GNOME Shell Extension [Default]"
    echo "  2) Skip GUI installation (CLI only)"
    read -r -p "Enter choice [1-2] (default: 1): " GUI_CHOICE
    case "${GUI_CHOICE:-1}" in
        1) CHOSEN="gnome" ;;
        2) CHOSEN="skip" ;;
        *) CHOSEN="gnome" ;;
    esac

else
    echo "[!] Detected Desktop Environment: ${CURRENT_DESKTOP_ENV:-Generic/X11/Wayland}"
    echo "    No native shell extension available for this desktop."
    echo "    The Universal System Tray Applet (Native GTK / Ayatana) will be used."
    echo ""
    echo "Select GUI integration option:"
    echo "  1) Universal System Tray Applet (Native GTK / Ayatana) [Default]"
    echo "  2) Skip GUI installation (CLI only)"
    read -r -p "Enter choice [1-2] (default: 1): " GUI_CHOICE
    case "${GUI_CHOICE:-1}" in
        1) CHOSEN="tray" ;;
        2) CHOSEN="skip" ;;
        *) CHOSEN="tray" ;;
    esac
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
        echo "[+] GNOME Shell extension files copied."

        # Pytanie o automatyczne włączenie apletu z domyślnym wyborem: TAK
        read -r -p "Enable Blackwell eGPU extension by default? [Y/n]: " ENABLE_EXT_CHOICE
        ENABLE_EXT_CHOICE=${ENABLE_EXT_CHOICE:-Y}

        if [[ "$ENABLE_EXT_CHOICE" =~ ^[Yy]$ ]]; then
            UUID="blackwell-egpu@com.github.blackwellegpu"

            # 1. Próba standardowa przez CLI GNOME
            if command -v gnome-extensions &>/dev/null; then
                gnome-extensions enable "$UUID" 2>/dev/null || true
            fi

            # 2. Bezpośrednie wstrzyknięcie do dconf/gsettings (kluczowe na świeżej sesji / Live CD)
            if command -v gsettings &>/dev/null; then
                CURRENT_EXTS=$(gsettings get org.gnome.shell enabled-extensions)
                if ! echo "$CURRENT_EXTS" | grep -q "$UUID"; then
                    if [ "$CURRENT_EXTS" = "@as []" ] || [ "$CURRENT_EXTS" = "[]" ]; then
                        NEW_EXTS="['$UUID']"
                    else
                        NEW_EXTS="${CURRENT_EXTS%]}, '$UUID']"
                    fi
                    gsettings set org.gnome.shell enabled-extensions "$NEW_EXTS" 2>/dev/null || true
                fi
            fi
            echo "[+] Extension marked as enabled in GNOME configuration."
        else
            echo "[*] Extension installed in disabled state."
        fi

        # Wykrywanie typu sesji i propozycja restartu powłoki / sesji
        SESSION_TYPE="${XDG_SESSION_TYPE:-unknown}"

        if [ "$SESSION_TYPE" = "wayland" ]; then
            echo "----------------------------------------------------------------------"
            echo "[!] Notice: Running on Wayland. GNOME cannot reload extensions in-place."
            echo "    A session restart is required to load/update the extension."
            echo "    WARNING: This will close your open applications and log you out."
            echo "----------------------------------------------------------------------"
            read -r -p "Restart GNOME session now? [y/N]: " RESTART_GNOME
            RESTART_GNOME=${RESTART_GNOME:-N}
            if [[ "$RESTART_GNOME" =~ ^[Yy]$ ]]; then
                echo "[*] Restarting GNOME session..."
                systemctl --user restart gnome-session.target 2>/dev/null || gnome-session-quit --logout --no-prompt
            else
                echo "[*] Skipping restart. Please log out and log back in manually."
            fi
        else
            read -r -p "Restart GNOME Shell to load extension now? [Y/n]: " RESTART_GNOME
            RESTART_GNOME=${RESTART_GNOME:-Y}
            if [[ "$RESTART_GNOME" =~ ^[Yy]$ ]]; then
                busctl --user call org.gnome.Shell /org/gnome/Shell org.gnome.Shell Eval s 'Meta.restart("Restarting…")' >/dev/null 2>&1 || true
                echo "[+] GNOME Shell reloaded."
            fi
        fi
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
