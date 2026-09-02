#!/usr/bin/env python3
import json
import shutil
import subprocess
import threading
import time

import gi
gi.require_version('Gtk', '3.0')
try:
    gi.require_version('AyatanaAppIndicator3', '0.1')
    from gi.repository import AyatanaAppIndicator3 as AppIndicator
except (ValueError, ImportError):
    gi.require_version('AppIndicator3', '0.1')
    from gi.repository import AppIndicator3 as AppIndicator

from gi.repository import Gtk, GLib

CLI_PATH = "/usr/local/bin/blackwell-egpu"
HEADER_TEXT = "----------------- Blackwell eGPU Manager -----------------"

class BlackwellTrayGTK:
    def __init__(self):
        self.indicator = AppIndicator.Indicator.new(
            "blackwell-egpu-tray",
            "video-display",
            AppIndicator.IndicatorCategory.HARDWARE
        )
        self.indicator.set_status(AppIndicator.IndicatorStatus.ACTIVE)

        self.menu = Gtk.Menu()
        self.init_menu_structure()
        self.indicator.set_menu(self.menu)

        self.running = True
        self.current_icon_mode = None

        self.thread = threading.Thread(target=self.poll_backend, daemon=True)
        self.thread.start()

    def open_display_settings(self, *args):
        commands = [
            ["kcmshell6", "kcm_kscreen"],
            ["kcmshell5", "kcm_kscreen"],
            ["gnome-control-center", "display"],
            ["xfce4-display-settings"],
            ["cinnamon-settings", "display"],
            ["mate-display-properties"],
            ["lxqt-config-monitor"],
            ["wdisplays"],
            ["arandr"]
        ]
        for cmd in commands:
            if shutil.which(cmd[0]):
                subprocess.Popen(cmd)
                return

    def run_cmd(self, mode):
        subprocess.Popen(["sudo", CLI_PATH, "set", str(mode)])

    def quit_app(self, *args):
        self.running = False
        Gtk.main_quit()

    def init_menu_structure(self):
        # Nagłówek
        self.item_header = Gtk.MenuItem(label=HEADER_TEXT)
        self.item_header.connect("activate", self.open_display_settings)
        self.menu.append(self.item_header)

        # Sekcja eGPU
        self.item_section = Gtk.MenuItem(label="eGPU:")
        self.item_section.set_sensitive(False)
        self.menu.append(self.item_section)

        # Informacje o urządzeniu
        self.item_device = Gtk.MenuItem(label="")
        self.item_box = Gtk.MenuItem(label="")
        self.item_auth = Gtk.MenuItem(label="")
        self.item_speed = Gtk.MenuItem(label="")
        self.item_status = Gtk.MenuItem(label="")

        for it in (self.item_device, self.item_box, self.item_auth, self.item_speed, self.item_status):
            self.menu.append(it)

        # Separator telemetrii
        self.sep_telemetry = Gtk.SeparatorMenuItem()
        self.menu.append(self.sep_telemetry)

        # Telemetria aktywna
        self.item_usage = Gtk.MenuItem(label="")
        self.item_vram = Gtk.MenuItem(label="")
        self.item_transfer = Gtk.MenuItem(label="")
        self.item_temp = Gtk.MenuItem(label="")

        for it in (self.item_usage, self.item_vram, self.item_transfer, self.item_temp):
            self.menu.append(it)

        # Separator akcji
        self.sep_actions = Gtk.SeparatorMenuItem()
        self.menu.append(self.sep_actions)

        # Ostrzeżenie
        self.item_warn = Gtk.MenuItem(label="⚠ Warning: Disabling the iGPU is experimental ⚠")
        self.item_warn.set_sensitive(False)
        self.menu.append(self.item_warn)

        # Przyciski sterujące
        self.btn_auth = Gtk.MenuItem(label="Authorize eGPU")
        self.btn_auth.connect("activate", lambda *_: self.run_cmd(2))
        self.menu.append(self.btn_auth)

        self.btn_connect = Gtk.MenuItem(label="Connect eGPU (Hybrid Offload)")
        self.btn_connect.connect("activate", lambda *_: self.run_cmd(3))
        self.menu.append(self.btn_connect)

        self.btn_dedic = Gtk.MenuItem(label="⚠ eGPU Only (disconnect iGPU) ⚠")
        self.btn_dedic.connect("activate", lambda *_: self.run_cmd(4))
        self.menu.append(self.btn_dedic)

        self.btn_detach = Gtk.MenuItem(label="Safely Remove eGPU")
        self.btn_detach.connect("activate", lambda *_: self.run_cmd(6))
        self.menu.append(self.btn_detach)

        self.btn_restore = Gtk.MenuItem(label="Connect iGPU (Restore)")
        self.btn_restore.connect("activate", lambda *_: self.run_cmd(5))
        self.menu.append(self.btn_restore)

        self.item_info_final = Gtk.MenuItem(label="iGPU Active (Terminal State)")
        self.item_info_final.set_sensitive(False)
        self.menu.append(self.item_info_final)

        # Ustawienia ekranu
        self.menu.append(Gtk.SeparatorMenuItem())
        self.item_display_settings = Gtk.MenuItem(label="Display Settings...")
        self.item_display_settings.connect("activate", self.open_display_settings)
        self.menu.append(self.item_display_settings)

        # Wyjście
        self.menu.append(Gtk.SeparatorMenuItem())
        self.item_quit = Gtk.MenuItem(label="Exit (will close tray icon and daemon)")
        self.item_quit.connect("activate", self.quit_app)
        self.menu.append(self.item_quit)

        self.menu.show_all()

    def poll_backend(self):
        while self.running:
            try:
                res = subprocess.run([CLI_PATH, "status"], capture_output=True, text=True)
                if res.returncode == 0:
                    data = json.loads(res.stdout.strip())
                    GLib.idle_add(self.update_menu, data)
            except Exception:
                pass
            time.sleep(2)

    def update_menu(self, data):
        mode = data.get("mode", 0)

        # Ikona stanu
        if self.current_icon_mode != mode:
            self.current_icon_mode = mode
            if mode == 1:
                self.indicator.set_icon_full("dialog-warning", "Awaiting Authorization")
            else:
                self.indicator.set_icon_full("video-display", "Blackwell eGPU")

        # Ukrywanie elementów dynamicznych
        for widget in (
            self.item_device, self.item_box, self.item_auth, self.item_speed, self.item_status,
            self.sep_telemetry, self.item_usage, self.item_vram, self.item_transfer, self.item_temp,
            self.sep_actions, self.item_warn, self.btn_auth, self.btn_connect, self.btn_dedic,
            self.btn_detach, self.btn_restore, self.item_info_final
        ):
            widget.hide()

        # Mode 0: Rozłączone
        if mode == 0:
            self.item_status.set_label("Status: Disconnected")
            self.item_status.set_sensitive(False)
            self.item_status.show()

        # Mode 1: Podłączone / Oczekuje na autoryzację
        elif mode == 1:
            box = data.get("egpu") or "Thunderbolt/USB4 Device"
            self.item_box.set_label(f"Box: {box}")
            self.item_auth.set_label("Authorized: no")
            self.item_speed.set_label("Speed: N/A")
            self.item_status.set_label("Status: Awaiting Authorization")

            for it in (self.item_box, self.item_auth, self.item_speed, self.item_status):
                it.set_sensitive(False)
                it.show()

            self.sep_actions.show()
            self.btn_auth.show()

        # Mode 2: Gotowość / Zautoryzowano
        elif mode == 2:
            box = data.get("egpu") or "AORUS RTX506T AI BOX"
            auth_val = data.get("authorized", data.get("auth"))
            if auth_val is None:
                auth_str = "yes"
            elif isinstance(auth_val, bool):
                auth_str = "yes" if auth_val else "no"
            else:
                auth_str = "yes" if str(auth_val).lower() in ("1", "yes", "true", "tak") else "no"

            self.item_box.set_label(f"{box}")
            self.item_auth.set_label(f"Authorized: {auth_str}")
            self.item_speed.set_label("Speed: N/A")
            self.item_status.set_label("Status: Standby (Ready)")

            for it in (self.item_box, self.item_auth, self.item_speed, self.item_status):
                it.set_sensitive(False)
                it.show()

            self.sep_actions.show()
            self.btn_connect.show()

        # Mode 3, 4, 5: Stany aktywne
        elif mode in (3, 4, 5):
            device = data.get("egpu2") or data.get("gpu_name") or "NVIDIA GeForce RTX 5060 Ti"
            box = data.get("egpu") or "AORUS RTX506T AI BOX"
            speed = data.get("link") or data.get("link_speed") or "16GT/s (Gen4)"

            if mode == 3:
                status_str = "Hybrid Offload"
            elif mode == 4:
                status_str = "Dedicated Primary"
            elif mode == 5:
                status_str = "Hybrid Offload (Restored)"
            else:
                status_str = "Active"

            raw_util = str(data.get("gpu_util", data.get("usage", 0))).rstrip("%")
            gpu_util = f"{raw_util}%"

            raw_pwr = data.get("pwr_curr", data.get("power", 0))
            try:
                pwr_val = float(raw_pwr)
                power_str = f"{pwr_val:.0f} W"
            except (ValueError, TypeError):
                power_str = f"{raw_pwr} W"

            vram_used = data.get("vram_used")
            vram_total = data.get("vram_total")
            if vram_used is not None and vram_total is not None:
                used_gb = round(float(vram_used) / 1024, 1)
                total_gb = round(float(vram_total) / 1024)
                vram_str = f"{used_gb} / {total_gb} GB"
            else:
                vram_str = data.get("vram", "0.0 / 16 GB")

            tx = data.get("pcie_tx", data.get("tx_throughput", 0))
            rx = data.get("pcie_rx", data.get("rx_throughput", 0))
            rx_str = f"{rx} MB/s" if not str(rx).endswith("MB/s") else str(rx)
            tx_str = f"{tx} MB/s" if not str(tx).endswith("MB/s") else str(tx)
            temp = str(data.get("temp", "0")).rstrip("°C") + "°C"

            self.item_device.set_label(f"{device}")
            self.item_box.set_label(f"Box: {box}")
            self.item_auth.set_label("Authorized: yes")
            self.item_speed.set_label(f"Speed: {speed}")
            self.item_status.set_label(f"Status: {status_str}")

            self.item_usage.set_label(f"Usage: {gpu_util} ({power_str})")
            self.item_vram.set_label(f"VRAM: {vram_str}")
            # RX (pobieranie / z eGPU) po lewej, TX (wysyłanie / do eGPU) po prawej
            self.item_transfer.set_label(f"Transfer: ↓ {rx_str}   ↑ {tx_str}")
            self.item_temp.set_label(f"Temp: {temp}")

            for it in (self.item_device, self.item_box, self.item_auth, self.item_speed, self.item_status,
                       self.item_usage, self.item_vram, self.item_transfer, self.item_temp):
                it.set_sensitive(True)
                it.show()

            self.sep_telemetry.show()
            self.sep_actions.show()

            if mode == 3:
                self.item_warn.show()
                self.btn_dedic.show()
                self.btn_detach.show()
            elif mode == 4:
                self.btn_restore.show()
            elif mode == 5:
                self.item_info_final.show()

        # Mode 6: Bezpieczne odłączanie
        elif mode == 6:
            self.item_status.set_label("Status: Detached / Safe to Unplug")
            self.item_status.set_sensitive(False)
            self.item_status.show()

        return False

if __name__ == "__main__":
    BlackwellTrayGTK()
    Gtk.main()
