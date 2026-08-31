# ⚡ Blackwell eGPU Universal Manager (USB4 / TB4 / TB5)

Automated PCIe Gen4/Gen5 hardware state management, USB4 link negotiation, and display switching for **NVIDIA Blackwell (RTX 50xx)** eGPUs on Linux (KDE Plasma 6 Wayland / CachyOS / Arch Linux).

![update140](assets/preview1.png)

---

## ⚡ Prerequisites & System Requirements

Before using this project, please review the following hardware and system requirements:

1. **Interface Scope (USB4 / Thunderbolt Only):**
   * Designed exclusively for eGPUs connected via **USB4, Thunderbolt 4, or Thunderbolt 5**.
   * It is **not** designed for or tested with OCuLink interfaces.

2. **Supported Host Graphics (iGPU AMD / Intel):**
   * Intended strictly for host systems featuring an **integrated GPU (AMD Radeon or Intel Iris/Arc)**.
   * Laptops with internal dedicated NVIDIA GPUs (dGPU) are **not supported** due to bus topology conflicts and module namespace overlap.

3. **Immutable Distro Compatibility (Notice):**
   * Immutable / Atomic operating systems (e.g., Bazzite, Fedora Silverblue) are **not officially supported out of the box**.
   * While the backend logic may execute correctly, system updates on immutable OSs risk overwriting or removing the required `/etc/udev/rules.d/` gating configuration.

4. **Desktop Environment & Daemon Architecture:**
   * Full functionality and automated polling are built for **KDE Plasma 6**.
   * The Plasma applet acts as the background daemon, querying the backend script every 2 seconds for real-time telemetry.
   * Headless / CLI-only usage is supported via terminal commands. (Community contributions for GNOME extensions or other DE applets are welcome).

5. **Driver Requirements (`nvidia-open`):**
   * Requires official **NVIDIA Open GPU Kernel Modules** (`nvidia-open`).
   * Compatible with driver version **580.xx and newer**.

> ⚡ **Ready to proceed?** If you have reviewed all 5 prerequisites above and your hardware and system environment meet these conditions, you can proceed with the Quick Start installation below.

---

## 🚀 Quick Start

Clone the repository and run the automated interactive installer:

```bash
git clone [https://github.com/DamianKA1993/blackwell-egpu-manager.git](https://github.com/DamianKA1993/blackwell-egpu-manager.git)
cd blackwell-egpu-manager
chmod +x install.sh uninstall.sh
./install.sh
