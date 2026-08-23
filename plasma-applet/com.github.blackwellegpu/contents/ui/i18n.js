.pragma library

// Flaga główna (ustawiana przez install.sh na true lub false)
var enabled = true;

// Domyślny język (ustawiany na "auto" dla autodetekcji z systemu lub ręcznie np. "pl", "de", "en")
var currentLang = "auto";

var translations = {
    // === POLSKI (PL) ===
    "pl": {
        "Blackwell eGPU Manager": "Menedżer eGPU Blackwell",
        "Checking hardware state...": "Sprawdzanie stanu sprzętu...",
        "iGPU": "iGPU",
        "eGPU": "eGPU",
        "Device: %1": "Urządzenie: %1",
        "Box: %1": "Obudowa: %1",
        "Authorized: %1": "Autoryzowano: %1",
        "Speed: %1": "Prędkość: %1",
        "yes": "tak",
        "no": "nie",
        "Status: Inactive": "Status: Nieaktywna",
        "Status: Primary Display": "Status: Główny ekran",
        "Status: Active": "Status: Aktywna",
        "No Blackwell eGPU found": "Nie znaleziono eGPU Blackwell",
        "Status: Disconnected": "Status: Odłączone",
        "Status: Unauthorized (USB4)": "Status: Nieautoryzowane (USB4)",
        "Status: Standby (Ready)": "Status: Gotowe (Standby)",
        "Status: Hybrid Offload": "Status: Hybrydowy (Offload)",
        "Status: Dedicated Primary": "Status: Dedykowany (Główny)",
        "Status: Unknown": "Status: Nieznany",
        "Authorize": "Autoryzuj",
        "Connect eGPU": "Podłącz eGPU",
        "Screen Manager": "Ustawienia ekranu",
        "eGPU Only (disconnect iGPU)": "Tylko eGPU (odłącz iGPU)",
        "Warning: Disabling the iGPU is experimental. Proceed at your own risk.": "Ostrzeżenie: Wyłączenie iGPU jest eksperymentalne. Działasz na własne ryzyko."
    },

    // === NIEMIECKI (DE) ===
    "de": {
        "Blackwell eGPU Manager": "Blackwell eGPU-Verwaltung",
        "Checking hardware state...": "Hardwarestatus wird überprüft...",
        "iGPU": "iGPU",
        "eGPU": "eGPU",
        "Device: %1": "Gerät: %1",
        "Box: %1": "Gehäuse: %1",
        "Authorized: %1": "Autorisiert: %1",
        "Speed: %1": "Geschwindigkeit: %1",
        "yes": "ja",
        "no": "nein",
        "Status: Inactive": "Status: Inaktiv",
        "Status: Primary Display": "Status: Hauptanzeige",
        "Status: Active": "Status: Aktiv",
        "No Blackwell eGPU found": "Keine Blackwell eGPU gefunden",
        "Status: Disconnected": "Status: Getrennt",
        "Status: Unauthorized (USB4)": "Status: Nicht autorisiert (USB4)",
        "Status: Standby (Ready)": "Status: Bereit (Standby)",
        "Status: Hybrid Offload": "Status: Hybrid (Offload)",
        "Status: Dedicated Primary": "Status: Dediziert (Primär)",
        "Status: Unknown": "Status: Unbekannt",
        "Authorize": "Autorisieren",
        "Connect eGPU": "eGPU Verbinden",
        "Screen Manager": "Bildschirmeinstellungen",
        "eGPU Only (disconnect iGPU)": "Nur eGPU (iGPU trennen)",
        "Warning: Disabling the iGPU is experimental. Proceed at your own risk.": "Warnung: Das Deaktivieren der iGPU ist experimentell. Benutzung auf eigene Gefahr."
    },

    // === HISZPAŃSKI (ES) ===
    "es": {
        "Blackwell eGPU Manager": "Administrador de eGPU Blackwell",
        "Checking hardware state...": "Comprobando estado del hardware...",
        "iGPU": "iGPU",
        "eGPU": "eGPU",
        "Device: %1": "Dispositivo: %1",
        "Box: %1": "Carcasa: %1",
        "Authorized: %1": "Autorizado: %1",
        "Speed: %1": "Velocidad: %1",
        "yes": "sí",
        "no": "no",
        "Status: Inactive": "Estado: Inactivo",
        "Status: Primary Display": "Estado: Pantalla principal",
        "Status: Active": "Estado: Activo",
        "No Blackwell eGPU found": "No se encontró eGPU Blackwell",
        "Status: Disconnected": "Estado: Desconectado",
        "Status: Unauthorized (USB4)": "Estado: No autorizado (USB4)",
        "Status: Standby (Ready)": "Estado: Listo (Standby)",
        "Status: Hybrid Offload": "Estado: Híbrido (Offload)",
        "Status: Dedicated Primary": "Estado: Dedicado principal",
        "Status: Unknown": "Estado: Desconocido",
        "Authorize": "Autorizar",
        "Connect eGPU": "Conectar eGPU",
        "Screen Manager": "Ajustes de pantalla",
        "eGPU Only (disconnect iGPU)": "Solo eGPU (desconectar iGPU)",
        "Warning: Disabling the iGPU is experimental. Proceed at your own risk.": "Advertencia: Desactivar la iGPU es experimental. Proceda bajo su propio riesgo."
    },

    // === FRANCUSKI (FR) ===
    "fr": {
        "Blackwell eGPU Manager": "Gestionnaire eGPU Blackwell",
        "Checking hardware state...": "Vérification de l'état matériel...",
        "iGPU": "iGPU",
        "eGPU": "eGPU",
        "Device: %1": "Périphérique : %1",
        "Box: %1": "Boîtier : %1",
        "Authorized: %1": "Autorisé : %1",
        "Speed: %1": "Vitesse : %1",
        "yes": "oui",
        "no": "non",
        "Status: Inactive": "État : Inactif",
        "Status: Primary Display": "État : Écran principal",
        "Status: Active": "État : Actif",
        "No Blackwell eGPU found": "Aucun eGPU Blackwell détecté",
        "Status: Disconnected": "État : Déconnecté",
        "Status: Unauthorized (USB4)": "État : Non autorisé (USB4)",
        "Status: Standby (Ready)": "État : Prêt (Standby)",
        "Status: Hybrid Offload": "État : Hybride (Offload)",
        "Status: Dedicated Primary": "État : Dédié principal",
        "Status: Unknown": "État : Inconnu",
        "Authorize": "Autoriser",
        "Connect eGPU": "Connecter l'eGPU",
        "Screen Manager": "Gestion des écrans",
        "eGPU Only (disconnect iGPU)": "eGPU uniquement (déconnecter l'iGPU)",
        "Warning: Disabling the iGPU is experimental. Proceed at your own risk.": "Attention : La désactivation de l'iGPU est expérimentale. À vos risques et périls."
    },

    // === WŁOSKI (IT) ===
    "it": {
        "Blackwell eGPU Manager": "Gestore eGPU Blackwell",
        "Checking hardware state...": "Verifica dello stato hardware...",
        "iGPU": "iGPU",
        "eGPU": "eGPU",
        "Device: %1": "Dispositivo: %1",
        "Box: %1": "Chassis: %1",
        "Authorized: %1": "Autorizzato: %1",
        "Speed: %1": "Velocità: %1",
        "yes": "sì",
        "no": "no",
        "Status: Inactive": "Stato: Inattivo",
        "Status: Primary Display": "Stato: Schermo principale",
        "Status: Active": "Stato: Attivo",
        "No Blackwell eGPU found": "Nessuna eGPU Blackwell trovata",
        "Status: Disconnected": "Stato: Disconnesso",
        "Status: Unauthorized (USB4)": "Stato: Non autorizzato (USB4)",
        "Status: Standby (Ready)": "Stato: Pronto (Standby)",
        "Status: Hybrid Offload": "Stato: Ibrido (Offload)",
        "Status: Dedicated Primary": "Stato: Dedicato principale",
        "Status: Unknown": "Stato: Sconosciuto",
        "Authorize": "Autorizza",
        "Connect eGPU": "Connetti eGPU",
        "Screen Manager": "Gestione schermi",
        "eGPU Only (disconnect iGPU)": "Solo eGPU (disconnetti iGPU)",
        "Warning: Disabling the iGPU is experimental. Proceed at your own risk.": "Avviso: La disattivazione della iGPU è sperimentale. Procedi a tuo rischio."
    },

    // === PORTUGALSKI (PT) ===
    "pt": {
        "Blackwell eGPU Manager": "Gerenciador de eGPU Blackwell",
        "Checking hardware state...": "Verificando estado do hardware...",
        "iGPU": "iGPU",
        "eGPU": "eGPU",
        "Device: %1": "Dispositivo: %1",
        "Box: %1": "Gabinete: %1",
        "Authorized: %1": "Autorizado: %1",
        "Speed: %1": "Velocidade: %1",
        "yes": "sim",
        "no": "não",
        "Status: Inactive": "Status: Inativo",
        "Status: Primary Display": "Status: Tela principal",
        "Status: Active": "Status: Ativo",
        "No Blackwell eGPU found": "Nenhuma eGPU Blackwell encontrada",
        "Status: Disconnected": "Status: Desconectado",
        "Status: Unauthorized (USB4)": "Status: Não autorizado (USB4)",
        "Status: Standby (Ready)": "Status: Pronto (Standby)",
        "Status: Hybrid Offload": "Status: Híbrido (Offload)",
        "Status: Dedicated Primary": "Status: Dedicado principal",
        "Status: Unknown": "Status: Desconhecido",
        "Authorize": "Autorizar",
        "Connect eGPU": "Conectar eGPU",
        "Screen Manager": "Gerenciador de telas",
        "eGPU Only (disconnect iGPU)": "Apenas eGPU (desconectar iGPU)",
        "Warning: Disabling the iGPU is experimental. Proceed at your own risk.": "Aviso: Desativar a iGPU é experimental. Prossiga por sua conta e risco."
    },

    // === UKRAIŃSKI (UK) ===
    "uk": {
        "Blackwell eGPU Manager": "Менеджер eGPU Blackwell",
        "Checking hardware state...": "Перевірка стану обладнання...",
        "iGPU": "iGPU",
        "eGPU": "eGPU",
        "Device: %1": "Пристрій: %1",
        "Box: %1": "Корпус: %1",
        "Authorized: %1": "Авторизовано: %1",
        "Speed: %1": "Швидкість: %1",
        "yes": "так",
        "no": "ні",
        "Status: Inactive": "Статус: Неактивна",
        "Status: Primary Display": "Статус: Головний екран",
        "Status: Active": "Статус: Активна",
        "No Blackwell eGPU found": "eGPU Blackwell не знайдено",
        "Status: Disconnected": "Статус: Відключено",
        "Status: Unauthorized (USB4)": "Статус: Не авторизовано (USB4)",
        "Status: Standby (Ready)": "Статус: Готово (Standby)",
        "Status: Hybrid Offload": "Статус: Гібридний (Offload)",
        "Status: Dedicated Primary": "Статус: Виділений (Головний)",
        "Status: Unknown": "Статус: Невідомо",
        "Authorize": "Авторизувати",
        "Connect eGPU": "Підключити eGPU",
        "Screen Manager": "Налаштування дисплея",
        "eGPU Only (disconnect iGPU)": "Тільки eGPU (відключити iGPU)",
        "Warning: Disabling the iGPU is experimental. Proceed at your own risk.": "Попередження: Вимкнення iGPU є експериментальним. Ви дієте на власний ризик."
    },

    // === CZESKI (CS) ===
    "cs": {
        "Blackwell eGPU Manager": "Správce eGPU Blackwell",
        "Checking hardware state...": "Kontrola stavu hardwaru...",
        "iGPU": "iGPU",
        "eGPU": "eGPU",
        "Device: %1": "Zařízení: %1",
        "Box: %1": "Box: %1",
        "Authorized: %1": "Autorizováno: %1",
        "Speed: %1": "Rychlost: %1",
        "yes": "ano",
        "no": "ne",
        "Status: Inactive": "Stav: Neaktivní",
        "Status: Primary Display": "Stav: Hlavní obrazovka",
        "Status: Active": "Stav: Aktivní",
        "No Blackwell eGPU found": "Nebylo nalezeno žádné eGPU Blackwell",
        "Status: Disconnected": "Stav: Odpojeno",
        "Status: Unauthorized (USB4)": "Stav: Neautorizováno (USB4)",
        "Status: Standby (Ready)": "Stav: Připraveno (Standby)",
        "Status: Hybrid Offload": "Stav: Hybridní (Offload)",
        "Status: Dedicated Primary": "Stav: Dedikovaný (Hlavní)",
        "Status: Unknown": "Stav: Neznámý",
        "Authorize": "Autorizovat",
        "Connect eGPU": "Připojit eGPU",
        "Screen Manager": "Nastavení displeje",
        "eGPU Only (disconnect iGPU)": "Pouze eGPU (odpojit iGPU)",
        "Warning: Disabling the iGPU is experimental. Proceed at your own risk.": "Varování: Deaktivace iGPU je experimentální. Postupujte na vlastní riziko."
    },

    // === JAPOŃSKI (JA) ===
    "ja": {
        "Blackwell eGPU Manager": "Blackwell eGPU マネージャー",
        "Checking hardware state...": "ハードウェアの状態を確認中...",
        "iGPU": "iGPU",
        "eGPU": "eGPU",
        "Device: %1": "デバイス: %1",
        "Box: %1": "ボックス: %1",
        "Authorized: %1": "認証済み: %1",
        "Speed: %1": "速度: %1",
        "yes": "はい",
        "no": "いいえ",
        "Status: Inactive": "状態: 非アクティブ",
        "Status: Primary Display": "状態: プライマリディスプレイ",
        "Status: Active": "状態: アクティブ",
        "No Blackwell eGPU found": "Blackwell eGPU が見つかりません",
        "Status: Disconnected": "状態: 切断",
        "Status: Unauthorized (USB4)": "状態: 未認証 (USB4)",
        "Status: Standby (Ready)": "状態: 待機中 (準備完了)",
        "Status: Hybrid Offload": "状態: ハイブリッド (Offload)",
        "Status: Dedicated Primary": "状態: 専用プライマリ",
        "Status: Unknown": "状態: 不明",
        "Authorize": "認証",
        "Connect eGPU": "eGPU を接続",
        "Screen Manager": "ディスプレイ設定",
        "eGPU Only (disconnect iGPU)": "eGPU のみ (iGPU を切断)",
        "Warning: Disabling the iGPU is experimental. Proceed at your own risk.": "警告: iGPU の無効化は実験的です。自己責任で実行してください。"
    },

    // === CHIŃSKI UPROSZCZONY (ZH) ===
    "zh": {
        "Blackwell eGPU Manager": "Blackwell eGPU 管理器",
        "Checking hardware state...": "正在检查硬件状态...",
        "iGPU": "iGPU",
        "eGPU": "eGPU",
        "Device: %1": "设备: %1",
        "Box: %1": "显卡坞: %1",
        "Authorized: %1": "已授权: %1",
        "Speed: %1": "速度: %1",
        "yes": "是",
        "no": "否",
        "Status: Inactive": "状态: 未激活",
        "Status: Primary Display": "状态: 主显示器",
        "Status: Active": "状态: 已激活",
        "No Blackwell eGPU found": "未找到 Blackwell eGPU",
        "Status: Disconnected": "状态: 已断开",
        "Status: Unauthorized (USB4)": "状态: 未授权 (USB4)",
        "Status: Standby (Ready)": "状态: 就绪 (待机)",
        "Status: Hybrid Offload": "状态: 混合模式 (Offload)",
        "Status: Dedicated Primary": "状态: 独立主显卡",
        "Status: Unknown": "状态: 未知",
        "Authorize": "授权",
        "Connect eGPU": "连接 eGPU",
        "Screen Manager": "屏幕设置",
        "eGPU Only (disconnect iGPU)": "仅 eGPU (断开 iGPU)",
        "Warning: Disabling the iGPU is experimental. Proceed at your own risk.": "警告: 禁用 iGPU 属于实验性功能，请自行承担风险。"
    }
};

function getActiveLanguage() {
    if (currentLang !== "auto") {
        return currentLang;
    }
    try {
        var localeName = Qt.locale().name; // np. "pl_PL", "zh_CN", "de_DE"
        return localeName.substring(0, 2);
    } catch(e) {
        return "en";
    }
}

function t(text, param) {
    if (!enabled) {
        return (param !== undefined) ? text.replace("%1", param) : text;
    }

    var lang = getActiveLanguage();
    var dict = translations[lang] || {};
    var res = (dict[text] !== undefined) ? dict[text] : text;

    if (param !== undefined) {
        res = res.replace("%1", param);
    }
    return res;
}
