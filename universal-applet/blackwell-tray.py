#!/usr/bin/env python3
import json
import shutil
import subprocess
import sys
import threading
import time

from PySide6.QtCore import QObject, Signal
from PySide6.QtGui import QAction, QIcon
from PySide6.QtWidgets import QApplication, QMenu, QSystemTrayIcon

CLI_PATH = "/usr/local/bin/blackwell-egpu"
HEADER_TEXT = "----------------- Blackwell eGPU Manager -----------------"

class DataBridge(QObject):
    data_received = Signal(dict)

class BlackwellTray(QSystemTrayIcon):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.bridge = DataBridge()
        self.bridge.data_received.connect(self.update_menu)

        # Inicjalizacja stałego menu PPM
        self.menu = QMenu()
        self.init_menu_structure()
        self.setContextMenu(self.menu)

        # Obsługa LPM (Screen Settings)
        self.activated.connect(self.on_tray_activated)

        self.current_icon_mode = None
        self.setIcon(QIcon.fromTheme("video-display"))
        self.setVisible(True)

        self.running = True
        self.thread = threading.Thread(target=self.poll_backend, daemon=True)
        self.thread.start()

    def on_tray_activated(self, reason):
        if reason == QSystemTrayIcon.ActivationReason.Trigger:
            self.open_display_settings()

    def open_display_settings(self):
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

    def init_menu_structure(self):
        # Aktywny nagłówek rozpychający
        self.act_header = self.menu.addAction(HEADER_TEXT)
        self.act_header.triggered.connect(self.open_display_settings)

        # Tytuł sekcji eGPU
        self.act_section = self.menu.addAction("eGPU:")
        self.act_section.setEnabled(False)

        # Informacje o urządzeniu
        self.act_device = self.menu.addAction("")
        self.act_box = self.menu.addAction("")
        self.act_auth = self.menu.addAction("")
        self.act_speed = self.menu.addAction("")
        self.act_status = self.menu.addAction("")

        # Separator telemetrii
        self.sep_telemetry = self.menu.addSeparator()

        # Telemetria aktywna
        self.act_usage = self.menu.addAction("")
        self.act_vram = self.menu.addAction("")
        self.act_transfer = self.menu.addAction("")
        self.act_temp = self.menu.addAction("")

        # Separator akcji
        self.sep_actions = self.menu.addSeparator()

        # Ostrzeżenie
        self.act_warn = self.menu.addAction("⚠ Warning: Disabling the iGPU is experimental ⚠")
        self.act_warn.setEnabled(False)

        # Przyciski sterujące
        self.act_btn_auth = self.menu.addAction("Authorize eGPU")
        self.act_btn_auth.triggered.connect(lambda: self.run_cmd(2))

        self.act_btn_connect = self.menu.addAction("Connect eGPU (Hybrid Offload)")
        self.act_btn_connect.triggered.connect(lambda: self.run_cmd(3))

        self.act_btn_dedic = self.menu.addAction("⚠ eGPU Only (disconnect iGPU) ⚠")
        self.act_btn_dedic.triggered.connect(lambda: self.run_cmd(4))

        self.act_btn_detach = self.menu.addAction("Safely Remove eGPU")
        self.act_btn_detach.triggered.connect(lambda: self.run_cmd(6))

        self.act_btn_restore = self.menu.addAction("Connect iGPU (Restore)")
        self.act_btn_restore.triggered.connect(lambda: self.run_cmd(5))

        self.act_info_final = self.menu.addAction("iGPU Active (Terminal State)")
        self.act_info_final.setEnabled(False)

        # Ustawienia ekranu
        self.menu.addSeparator()
        self.act_display_settings = self.menu.addAction("Display Settings...")
        self.act_display_settings.triggered.connect(self.open_display_settings)

        # Separator przed wyjściem
        self.menu.addSeparator()

        # Wyjście
        self.act_quit = self.menu.addAction("Exit (will close tray icon and daemon)")
        self.act_quit.triggered.connect(self.quit_app)

    def quit_app(self):
        self.running = False
        QApplication.quit()

    def run_cmd(self, mode):
        subprocess.Popen(["sudo", CLI_PATH, "set", str(mode)])

    def poll_backend(self):
        while self.running:
            try:
                res = subprocess.run([CLI_PATH, "status"], capture_output=True, text=True)
                if res.returncode == 0:
                    data = json.loads(res.stdout.strip())
                    self.bridge.data_received.emit(data)
            except Exception:
                pass
            time.sleep(2)

    def update_menu(self, data):
        mode = data.get("mode", 0)

        # Aktualizacja ikony stanu
        if self.current_icon_mode != mode:
            self.current_icon_mode = mode
            if mode == 1:
                self.setIcon(QIcon.fromTheme("dialog-warning"))
            else:
                self.setIcon(QIcon.fromTheme("video-display"))

        # Ukrywanie elementów dynamicznych przed selektywnym włączeniem
        self.act_device.setVisible(False)
        self.act_box.setVisible(False)
        self.act_auth.setVisible(False)
        self.act_speed.setVisible(False)
        self.act_status.setVisible(False)
        self.sep_telemetry.setVisible(False)
        self.act_usage.setVisible(False)
        self.act_vram.setVisible(False)
        self.act_transfer.setVisible(False)
        self.act_temp.setVisible(False)
        self.sep_actions.setVisible(False)
        self.act_warn.setVisible(False)
        self.act_btn_auth.setVisible(False)
        self.act_btn_connect.setVisible(False)
        self.act_btn_dedic.setVisible(False)
        self.act_btn_detach.setVisible(False)
        self.act_btn_restore.setVisible(False)
        self.act_info_final.setVisible(False)

        # Mode 0: Rozłączone
        if mode == 0:
            self.setToolTip(
                f"{HEADER_TEXT}\n"
                "eGPU:\n"
                "Status: Disconnected\n"
                "(LMB: Display Settings | RMB: Menu)"
            )
            self.act_status.setText("Status: Disconnected")
            self.act_status.setEnabled(False)
            self.act_status.setVisible(True)

        # Mode 1: Podłączone / Oczekuje na autoryzację
        elif mode == 1:
            box = data.get("egpu") or "Thunderbolt/USB4 Device"
            self.setToolTip(
                f"{HEADER_TEXT}\n"
                f"eGPU:\n"
                f"Box: {box}\n"
                f"Authorized: no\n"
                f"Status: Awaiting Authorization\n"
                f"(LMB: Display Settings | RMB: Menu)"
            )

            self.act_box.setText(f"Box: {box}")
            self.act_auth.setText("Authorized: no")
            self.act_speed.setText("Speed: N/A")
            self.act_status.setText("Status: Awaiting Authorization")

            for act in (self.act_box, self.act_auth, self.act_speed, self.act_status):
                act.setEnabled(False)
                act.setVisible(True)

            self.sep_actions.setVisible(True)
            self.act_btn_auth.setVisible(True)

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

            self.setToolTip(
                f"{HEADER_TEXT}\n"
                f"eGPU:\n"
                f"{box}\n"
                f"Authorized: {auth_str}\n"
                f"Speed: N/A\n"
                f"Status: Standby (Ready)\n"
                f"(LMB: Display Settings | RMB: Menu)"
            )

            self.act_box.setText(f"{box}")
            self.act_auth.setText(f"Authorized: {auth_str}")
            self.act_speed.setText("Speed: N/A")
            self.act_status.setText("Status: Standby (Ready)")

            for act in (self.act_box, self.act_auth, self.act_speed, self.act_status):
                act.setEnabled(False)
                act.setVisible(True)

            self.sep_actions.setVisible(True)
            self.act_btn_connect.setVisible(True)

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

            gpu_util = data.get("gpu_util", data.get("usage", 0))

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
            tx_str = f"{tx} MB/s" if not str(tx).endswith("MB/s") else str(tx)
            rx_str = f"{rx} MB/s" if not str(rx).endswith("MB/s") else str(rx)
            temp = str(data.get("temp", "0")).rstrip("°C") + "°C"

            self.setToolTip(
                f"{HEADER_TEXT}\n"
                f"eGPU:\n"
                f"{device}\n"
                f"Box: {box}\n"
                f"Authorized: yes\n"
                f"Speed: {speed}\n"
                f"Status: {status_str}\n"
                f"Usage: {gpu_util}% ({power_str})\n"
                f"VRAM: {vram_str}\n"
                f"Temp: {temp}\n"
                f"Transfer: ↓ {rx_str} | ↑ {tx_str}\n"
                f"(LMB: Display Settings | RMB: Menu)"
            )

            self.act_device.setText(f"{device}")
            self.act_box.setText(f"Box: {box}")
            self.act_auth.setText("Authorized: yes")
            self.act_speed.setText(f"Speed: {speed}")
            self.act_status.setText(f"Status: {status_str}")

            self.act_usage.setText(f"Usage: {gpu_util}% ({power_str})")
            self.act_vram.setText(f"VRAM: {vram_str}")
            self.act_transfer.setText(f"Transfer: ↓ {rx_str}   ↑ {tx_str}")
            self.act_temp.setText(f"Temp: {temp}")

            for act in (self.act_device, self.act_box, self.act_auth, self.act_speed, self.act_status,
                        self.act_usage, self.act_vram, self.act_transfer, self.act_temp):
                act.setEnabled(True)
                act.setVisible(True)

            self.sep_telemetry.setVisible(True)
            self.sep_actions.setVisible(True)

            if mode == 3:
                self.act_warn.setVisible(True)
                self.act_btn_dedic.setVisible(True)
                self.act_btn_detach.setVisible(True)
            elif mode == 4:
                self.act_btn_restore.setVisible(True)
            elif mode == 5:
                self.act_info_final.setVisible(True)

        # Mode 6: Bezpieczne odłączanie
        elif mode == 6:
            self.setToolTip(
                f"{HEADER_TEXT}\n"
                "eGPU:\n"
                "Status: Detached / Safe to Unplug\n"
                "(LMB: Display Settings | RMB: Menu)"
            )
            self.act_status.setText("Status: Detached / Safe to Unplug")
            self.act_status.setEnabled(False)
            self.act_status.setVisible(True)

if __name__ == "__main__":
    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)
    tray = BlackwellTray()
    sys.exit(app.exec())
