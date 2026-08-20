#!/usr/bin/env bash
set -e

# ==============================================================================
# iGPU / Blackwell eGPU Universal Manager - Installer (State Machine v2.2)
# Target: CachyOS / Arch Linux (KDE Plasma 6 Wayland)
# ==============================================================================

if [ "$EUID" -eq 0 ]; then
  echo "[-] Error: Run this script as a normal user (without sudo)."
  echo "    The installer will prompt for root privileges when needed."
  exit 1
fi

APPLET_ID="org.cachyos.blackwellegpu"
OLD_APPLET_ID="org.cachyos.egpuswitcher"
CURRENT_USER="$USER"

QDBUS_CMD="qdbus6"
command -v qdbus6 >/dev/null 2>&1 || QDBUS_CMD="qdbus"

echo "=== 1. Checking NVIDIA Open Kernel Driver ==="
if ! pacman -Qs "nvidia-open" >/dev/null 2>&1 && ! modinfo nvidia 2>/dev/null | grep -iq "license.*dual"; then
    echo "----------------------------------------------------------------------"
    echo "[!] WARNING: NVIDIA Open Kernel module not detected!"
    echo "    Blackwell GPUs (RTX 50xx) require open-source kernel modules."
    echo "    Please install: 'nvidia-open-dkms' (or 'nvidia-open') and kernel headers."
    echo "----------------------------------------------------------------------"
    read -r -p "Press [Enter] to acknowledge and continue, or Ctrl+C to abort..."
else
    echo "[+] NVIDIA Open Kernel module detected."
fi

echo "=== 2. Generating CLI backend (/usr/local/bin/blackwell-egpu) ==="
sudo bash -c 'cat << "EOF" > /usr/local/bin/blackwell-egpu
#!/usr/bin/env bash
set -e

negotiate_optimal_link_speed() {
    local GPU_PCI="$1"
    local PARENT_PORT="$2"

    local gpu_speed parent_speed
    gpu_speed=$(lspci -s "$GPU_PCI" -vv 2>/dev/null | awk '\''/LnkCap:/ {for(i=1;i<=NF;i++) if($i ~ /Speed/) print $(i+1)}'\'' | tr -dc '\''0-9'\'')
    parent_speed=$(lspci -s "$PARENT_PORT" -vv 2>/dev/null | awk '\''/LnkCap:/ {for(i=1;i<=NF;i++) if($i ~ /Speed/) print $(i+1)}'\'' | tr -dc '\''0-9'\'')

    local min_speed=${gpu_speed:-16}
    if [ -n "$parent_speed" ] && [ "$parent_speed" -lt "$min_speed" ]; then
        min_speed=$parent_speed
    fi

    case "$min_speed" in
        32*) echo "0025" ;; # Gen5
        16*) echo "0024" ;; # Gen4
        8*)  echo "0023" ;; # Gen3
        *)   echo "0024" ;; # Bezpieczny standard
    esac
}

detach_amd_igpu() {
    local AMD_IGPU
    AMD_IGPU=$(lspci -D -d 1002: -nn 2>/dev/null | grep -iE "VGA|Display" | awk "{print \$1}" | head -n 1)
    if [ -n "$AMD_IGPU" ] && [ -e "/sys/bus/pci/devices/$AMD_IGPU/remove" ]; then
        echo "[*] Detaching AMD iGPU ($AMD_IGPU)..."
        echo 1 > "/sys/bus/pci/devices/$AMD_IGPU/remove" 2>/dev/null || true
    fi
}

attach_amd_igpu() {
    if ! compgen -G "/sys/bus/pci/drivers/amdgpu/0000:*" > /dev/null; then
        echo "[*] Restoring AMD iGPU bus..."
        echo 1 > /sys/bus/pci/rescan 2>/dev/null || true
        udevadm settle --timeout=2 2>/dev/null || true
    fi
}

stabilize_pcie_bus() {
    echo "[*] Unloading NVIDIA modules before PCIe retraining..."
    fuser -k /dev/nvidia* 2>/dev/null || true
    modprobe -r nvidia_uvm nvidia_drm nvidia_modeset nvidia 2>/dev/null || true

    if command -v boltctl >/dev/null 2>&1; then
        local PENDING_UUIDS
        PENDING_UUIDS=$(boltctl list 2>/dev/null | awk '\''/ ● / {uuid=$2} /status:[[:space:]]+(connected|authorizing)/ {print uuid}'\'')
        for uuid in $PENDING_UUIDS; do
            echo "[*] Authorizing Thunderbolt device ($uuid)..."
            boltctl enroll --policy auto "$uuid" 2>/dev/null || boltctl authorize "$uuid" 2>/dev/null || true
        done
    fi

    touch /tmp/egpu_allow
    echo 1 > /sys/bus/pci/rescan 2>/dev/null
    udevadm settle --timeout=2 2>/dev/null || true
    rm -f /tmp/egpu_allow

    GPU_FULL_PCI=$(lspci -D -d 10de: -nn 2>/dev/null | grep -iE "VGA|3D" | awk "{print \$1}" | head -n 1)
    if [ -z "$GPU_FULL_PCI" ]; then
        echo "[-] Error: No NVIDIA GPU detected on PCIe bus."
        return 1
    fi
    echo "[+] Detected eGPU: $GPU_FULL_PCI"

    PCI_TREE=$(lspci -D -PP -s "$GPU_FULL_PCI" 2>/dev/null | awk "{print \$1}")
    IFS="/" read -ra BRIDGE_LIST <<< "$PCI_TREE"
    TOTAL_NODES=${#BRIDGE_LIST[@]}

    echo performance > /sys/module/pcie_aspm/parameters/policy 2>/dev/null || true

    for node in "${BRIDGE_LIST[@]}"; do
        setpci -s "$node" CAP_EXP+10.w=0000 2>/dev/null || true
        setpci -s "$node" ECAP_1E+04.l=00000000 2>/dev/null || true
    done

    if [ "$TOTAL_NODES" -ge 2 ]; then
        PARENT_PORT="${BRIDGE_LIST[$((TOTAL_NODES - 2))]}"

        TARGET_HEX=$(negotiate_optimal_link_speed "$GPU_FULL_PCI" "$PARENT_PORT")

        setpci -s "$PARENT_PORT" CAP_EXP+30.w="$TARGET_HEX:002f" 2>/dev/null || true
        setpci -s "$GPU_FULL_PCI" CAP_EXP+30.w="$TARGET_HEX:002f" 2>/dev/null || true
        setpci -s "$PARENT_PORT" CAP_EXP+10.w=0020:0020 2>/dev/null || true

        local retries=0
        while [ $retries -lt 30 ]; do
            local lnksta
            lnksta=$(setpci -s "$PARENT_PORT" CAP_EXP+12.w 2>/dev/null)
            local val=$(( 16#${lnksta:-0} ))
            if [ $(( val & 0x0800 )) -eq 0 ] && [ $(( val & 0x2000 )) -ne 0 ]; then
                echo "[+] Link stable: 0x$lnksta"
                break
            fi
            sleep 0.1
            retries=$((retries + 1))
        done
    fi

    sleep 0.5
    modprobe nvidia NVreg_DynamicPowerManagement=0x00 2>/dev/null || true

    if [ -n "$PARENT_PORT" ]; then
        setpci -s "$PARENT_PORT" CAP_EXP+30.w="$TARGET_HEX:002f" 2>/dev/null || true
    fi

    modprobe nvidia_modeset nvidia_drm nvidia_uvm 2>/dev/null || true
    udevadm settle

    # Dynamic clock stabilization for Blackwell GPUs
    nvidia-smi -pm 1 >/dev/null 2>&1 || true

    MAX_GPU=$(nvidia-smi --query-gpu=clocks.max.graphics --format=csv,noheader,nounits 2>/dev/null | head -n 1 | tr -d '\''[:space:]'\'')
    MAX_MEM=$(nvidia-smi --query-gpu=clocks.max.memory --format=csv,noheader,nounits 2>/dev/null | head -n 1 | tr -d '\''[:space:]'\'')

    MAX_GPU=${MAX_GPU:-3090}
    MAX_MEM=${MAX_MEM:-14001}

    nvidia-smi --auto-boost-permission=0 >/dev/null 2>&1 || true
    nvidia-smi --lock-gpu-clocks="2000,$MAX_GPU" >/dev/null 2>&1 || true
    nvidia-smi --lock-memory-clocks="$MAX_MEM,$MAX_MEM" >/dev/null 2>&1 || true
}

ensure_egpu_ready() {
    if ! lsmod | grep -q "^nvidia "; then
        stabilize_pcie_bus
    fi
}

case "$1" in
    mode0|detach|igpu)
        echo "[*] Switching to State 0: iGPU Only..."
        fuser -k /dev/nvidia* 2>/dev/null || true
        modprobe -r nvidia_uvm nvidia_drm nvidia_modeset nvidia 2>/dev/null || true

        GPU_FULL_PCI=$(lspci -D -d 10de: -nn 2>/dev/null | grep -iE "VGA|3D" | awk "{print \$1}" | head -n 1)
        if [ -n "$GPU_FULL_PCI" ]; then
            GPU_SLOT="${GPU_FULL_PCI%.*}"
            for dev in "/sys/bus/pci/devices/${GPU_SLOT}".*; do
                [ -f "$dev/remove" ] && echo 1 > "$dev/remove" 2>/dev/null || true
            done
        fi

        attach_amd_igpu
        echo "[+] State 0 Active: Pure iGPU."
        ;;

    mode1|hybrid|egpu-int|attach)
        echo "[*] Switching to State 1: Hybrid Mode (iGPU + eGPU)..."
        attach_amd_igpu
        ensure_egpu_ready
        echo "[+] State 1 Active: Hybrid Graphics."
        ;;

    mode2|egpu-ext)
        echo "[*] Switching to State 2: eGPU Only (External Display)..."
        ensure_egpu_ready
        detach_amd_igpu
        echo "[+] State 2 Active: eGPU Only."
        ;;

    status)
        if lsmod | grep -q "^nvidia "; then
            if compgen -G "/sys/bus/pci/drivers/amdgpu/0000:*" > /dev/null; then
                echo "mode1"
            else
                echo "mode2"
            fi
        else
            echo "mode0"
        fi
        ;;

    *)
        echo "Usage: blackwell-egpu {mode0|mode1|mode2|status}"
        exit 1
        ;;
esac
EOF'

sudo chmod +x /usr/local/bin/blackwell-egpu

echo "=== 3. Configuring sudoers permissions ==="
echo "$CURRENT_USER ALL=(ALL) NOPASSWD: /usr/local/bin/blackwell-egpu" | sudo tee "/etc/sudoers.d/blackwell-egpu" > /dev/null
sudo chmod 0440 "/etc/sudoers.d/blackwell-egpu"

echo "=== 4. Configuring udev rules ==="
read -r -p "Install udev rules to prevent unconfigured module autoloading on USB4/TB? [Y/n]: " UDEV_CHOICE
UDEV_CHOICE=${UDEV_CHOICE:-Y}

if [[ "$UDEV_CHOICE" =~ ^[YyTt]$ ]]; then
    sudo bash -c 'cat << "EOF" > /etc/udev/rules.d/99-blackwell-egpu.rules
# Intel Barlow Ridge (AORUS TB5)
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0x5786", TEST!="/tmp/egpu_allow", ATTR{remove}="1"

# ASMedia ASM2464PD (USB4)
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x1b21", ATTR{device}=="0x2464", TEST!="/tmp/egpu_allow", ATTR{remove}="1"

# Intel Goshen / Titan Ridge (TB3/TB4)
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0x15eb", TEST!="/tmp/egpu_allow", ATTR{remove}="1"
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0x0b26", TEST!="/tmp/egpu_allow", ATTR{remove}="1"
EOF'
    sudo udevadm control --reload-rules
    echo "[+] udev rules successfully installed."
else
    echo "[*] Skipped udev rule installation."
fi

echo "=== 5. Installing Plasma 6 Native Applet ==="
PLASMOID_DIR="$HOME/.local/share/plasma/plasmoids/$APPLET_ID"
mkdir -p "$PLASMOID_DIR/contents/ui"

cat << "EOF" > "$PLASMOID_DIR/metadata.json"
{
    "KPackageStructure": "Plasma/Applet",
    "KPlugin": {
        "Authors": [{"Name": "OpenSource Contributor"}],
        "Category": "System Information",
        "Description": "Control Blackwell eGPU over USB4/TB5",
        "Icon": "video-display",
        "Id": "org.cachyos.blackwellegpu",
        "Name": "Blackwell eGPU Manager",
        "Version": "2.2"
    },
    "X-Plasma-API-Minimum-Version": "6.0",
    "X-Plasma-MainScript": "ui/main.qml"
}
EOF

cat << "EOF" > "$PLASMOID_DIR/contents/ui/main.qml"
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root
    preferredRepresentation: compactRepresentation

    property bool egpuAvailable: false
    property string activeMode: "mode0"
    property string detectedName: "AORUS RTX506T AI BOX (USB4)"
    property string activeGpuName: "Radeon 780M (Integrated)"

    P5Support.DataSource {
        id: statusEngine
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            var stdout = (data["stdout"] || "").trim();

            if (sourceName.indexOf("check_presence") !== -1) {
                root.egpuAvailable = stdout.length > 0;
            } else if (sourceName.indexOf("check_mode") !== -1) {
                root.activeMode = stdout;
                if (stdout === "mode2") {
                    root.activeGpuName = "NVIDIA RTX eGPU (External Only)";
                } else if (stdout === "mode1") {
                    root.activeGpuName = "Hybrid (Radeon 780M + NVIDIA RTX)";
                } else {
                    root.activeGpuName = "Radeon 780M (Integrated)";
                }
            }
            disconnectSource(sourceName);
        }
        function refreshStatus() {
            connectSource("/bin/sh -c 'boltctl list 2>/dev/null | grep -iE \"connected|authorized\" || lspci -d 8086:5786 2>/dev/null || lspci -d 10de: 2>/dev/null || lspci -d 1b21:2464 2>/dev/null' # check_presence");
            connectSource("/usr/local/bin/blackwell-egpu status # check_mode");
        }
    }

    P5Support.DataSource {
        id: actionRunner
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            disconnectSource(sourceName);
            statusEngine.refreshStatus();
        }
        function exec(cmd) {
            connectSource(cmd);
        }
    }

    onExpandedChanged: {
        if (expanded) {
            statusEngine.refreshStatus();
        }
    }

    Component.onCompleted: {
        statusEngine.refreshStatus();
    }

    compactRepresentation: MouseArea {
        onClicked: root.expanded = !root.expanded
        Kirigami.Icon {
            anchors.fill: parent
            source: root.activeMode !== "mode0" ? "video-display" : "video-television"
        }
    }

    fullRepresentation: ColumnLayout {
        Layout.preferredWidth: 320
        Layout.preferredHeight: implicitHeight
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Kirigami.Icon {
                source: "video-display"
                implicitWidth: 36
                implicitHeight: 36
            }

            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true

                QQC2.Label {
                    text: "eGPU Manager"
                    font.bold: true
                    font.pixelSize: 13
                }

                RowLayout {
                    spacing: 4
                    QQC2.Label {
                        text: "Detected:"
                        font.pixelSize: 11
                        opacity: 0.7
                    }
                    QQC2.Label {
                        text: root.egpuAvailable ? root.detectedName : "None"
                        font.pixelSize: 11
                        font.bold: true
                        elide: Text.ElideRight
                    }
                }

                RowLayout {
                    spacing: 4
                    QQC2.Label {
                        text: "Active:"
                        color: "#27ae60"
                        font.bold: true
                        font.pixelSize: 11
                    }
                    QQC2.Label {
                        text: root.activeGpuName
                        font.pixelSize: 11
                        font.bold: true
                        elide: Text.ElideRight
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(255, 255, 255, 0.12)
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: root.egpuAvailable

            // OPCJA 2: eGPU Only (Stan 2)
            QQC2.Button {
                Layout.fillWidth: true
                enabled: root.activeMode !== "mode2"
                contentItem: RowLayout {
                    spacing: 8
                    Kirigami.Icon {
                        source: root.activeMode === "mode2" ? "dialog-ok" : "video-display"
                        color: root.activeMode === "mode2" ? "#27ae60" : (parent.parent.enabled ? "white" : "#666666")
                        implicitWidth: 16
                        implicitHeight: 16
                    }
                    QQC2.Label {
                        text: "eGPU + External Display"
                        font.bold: root.activeMode === "mode2"
                        color: parent.parent.enabled ? "white" : "#666666"
                        Layout.fillWidth: true
                    }
                }
                onClicked: {
                    root.activeMode = "mode2";
                    root.activeGpuName = "NVIDIA RTX eGPU (External Only)";
                    actionRunner.exec("sudo /usr/local/bin/blackwell-egpu mode2");
                    root.expanded = false;
                }
            }

            // OPCJA 1: Hybrid Mode (Stan 1)
            QQC2.Button {
                Layout.fillWidth: true
                enabled: root.activeMode === "mode0"
                contentItem: RowLayout {
                    spacing: 8
                    Kirigami.Icon {
                        source: root.activeMode === "mode1" ? "dialog-ok" : "edit-copy"
                        color: root.activeMode === "mode1" ? "#27ae60" : (parent.parent.enabled ? "white" : "#666666")
                        implicitWidth: 16
                        implicitHeight: 16
                    }
                    QQC2.Label {
                        text: "eGPU + Internal Display"
                        font.bold: root.activeMode === "mode1"
                        color: parent.parent.enabled ? "white" : "#666666"
                        Layout.fillWidth: true
                    }
                }
                onClicked: {
                    root.activeMode = "mode1";
                    root.activeGpuName = "Hybrid (Radeon 780M + NVIDIA RTX)";
                    actionRunner.exec("sudo /usr/local/bin/blackwell-egpu mode1");
                    root.expanded = false;
                }
            }

            // OPCJA 0: iGPU Only (Stan 0)
            QQC2.Button {
                Layout.fillWidth: true
                enabled: false
                contentItem: RowLayout {
                    spacing: 8
                    Kirigami.Icon {
                        source: root.activeMode === "mode0" ? "dialog-ok" : "video-television"
                        color: root.activeMode === "mode0" ? "#27ae60" : (parent.parent.enabled ? "white" : "#666666")
                        implicitWidth: 16
                        implicitHeight: 16
                    }
                    QQC2.Label {
                        text: "iGPU Only (Integrated)"
                        font.bold: root.activeMode === "mode0"
                        color: parent.parent.enabled ? "white" : "#666666"
                        Layout.fillWidth: true
                    }
                }
                onClicked: {
                    root.activeMode = "mode0";
                    root.activeGpuName = "Radeon 780M (Integrated)";
                    actionRunner.exec("sudo /usr/local/bin/blackwell-egpu mode0");
                    root.expanded = false;
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: !root.egpuAvailable

            QQC2.Label {
                text: "No Blackwell eGPU available"
                color: "#888888"
                font.pixelSize: 11
                Layout.alignment: Qt.AlignHCenter
            }

            QQC2.Button {
                text: "Rescan Bus"
                icon.name: "view-refresh"
                Layout.fillWidth: true
                onClicked: {
                    statusEngine.refreshStatus();
                }
            }
        }
    }
}
EOF

kbuildsycoca6 --noincremental >/dev/null 2>&1 || true

echo "=== 6. Updating KDE Plasma Panel ==="
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
    if (p.location === "bottom" || p.location === "top") {
        p.addWidget("$APPLET_ID");
    }
}
EOF
)

$QDBUS_CMD org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$JS_PAYLOAD" >/dev/null 2>&1 || true

echo -e "\n[+] Installation complete! State Machine v2.2 with Gen4 negotiation is now active."
