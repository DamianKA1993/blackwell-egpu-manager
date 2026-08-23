# ⚡ Blackwell eGPU Universal Manager (USB4 / TB4 / TB5)

Automated PCIe Gen4/Gen5 hardware state management, USB4 link negotiation, and display switching for **NVIDIA Blackwell (RTX 50xx)** eGPUs on Linux (KDE Plasma 6 Wayland / CachyOS / Arch Linux).

## 💡 Important Notes (Intel Platform & First-Time Setup)

* **Intel Cold-Plug Warning**: On Intel host platforms, connecting the eGPU before powering on the system (cold-plug) may cause PCIe bridge enumeration conflicts, leading to applet initialization errors (such as NVML failing to detect the GPU in early boot). It is strongly recommended to connect/power on the eGPU after the system has fully booted into the desktop.
* **Post-Installation Reboot**: The installer deploys custom udev rules to prevent PCIe link stalls and improper driver auto-binding. A **system reboot is required** after running `install.sh` for these rules to fully take effect and ensure a clean, fixed link negotiation.

![Authorization Mode](assets/preview.jpg)

---

## 🚀 Key Features

* **Dynamic Multi-Platform Discovery**: Real-time detection of host iGPU (AMD Phoenix/HawkPoint/Strix APUs and Intel 11th Gen+ Tiger Lake / Iris Xe / Core Ultra) and NVIDIA RTX 50-series Blackwell eGPUs with zero hardcoded PCI paths.
* **Ghost-Free Hardware State Engine**: Direct synchronous querying of `/sys/bus/pci/devices/` and `boltctl` connection states, eliminating phantom devices during hot-unplug events.
* **PCIe 4.0 / USB4 Link Negotiation**: Real-time link speed detection and display (up to 16 GT/s PCIe 4.0 x4) across Intel Barlow Ridge, Goshen Ridge, and ASMedia ASM2464PD bridges.
* **5-Mode Hardware State Switching Engine**:
  * **Mode 0 (Disconnected)**: USB4 / PCIe bus detached; zero power draw.
  * **Mode 1 (Unauthorized)**: Device detected via USB4/Thunderbolt, awaiting host authorization.
  * **Mode 2 (Standby / Ready)**: Controller authorized, card recognized on PCIe bus and kept in low-power standby (D3cold).
  * **Mode 3 (Hybrid Offload / PRIME)**: Active iGPU runs desktop displays while RTX 5060 Ti handles on-demand GPU offloading (`prime-run` / CUDA / Vulkan).
  * **Mode 4 (Dedicated Primary / eGPU Only)**: Dedicated GPU rendering session for external display setups with experimental runtime iGPU PCI-bus removal.
* **Multi-Language Support (i18n)**: Built-in localization support for 10 languages (`en`, `pl`, `de`, `es`, `fr`, `it`, `pt`, `uk`, `cs`, `ja`, `zh`) with automatic desktop locale detection and fallback handling.
* **KDE Display Settings Integration**: Instant one-click launcher for KDE Screen Management (`kcm_kscreen`) directly from the widget.
* **Modular Interactive Installer & Uninstaller**: Clean Bash wizards with optional udev rule management, sudoers configuration, and desktop widget deployment.
* **Native KDE Plasma 6 Applet**: Standalone Plasmoid with fixed proportions (24x24 gridUnit), live link-speed badge, and vertically centered control buttons.

---

![Intel Workflow](assets/preview2.jpg)

## ⚠️ Experimental Feature Warning

> **Mode 4 (eGPU Only / Disable iGPU)** dynamically removes the integrated GPU and its associated audio controller directly from the PCI tree (`/sys/bus/pci/devices/*/remove`). This forces KDE Plasma and Wayland to render exclusively on the external GPU. While tested and functional, runtime iGPU bus removal is **highly experimental**. Use at your own risk.

---

## 📋 Requirements

* **OS**: CachyOS, Arch Linux, or other rolling-release distributions with Linux Kernel >= 6.10 (tested on Linux 7.2.0-cachyos).
* **Desktop**: KDE Plasma 6 (Wayland recommended; purely optional for standalone CLI usage).
* **Driver & Dependencies**:
  * NVIDIA Open Kernel Modules: `linux-cachyos-nvidia-open`, `nvidia-open-dkms`, or `nvidia-open` (610.xx+ driver series).
  * System tools: `nvidia-utils` (for NVML / `nvidia-smi`) and `bolt` (for Thunderbolt/USB4 device authorization).
* **Supported Hardware**:
  * **eGPU**: NVIDIA RTX 50-series (Blackwell architecture, e.g. AORUS RTX 5060 Ti AI BOX).
  * **USB4 / TB Bridges**: Intel Barlow Ridge (`0x5786`), Goshen Ridge / Titan Ridge (`0x15eb`, `0x0b26`), ASMedia ASM2464PD (`0x2464`).
  * **Host CPU / iGPU**:
    * AMD Ryzen APU (Phoenix, HawkPoint, Strix Point with Radeon 780M / 890M).
    * Intel Core / Core Ultra (11th Gen Tiger Lake with Iris Xe up to Meteor Lake / Arrow Lake).

---

![AMD Workflow](assets/preview3.jpg)

## 🛠️ Installation

Clone the repository and run the interactive installer as a regular user:

```bash
git clone https://github.com/DamianKA1993/blackwell-egpu-manager.git
cd blackwell-egpu-manager
chmod +x install.sh uninstall.sh
./install.sh
```

The installer will interactively guide you through:
1. Verifying NVIDIA Open kernel module presence.
2. Installing the `/usr/local/bin/blackwell-egpu` backend CLI.
3. Setting up passwordless sudoers permissions for state switching.
4. *(Optional)* Deploying udev rules to prevent PCIe link stalls during hot-plug.
5. *(Optional)* Installing the KDE Plasma 6 widget with optional multi-language localization.

---

## 🖥️ CLI Usage

The backend CLI can be managed independently from scripts, keybindings, or terminals:

```bash
# Query current state (returns JSON formatted status)
blackwell-egpu status

# Authorize USB4/TB connection (Mode 1 -> Mode 2)
sudo blackwell-egpu set 2

# Switch to Hybrid Offload (Mode 3: PRIME render offload)
sudo blackwell-egpu set 3

# Switch to Dedicated eGPU Mode (Mode 4: Disconnect iGPU / Primary eGPU)
sudo blackwell-egpu set 4
```

---

## 🗑️ Uninstallation

To cleanly remove all installed binaries, optional udev rules, sudoers privileges, temporary caches, and the Plasma applet:

```bash
./uninstall.sh
```

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.
