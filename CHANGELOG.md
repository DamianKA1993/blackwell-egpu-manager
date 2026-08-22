# Changelog

All notable changes to the Blackwell eGPU Universal Manager project will be documented in this file.

## [1.1.0] - 2026-08-22

### Architecture & Installation
* **Modular Installer (`install.sh`)**: Refactored the installer into an interactive, step-by-step wizard.
* **Decoupled KDE Plasma 6 Applet**: The Plasmoid is now completely optional; the backend CLI (`blackwell-egpu`) works fully independently in headless or pure terminal environments.
* **Automated Environment Setup**: Added automated checks for `nvidia-open` kernel modules, udev rule installation, `sudoers` rule generation, and Plasmashell cache reloading.

### KDE Plasma 6 Applet (`com.github.blackwellegpu`)
* **Fixed Geometry & Aspect Ratio**: Locked the root `fullRepresentation` bounds to a fixed 24x24 `gridUnit` container, completely resolving the dynamic window shrinking/collapsing bug.
* **Modern Plasma 6 System Layout**: Redesigned UI to match native system widgets (such as the Plasma Network & Bluetooth applets), including styled category separators and medium hardware icons.
* **Centrally Stacked Control Buttons**: Redesigned action buttons from a wide horizontal layout to a clean, vertically stacked list centered in the lower container area.
* **Text Wrapping & Typography**: Enabled multi-line text wrapping (`Text.Wrap`) on verbose device strings (such as long iGPU/eGPU PCI naming) to prevent UI overflow.

### Hardware State Detection & Backend
* **Eliminated Ghost Devices (Hot-Unplug)**: Replaced stale caching with direct, synchronous `/sys/bus/pci/devices/` queries and `boltctl` link checks. When disconnected, the applet immediately falls back to Mode 0 (`Disconnected`) without leaving leftover device traces.
* **Verified Dual-Platform Support**: Successfully validated Mode 0–4 switching, hot-plugging, cold boot, and real-time PCIe speed reporting (16GT/s) across AMD APU (HawkPoint) and Intel (Tiger Lake / Iris Xe) host systems.
* **Driver & Offload Integration**: Verified PRIME Render Offload (`Mode 3`) and Dedicated Mode (`Mode 4`) compatibility with `linux-cachyos-nvidia-open` (NVIDIA 610.xx driver series).

---

## [1.0.0] - 2026-08-20

### Initial Release
* Initial monolithic release of the `blackwell-egpu` CLI manager for RTX 50-series (Blackwell) eGPUs.
* Basic udev rules for Barlow Ridge (TB5), Goshen Ridge (TB4), and ASMedia ASM2464PD (USB4).
* Basic Plasma 6 applet prototype.
