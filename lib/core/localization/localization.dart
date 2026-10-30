import 'package:flutter/foundation.dart';

import 'translations/es.dart';
import 'translations/pl.dart';
import 'translations/ro.dart';
import 'translations/ru.dart';
import 'translations/uk.dart';

class AppLocalizations {
  AppLocalizations._();

  /// Every language the app speaks, in the order the picker shows them.
  /// The codes are upper-case ISO 639-1 ('UK' is Ukrainian).
  static const List<String> languages = [
    'TR',
    'EN',
    'DE',
    'RU',
    'PL',
    'RO',
    'ES',
    'UK',
  ];

  /// Each language's name in itself, for the picker.
  static const Map<String, String> languageNames = {
    'TR': 'Türkçe',
    'EN': 'English',
    'DE': 'Deutsch',
    'RU': 'Русский',
    'PL': 'Polski',
    'RO': 'Română',
    'ES': 'Español',
    'UK': 'Українська',
  };

  /// The languages added after Turkish, English and German, each in a file of
  /// its own under translations/ so the main map below stays as it is.
  static const Map<String, Map<String, String>> _moreLanguages = {
    'RU': ruTranslations,
    'PL': plTranslations,
    'RO': roTranslations,
    'ES': esTranslations,
    'UK': ukTranslations,
  };

  /// The language the app is showing, kept up to date by AppState, for text
  /// made where no BuildContext reaches: services, controllers, exceptions.
  static String current = 'TR';

  /// [getText] in [current], with every `{name}` in [args] filled in.
  static String text(String key, [Map<String, Object?> args = const {}]) =>
      fill(getText(current, key), args);

  /// Fills `{name}` placeholders of an already looked-up text.
  static String fill(String template, Map<String, Object?> args) {
    var out = template;
    args.forEach((name, value) => out = out.replaceAll('{$name}', '$value'));
    return out;
  }

  @visibleForTesting
  static Iterable<String> get keys => _translations.keys;

  @visibleForTesting
  static Map<String, String>? moreLanguage(String lang) => _moreLanguages[lang];

  static const Map<String, Map<String, String>> _translations = {
    'nav.dashboard': {'TR': 'Panel', 'EN': 'Dashboard', 'DE': 'Dashboard'},
    'nav.logs': {'TR': 'Kayıtlar', 'EN': 'Logs', 'DE': 'Protokolle'},
    'nav.alerts': {'TR': 'Uyarılar', 'EN': 'Alerts', 'DE': 'Warnungen'},
    'nav.timeline': {'TR': 'Çizelge', 'EN': 'Timeline', 'DE': 'Zeitleiste'},
    'nav.dddFiles': {'TR': 'Dosyalar', 'EN': 'Files', 'DE': 'Dateien'},
    'nav.vu': {'TR': 'ITS', 'EN': 'ITS', 'DE': 'ITS'},
    'nav.settings': {'TR': 'Ayarlar', 'EN': 'Settings', 'DE': 'Einstellungen'},

    'bt.errorTitle': {
      'TR': 'Bluetooth Bağlantısı Kesildi',
      'EN': 'Bluetooth Connection Lost',
      'DE': 'Bluetooth-Verbindung Verloren',
    },
    'bt.errorMsg': {
      'TR':
          'Bluetooth koptu lütfen verileri almaya devam etmek için tekrar bağlanın.',
      'EN':
          'Bluetooth disconnected, please reconnect to continue receiving data.',
      'DE':
          'Bluetooth getrennt. Bitte verbinden Sie sich erneut, um Daten zu empfangen.',
    },
    'bt.reconnect': {
      'TR': 'Tekrar Bağlan',
      'EN': 'Reconnect',
      'DE': 'Wiederverbinden',
    },
    'bt.connecting': {
      'TR': 'Bağlanıyor...',
      'EN': 'Connecting...',
      'DE': 'Verbindung wird hergestellt...',
    },
    'bt.connectedSnack': {
      'TR': 'Bluetooth başarıyla bağlandı.',
      'EN': 'Bluetooth successfully connected.',
      'DE': 'Bluetooth erfolgreich verbunden.',
    },
    'bt.errorTitleShort': {
      'TR': 'Bağlantı Hatası',
      'EN': 'Connection Error',
      'DE': 'Verbindungsfehler',
    },
    'bt.errorMsgShort': {
      'TR': 'Bluetooth koptu. Lütfen cihazınızı kontrol edin.',
      'EN': 'Bluetooth disconnected. Please check your device.',
      'DE': 'Bluetooth getrennt. Bitte überprüfen Sie Ihr Gerät.',
    },
    'cardSlot.ambiguityWarning': {
      'TR': 'Takılıysa okunamıyor veya geçersiz olabilir.',
      'EN': 'If inserted, it may be unreadable or invalid.',
      'DE': 'Falls eingelegt, evtl. unlesbar oder ungültig.',
    },
    'cardSlot.noCardSlot1': {
      'TR': 'Sürücü kartı takılı değil (Yuva 1).',
      'EN': 'No driver card (slot 1).',
      'DE': 'Keine Fahrerkarte (Fach 1).',
    },
    'cardSlot.noCardSlot2': {
      'TR': 'Yardımcı sürücü kartı takılı değil (Yuva 2).',
      'EN': 'No co-driver card (slot 2).',
      'DE': 'Keine Beifahrerkarte (Fach 2).',
    },
    'cardSlot.noCardBoth': {
      'TR': 'Sürücü kartı takılı değil (Yuva 1 ve 2).',
      'EN': 'No driver card (slots 1 and 2).',
      'DE': 'Keine Fahrerkarte (Fächer 1 und 2).',
    },
    'common.close': {'TR': 'Kapat', 'EN': 'Close', 'DE': 'Schließen'},

    'settings.deviceStatus': {
      'TR': 'Cihaz Durumu',
      'EN': 'Device Status',
      'DE': 'Gerätestatus',
    },
    'settings.connected': {
      'TR': 'Bağlantı Sağlandı, Veri Akışı Var',
      'EN': 'Connected — Data Flowing',
      'DE': 'Verbunden — Datenübertragung aktiv',
    },
    'settings.disconnected': {
      'TR': 'Takograf Bağlantısı Yok',
      'EN': 'Tachograph Disconnected',
      'DE': 'Fahrtenschreiber getrennt',
    },
    'settings.connectedNoData': {
      'TR': 'Bağlı, Veri Alınamıyor',
      'EN': 'Connected, No Data',
      'DE': 'Verbunden, Keine Daten',
    },
    'settings.lastSync': {
      'TR': 'Son senkronizasyon: ',
      'EN': 'Last sync: ',
      'DE': 'Letzte Synch.: ',
    },
    'settings.justNow': {
      'TR': 'az önce',
      'EN': 'just now',
      'DE': 'gerade eben',
    },
    'settings.minutesAgo': {
      'TR': '{count} dk önce',
      'EN': '{count} min ago',
      'DE': 'vor {count} Min.',
    },
    'settings.hoursAgo': {
      'TR': '{count} sa önce',
      'EN': '{count} h ago',
      'DE': 'vor {count} Std.',
    },
    'settings.daysAgo': {
      'TR': '{count} gün önce',
      'EN': '{count}d ago',
      'DE': 'vor {count} Tagen',
    },
    'settings.active': {
      'TR': 'Bağlantı Aktif',
      'EN': 'Connection Active',
      'DE': 'Verbindung Aktiv',
    },
    'settings.inactive': {
      'TR': 'Bağlantı Kesik',
      'EN': 'Disconnected',
      'DE': 'Verbindung Aus',
    },
    'settings.noData': {'TR': 'Veri Yok', 'EN': 'No Data', 'DE': 'Keine Daten'},
    'settings.tapToConnect': {
      'TR': 'Bağlanmak için dokunun',
      'EN': 'Tap to connect',
      'DE': 'Zum Verbinden tippen',
    },
    'settings.tapToDisconnect': {
      'TR': 'Bağlantıyı kesmek için dokunun',
      'EN': 'Tap to disconnect',
      'DE': 'Zum Trennen tippen',
    },

    'settings.vehicleInfo': {
      'TR': 'Bu Araç / Takograf',
      'EN': 'This Vehicle / Tachograph',
      'DE': 'Dieses Fahrzeug / Fahrtenschreiber',
    },
    'settings.vin': {
      'TR': 'Şasi No (VIN)',
      'EN': 'Chassis No. (VIN)',
      'DE': 'Fahrgestellnr. (VIN)',
    },
    'settings.vrn': {
      'TR': 'Plaka (VRN)',
      'EN': 'Plate (VRN)',
      'DE': 'Kennzeichen (VRN)',
    },
    'settings.memberState': {
      'TR': 'Kayıt Ülkesi',
      'EN': 'Registered State',
      'DE': 'Zulassungsstaat',
    },
    'settings.hwVersion': {
      'TR': 'Donanım Sürümü',
      'EN': 'Hardware Version',
      'DE': 'Hardware-Version',
    },
    'settings.swVersion': {
      'TR': 'Yazılım Sürümü',
      'EN': 'Software Version',
      'DE': 'Software-Version',
    },
    'settings.typeApproval': {
      'TR': 'Tip Onay No',
      'EN': 'Type Approval No.',
      'DE': 'Typgenehmigungsnr.',
    },
    'settings.dtcCount': {
      'TR': 'Arıza Kodu (DTC)',
      'EN': 'Fault Codes (DTC)',
      'DE': 'Fehlercodes (DTC)',
    },
    'settings.dtcNone': {
      'TR': 'Arıza yok',
      'EN': 'No faults',
      'DE': 'Keine Fehler',
    },
    'settings.supplier': {
      'TR': 'Üretici/Tedarikçi',
      'EN': 'Supplier',
      'DE': 'Lieferant',
    },
    'settings.ecuSerial': {
      'TR': 'Cihaz Seri No',
      'EN': 'Unit Serial No.',
      'DE': 'Geräte-Seriennr.',
    },
    'settings.ecuMfgDate': {
      'TR': 'Üretim Tarihi',
      'EN': 'Manufacturing Date',
      'DE': 'Herstellungsdatum',
    },
    'settings.calibrationDate': {
      'TR': 'Son Kalibrasyon',
      'EN': 'Last Calibration',
      'DE': 'Letzte Kalibrierung',
    },
    'settings.nextCalibrationDate': {
      'TR': 'Sonraki Kalibrasyon',
      'EN': 'Next Calibration',
      'DE': 'Nächste Kalibrierung',
    },
    'settings.ecuInstallDate': {
      'TR': 'Cihaz Montaj Tarihi',
      'EN': 'Unit Install Date',
      'DE': 'Einbaudatum',
    },
    'settings.vehicleRegDate': {
      'TR': 'Araç Tescil Tarihi',
      'EN': 'Vehicle Registration Date',
      'DE': 'Fahrzeug-Zulassungsdatum',
    },
    'settings.tripDistance': {
      'TR': 'Sefer Mesafesi',
      'EN': 'Trip Distance',
      'DE': 'Fahrtstrecke',
    },
    'settings.hwNumber': {
      'TR': 'Donanım Parça No',
      'EN': 'Hardware Part No.',
      'DE': 'Hardware-Teilenr.',
    },
    'settings.swNumber': {
      'TR': 'Yazılım Parça No',
      'EN': 'Software Part No.',
      'DE': 'Software-Teilenr.',
    },
    'settings.about': {'TR': 'Hakkında', 'EN': 'About', 'DE': 'Über'},
    'settings.aboutIdentitySection': {
      'TR': 'Araç Kimlik Bilgileri',
      'EN': 'Vehicle Identity',
      'DE': 'Fahrzeugkennung',
    },
    'settings.aboutManufacturerSection': {
      'TR': 'Takograf ve Sensör Üretici Bilgileri',
      'EN': 'Tachograph & Sensor Manufacturer Info',
      'DE': 'Hersteller-Infos zu Fahrtenschreiber & Sensor',
    },
    'settings.aboutVersionSection': {
      'TR': 'Versiyon Bilgileri',
      'EN': 'Version Info',
      'DE': 'Versionsinformationen',
    },
    'settings.aboutProductionSection': {
      'TR': 'Üretim ve Onay',
      'EN': 'Production & Approval',
      'DE': 'Herstellung & Zulassung',
    },
    'settings.aboutNoData': {
      'TR':
          'Bu bilgiler yalnızca takograf Bluetooth üzerinden bağlıyken görüntülenebilir.',
      'EN':
          'This information is only available while connected to the tachograph over Bluetooth.',
      'DE':
          'Diese Informationen sind nur verfügbar, wenn eine Bluetooth-Verbindung zum Fahrtenschreiber besteht.',
    },
    'settings.close': {'TR': 'Kapat', 'EN': 'Close', 'DE': 'Schließen'},

    'settings.tachoMode': {
      'TR': 'Takograf Modu',
      'EN': 'Tachograph Mode',
      'DE': 'Fahrtenschreiber-Modus',
    },
    'settings.tachoAutoDetected': {
      'TR': 'Bluetooth üzerinden otomatik algılanmaktadır.',
      'EN': 'Automatically detected via Bluetooth.',
      'DE': 'Wird automatisch über Bluetooth erkannt.',
    },
    'settings.simulation': {
      'TR': 'Kart Takma Simülasyonu',
      'EN': 'Card Insert Simulation',
      'DE': 'Karteneinsteck-Simulation',
    },
    'settings.simulationDesc': {
      'TR': 'Test amaçlı: Farklı kart türleri simüle edin.',
      'EN': 'For testing: Simulate different card types.',
      'DE': 'Zum Testen: Verschiedene Kartentypen simulieren.',
    },

    'settings.preferences': {
      'TR': 'Tercihler',
      'EN': 'Preferences',
      'DE': 'Präferenzen',
    },
    'settings.langSelect': {
      'TR': 'Dil Seçimi',
      'EN': 'Language Selection',
      'DE': 'Sprachauswahl',
    },
    'settings.themeSelect': {
      'TR': 'Tema Seçimi',
      'EN': 'Theme Selection',
      'DE': 'Themenauswahl',
    },
    'settings.themeSystem': {'TR': 'Sistem', 'EN': 'System', 'DE': 'System'},
    'settings.themeLight': {'TR': 'Açık', 'EN': 'Light', 'DE': 'Hell'},
    'settings.themeDark': {'TR': 'Koyu', 'EN': 'Dark', 'DE': 'Dunkel'},
    'settings.freeScreen': {
      'TR': 'Serbest Ekran',
      'EN': 'Free Screen',
      'DE': 'Freier Bildschirm',
    },
    'settings.freeScreenDesc': {
      'TR':
          'Uygulama içeriğinde iki parmakla yakınlaştırıp uzaklaşmayı etkinleştirir.',
      'EN': 'Enables pinch-to-zoom in and out on the app content.',
      'DE':
          'Aktiviert Zwei-Finger-Zoom (Vergrößern/Verkleinern) im App-Inhalt.',
    },
    'select.title': {
      'TR': 'Takograf Seçin',
      'EN': 'Choose Your Tachograph',
      'DE': 'Fahrtenschreiber wählen',
    },
    'select.subtitle': {
      'TR': 'Bağlanacağınız takografın tipini seçin',
      'EN': 'Choose the type of tachograph to connect to',
      'DE': 'Wählen Sie den Typ des Fahrtenschreibers für die Verbindung',
    },
    'select.stc8255Desc': {
      'TR': 'Aselsan STC-8255 · BLE dongle üzerinden canlı sürüş verisi',
      'EN': 'Aselsan STC-8255 · live driving data through the BLE dongle',
      'DE': 'Aselsan STC-8255 · Live-Fahrdaten über den BLE-Dongle',
    },
    'select.atc8256Desc': {
      'TR': 'ATC-8256 · canlı sürüş verisi, ITS veri indirme ve diagnostik',
      'EN': 'ATC-8256 · live driving data, ITS data download and diagnostics',
      'DE': 'ATC-8256 · Live-Fahrdaten, ITS-Datendownload und Diagnose',
    },
    'connect.title': {'TR': 'Bağlan', 'EN': 'Connect', 'DE': 'Verbinden'},
    'conn.connectTooltip': {
      'TR': 'Takografa bağlan',
      'EN': 'Connect to the tachograph',
      'DE': 'Mit dem Fahrtenschreiber verbinden',
    },
    'conn.connectedTooltip': {
      'TR': 'Bağlı — bağlantıyı kesmek için dokunun',
      'EN': 'Connected — tap to disconnect',
      'DE': 'Verbunden — zum Trennen tippen',
    },
    'conn.disconnectTitle': {
      'TR': 'Bağlantı kesilsin mi?',
      'EN': 'Disconnect?',
      'DE': 'Verbindung trennen?',
    },
    'conn.disconnectBody': {
      'TR':
          '{device} ile bağlantı kapatılacak. Veriler yeniden bağlanana kadar güncellenmez.',
      'EN':
          'The connection to {device} will be closed. Data will not update until you connect again.',
      'DE':
          'Die Verbindung zu {device} wird getrennt. Die Daten werden bis zur erneuten Verbindung nicht aktualisiert.',
    },
    'conn.disconnect': {
      'TR': 'Bağlantıyı kes',
      'EN': 'Disconnect',
      'DE': 'Trennen',
    },
    'conn.cancel': {'TR': 'Vazgeç', 'EN': 'Cancel', 'DE': 'Abbrechen'},
    'conn.disconnected': {
      'TR': 'Takograf bağlantısı kesildi',
      'EN': 'Disconnected from the tachograph',
      'DE': 'Vom Fahrtenschreiber getrennt',
    },
    'ddd.itsNotConnected': {
      'TR': 'ITS indirme için önce takografa (ATC 8256) bağlanın.',
      'EN': 'Connect to the tachograph (ATC 8256) first to download over ITS.',
      'DE':
          'Zuerst mit dem Fahrtenschreiber (ATC 8256) verbinden, um über ITS herunterzuladen.',
    },
    'ddd.itsOpening': {
      'TR': 'İndirme kanalı açılıyor…',
      'EN': 'Opening the download channel…',
      'DE': 'Download-Kanal wird geöffnet…',
    },
    'ddd.itsSaving': {
      'TR': 'Kaydediliyor…',
      'EN': 'Saving…',
      'DE': 'Wird gespeichert…',
    },
    'ddd.itsNothing': {
      'TR': 'Takograf veri göndermedi.',
      'EN': 'The tachograph sent no data.',
      'DE': 'Der Fahrtenschreiber hat keine Daten gesendet.',
    },
    'ddd.itsDone': {
      'TR': 'İndirildi ve kaydedildi.',
      'EN': 'Downloaded and saved.',
      'DE': 'Heruntergeladen und gespeichert.',
    },
    'ddd.itsPartial': {
      'TR': 'Kaydedildi, ama bir kısmı alınamadı:',
      'EN': 'Saved, but some of it could not be downloaded:',
      'DE': 'Gespeichert, aber ein Teil konnte nicht heruntergeladen werden:',
    },
    'connect.mismatchTitle': {
      'TR': 'Takograf tipi uyuşmuyor',
      'EN': 'Tachograph type does not match',
      'DE': 'Fahrtenschreibertyp stimmt nicht überein',
    },
    'connect.mismatchBody': {
      'TR':
          '{device} bir {detected} görünüyor, ama {selected} seçildi. Yanlış profille bağlanılırsa takograf her mesajı hatalı sayar.',
      'EN':
          '{device} looks like a {detected}, but {selected} was chosen. Connected with the wrong profile, the tachograph rejects every message as malformed.',
      'DE':
          '{device} scheint ein {detected} zu sein, gewählt wurde aber {selected}. Mit dem falschen Profil wertet der Fahrtenschreiber jede Nachricht als fehlerhaft.',
    },
    'connect.mismatchSwitch': {
      'TR': '{detected} olarak bağlan',
      'EN': 'Connect as {detected}',
      'DE': 'Als {detected} verbinden',
    },
    'connect.mismatchKeep': {
      'TR': 'Seçimle devam et',
      'EN': 'Keep my choice',
      'DE': 'Auswahl beibehalten',
    },
    'connect.mismatchCancel': {
      'TR': 'Vazgeç',
      'EN': 'Cancel',
      'DE': 'Abbrechen',
    },
    'connect.skip': {
      'TR': 'Bağlanmadan devam et',
      'EN': 'Continue without connecting',
      'DE': 'Ohne Verbindung fortfahren',
    },
    'settings.liveRefresh': {
      'TR': 'Otomatik Veri Yenileme',
      'EN': 'Automatic Data Refresh',
      'DE': 'Automatische Datenaktualisierung',
    },
    'settings.liveRefreshDesc': {
      'TR':
          'Bağlıyken takograf verilerinin ne sıklıkla okunacağı. Kapalıyken veriler yalnızca üst bardaki yenile düğmesiyle güncellenir; çizelge de yalnızca o anlarda kayıt alır.',
      'EN':
          'How often tachograph data is read while connected. When off, data is updated only with the refresh button in the top bar, and the timeline records only at those moments.',
      'DE':
          'Wie oft die Fahrtenschreiberdaten bei bestehender Verbindung gelesen werden. Wenn deaktiviert, werden die Daten nur über die Schaltfläche in der oberen Leiste aktualisiert, und die Zeitleiste zeichnet nur dann auf.',
    },
    'settings.liveRefreshOff': {'TR': 'Kapalı', 'EN': 'Off', 'DE': 'Aus'},
    'settings.liveRefreshSeconds': {'TR': 'sn', 'EN': 's', 'DE': 's'},
    'settings.liveRefreshMinutes': {'TR': 'dk', 'EN': 'min', 'DE': 'Min'},
    'live.refresh': {
      'TR': 'Verileri yenile',
      'EN': 'Refresh data',
      'DE': 'Daten aktualisieren',
    },
    'live.refreshed': {
      'TR': 'Takograf verileri güncellendi',
      'EN': 'Tachograph data updated',
      'DE': 'Fahrtenschreiberdaten aktualisiert',
    },
    'live.refreshFailed': {
      'TR': 'Takograf yanıt vermedi, veriler güncellenemedi',
      'EN': 'The tachograph did not answer; data was not updated',
      'DE':
          'Der Fahrtenschreiber hat nicht geantwortet; Daten nicht aktualisiert',
    },
    'settings.backupTitle': {
      'TR': 'Google Drive Yedekleme',
      'EN': 'Google Drive Backup',
      'DE': 'Google Drive Sicherung',
    },
    'settings.backupDesc': {
      'TR':
          'İndirdiğiniz her .ddd dosyasının bir kopyası bağlı Google Drive hesabınıza yüklenir.',
      'EN':
          'A copy of every .ddd file you download is uploaded to your connected Google Drive account.',
      'DE':
          'Eine Kopie jeder heruntergeladenen .ddd-Datei wird in Ihr verbundenes Google-Drive-Konto hochgeladen.',
    },
    'settings.statusActive': {'TR': 'Aktif', 'EN': 'Active', 'DE': 'Aktiv'},
    'settings.statusInactive': {
      'TR': 'Bağlı değil',
      'EN': 'Not connected',
      'DE': 'Nicht verbunden',
    },

    'dashboard.drivingData': {
      'TR': 'SÜRÜŞ VERİLERİ',
      'EN': 'DRIVING DATA',
      'DE': 'FAHRDATEN',
    },
    'dashboard.plateLabel': {
      'TR': 'ARAÇ PLAKASI',
      'EN': 'VEHICLE PLATE',
      'DE': 'KENNZEICHEN',
    },
    'dashboard.driver1Tab': {
      'TR': '1. Sürücü',
      'EN': '1st Driver',
      'DE': '1. Fahrer',
    },
    'dashboard.driver2Tab': {
      'TR': '2. Sürücü',
      'EN': '2nd Driver',
      'DE': '2. Fahrer',
    },
    'dashboard.mainDriver': {
      'TR': 'Ana Sürücü',
      'EN': 'Main Driver',
      'DE': 'Hauptfahrer',
    },
    'dashboard.backupDriver': {
      'TR': 'Yedek Sürücü',
      'EN': 'Backup Driver',
      'DE': 'Ersatzfahrer',
    },
    'dashboard.speed': {
      'TR': 'Anlık Hız',
      'EN': 'Current Speed',
      'DE': 'Aktuelle Geschwindigkeit',
    },
    'dashboard.distance': {
      'TR': 'Gidilen Mesafe',
      'EN': 'Distance Traveled',
      'DE': 'Zurückgelegte Strecke',
    },

    'driverMode.button': {
      'TR': 'Sürüş Moduna Geç',
      'EN': 'Switch to Driving Mode',
      'DE': 'Zum Fahrmodus wechseln',
    },
    'driverMode.buttonHint': {
      'TR':
          'Telefonu yatay tutarken sürüş sırasında en önemli verileri büyük ve sade bir ekranda gösterir.',
      'EN':
          'Shows the most important data on a large, simplified screen for glancing while driving, phone held landscape.',
      'DE':
          'Zeigt beim Fahren die wichtigsten Daten groß und übersichtlich an, Telefon im Querformat.',
    },
    'driverMode.title': {
      'TR': 'Sürücü Modu',
      'EN': 'Driver Mode',
      'DE': 'Fahrermodus',
    },
    'driverMode.speedUnit': {'TR': 'KM/S', 'EN': 'KM/H', 'DE': 'KM/H'},
    'driverMode.dailyDriving': {
      'TR': 'Günlük Sürüş',
      'EN': 'Daily Driving',
      'DE': 'Tageslenkzeit',
    },
    'driverMode.weeklyDriving': {
      'TR': 'Haftalık Sürüş',
      'EN': 'Weekly Driving',
      'DE': 'Wochenlenkzeit',
    },
    'driverMode.nextRest': {
      'TR': 'Sonraki Dinlenme',
      'EN': 'Next Rest',
      'DE': 'Nächste Ruhezeit',
    },
    'driverMode.nextRestStartsAt': {
      'TR': "{time}'te başlamalı",
      'EN': 'Should start at {time}',
      'DE': 'Sollte um {time} beginnen',
    },
    'driverMode.distance': {
      'TR': 'Gidilen Mesafe',
      'EN': 'Distance',
      'DE': 'Strecke',
    },
    'driverMode.safeLimit': {
      'TR': 'Güvenli limit dahilinde',
      'EN': 'Within safe limit',
      'DE': 'Innerhalb des sicheren Limits',
    },
    'driverMode.speedWarning': {
      'TR': 'HIZ SINIRI AŞIMI',
      'EN': 'SPEED LIMIT EXCEEDED',
      'DE': 'GESCHWINDIGKEITSÜBERSCHREITUNG',
    },
    'driverMode.noData': {
      'TR': 'Veri Yok',
      'EN': 'No Data',
      'DE': 'Keine Daten',
    },
    'dashboard.break_': {'TR': 'MOLA', 'EN': 'BREAK', 'DE': 'PAUSE'},
    'dashboard.driving': {'TR': 'Sürüş', 'EN': 'Driving', 'DE': 'Fahren'},
    'dashboard.otherWork': {
      'TR': 'Diğer Çalışmalar',
      'EN': 'Other Work',
      'DE': 'Andere Arbeit',
    },
    'dashboard.availability': {
      'TR': 'Hazır Bulunma',
      'EN': 'Availability',
      'DE': 'Bereitschaft',
    },
    'dashboard.rest': {'TR': 'Dinlenme', 'EN': 'Rest', 'DE': 'Ruhezeit'},
    'dashboard.noData': {'TR': '-', 'EN': '-', 'DE': '-'},
    'dashboard.activeMode': {
      'TR': 'Aktif: Sürücü Modu',
      'EN': 'Active: Driver Mode',
      'DE': 'Aktiv: Fahrermodus',
    },
    'dashboard.speedError': {
      'TR': 'HATA: Hız aşımı!',
      'EN': 'ERROR: Speed exceeded!',
      'DE': 'FEHLER: Geschwindigkeitsüberschreitung!',
    },
    'dashboard.speedErrorMsg': {
      'TR': 'Lütfen yasal hız sınırlarına uyunuz.',
      'EN': 'Please observe the legal speed limits.',
      'DE': 'Bitte beachten Sie die gesetzlichen Geschwindigkeitsbegrenzungen.',
    },

    'timeline.title': {
      'TR': 'Günlük Zaman Çizelgesi',
      'EN': 'Daily Timeline',
      'DE': 'Tägliche Zeitleiste',
    },
    'timeline.activity': {
      'TR': '24 Saatlik Aktivite',
      'EN': '24-Hour Activity',
      'DE': '24-Stunden-Aktivität',
    },
    'timeline.summary': {
      'TR': 'Günlük Özet',
      'EN': 'Daily Summary',
      'DE': 'Tagesübersicht',
    },
    'timeline.detailedLog': {
      'TR': 'Detaylı Zaman Damgaları',
      'EN': 'Detailed Timestamps',
      'DE': 'Detaillierte Zeitstempel',
    },
    'timeline.driving': {'TR': 'Sürüş', 'EN': 'Driving', 'DE': 'Fahren'},
    'timeline.break_': {'TR': 'Mola', 'EN': 'Break', 'DE': 'Pause'},
    'timeline.work': {'TR': 'Çalışma', 'EN': 'Work', 'DE': 'Arbeit'},
    'timeline.available': {
      'TR': 'Hazır Bulunma',
      'EN': 'Availability',
      'DE': 'Bereitschaft',
    },
    'timeline.violation': {'TR': 'İhlal', 'EN': 'Violation', 'DE': 'Verstoß'},
    'timeline.noData': {
      'TR': 'Bu gün için kayıt yok',
      'EN': 'No records for this day',
      'DE': 'Keine Einträge für diesen Tag',
    },
    'timeline.totalDriving': {
      'TR': 'Toplam Sürüş',
      'EN': 'Total Driving',
      'DE': 'Gesamtfahrzeit',
    },
    'timeline.totalBreak': {
      'TR': 'Toplam Mola',
      'EN': 'Total Break',
      'DE': 'Gesamtpause',
    },
    'timeline.otherWork': {
      'TR': 'Diğer Çalışma',
      'EN': 'Other Work',
      'DE': 'Andere Arbeit',
    },
    'timeline.violationTime': {
      'TR': 'İhlal Süresi',
      'EN': 'Violation Time',
      'DE': 'Verstoßzeit',
    },
    'timeline.time': {'TR': 'Zaman', 'EN': 'Time', 'DE': 'Zeit'},
    'timeline.status': {'TR': 'Durum', 'EN': 'Status', 'DE': 'Status'},
    'timeline.duration': {'TR': 'Süre', 'EN': 'Duration', 'DE': 'Dauer'},
    'timeline.description': {
      'TR': 'Açıklama / Konum',
      'EN': 'Description / Location',
      'DE': 'Beschreibung / Ort',
    },
    'timeline.prev': {'TR': 'Önceki', 'EN': 'Previous', 'DE': 'Vorherige'},
    'timeline.today': {'TR': 'Bugün', 'EN': 'Today', 'DE': 'Heute'},
    'timeline.next': {'TR': 'Sonraki', 'EN': 'Next', 'DE': 'Nächste'},

    'logs.activityHistory': {
      'TR': 'Aktivite Geçmişi',
      'EN': 'Activity History',
      'DE': 'Aktivitätsverlauf',
    },
    'logs.filter': {'TR': 'Filtrele', 'EN': 'Filter', 'DE': 'Filtern'},
    'logs.dateTime': {
      'TR': 'TARİH / SAAT',
      'EN': 'DATE / TIME',
      'DE': 'DATUM / UHRZEIT',
    },
    'logs.activity': {'TR': 'AKTİVİTE', 'EN': 'ACTIVITY', 'DE': 'AKTIVITÄT'},
    'logs.duration': {'TR': 'SÜRE', 'EN': 'DURATION', 'DE': 'DAUER'},
    'logs.distance': {'TR': 'MESAFE', 'EN': 'DISTANCE', 'DE': 'ENTFERNUNG'},
    'logs.status': {'TR': 'DURUM', 'EN': 'STATUS', 'DE': 'STATUS'},
    'logs.now': {'TR': 'Şu an', 'EN': 'Now', 'DE': 'Jetzt'},
    'logs.currentDrive': {
      'TR': 'Mevcut Sürüş',
      'EN': 'Current Drive',
      'DE': 'Aktuelle Fahrt',
    },
    'logs.ongoing': {'TR': 'Devam Ediyor', 'EN': 'Ongoing', 'DE': 'Laufend'},
    'logs.completed': {
      'TR': 'Tamamlandı',
      'EN': 'Completed',
      'DE': 'Abgeschlossen',
    },
    'logs.warning': {'TR': 'Uyarı', 'EN': 'Warning', 'DE': 'Warnung'},
    'logs.driving': {'TR': 'Sürüş', 'EN': 'Driving', 'DE': 'Fahren'},
    'logs.break_': {'TR': 'Mola', 'EN': 'Break', 'DE': 'Pause'},
    'logs.todayAt': {'TR': 'Bugün', 'EN': 'Today', 'DE': 'Heute'},
    'logs.yesterday': {'TR': 'Dün', 'EN': 'Yesterday', 'DE': 'Gestern'},
    'logs.seeAll': {
      'TR': 'Tüm Geçmişi Gör',
      'EN': 'See All History',
      'DE': 'Gesamten Verlauf anzeigen',
    },
    'logs.showLess': {
      'TR': 'Daha Az Göster',
      'EN': 'Show Less',
      'DE': 'Weniger anzeigen',
    },

    'compliance.currentStatus': {
      'TR': 'MEVCUT DURUM',
      'EN': 'CURRENT STATUS',
      'DE': 'AKTUELLER STATUS',
    },
    'compliance.activeSession': {
      'TR': 'AKTİF OTURUM',
      'EN': 'ACTIVE SESSION',
      'DE': 'AKTIVE SITZUNG',
    },

    'compliance.staleSuffix': {
      'TR': '(son)',
      'EN': '(last)',
      'DE': '(zuletzt)',
    },
    'compliance.parametersTitle': {
      'TR': 'Sürüş ve Dinlenme',
      'EN': 'Driving and Rest',
      'DE': 'Fahren und Ruhezeit',
    },
    'compliance.timeUntilBreak': {
      'TR': 'Molaya Kalan Süre',
      'EN': 'Time Until Break',
      'DE': 'Zeit bis zur Pause',
    },
    'compliance.hoursUnit': {'TR': 'SAAT', 'EN': 'HOURS', 'DE': 'STUNDEN'},
    'compliance.critical': {'TR': 'Kritik', 'EN': 'Critical', 'DE': 'Kritisch'},
    'compliance.cumulativeBreak': {
      'TR': 'Kümülatif mola süresi',
      'EN': 'Cumulative break time',
      'DE': 'Kumulierte Pausenzeit',
    },
    'compliance.dailyUsage': {
      'TR': 'Günlük Sürüş Süresi',
      'EN': 'Daily Driving Time',
      'DE': 'Tageslenkzeit',
    },
    'compliance.continuousUsage': {
      'TR': 'Kesintisiz Sürüş',
      'EN': 'Continuous Driving',
      'DE': 'Ununterbrochenes Fahren',
    },
    'compliance.crewStatus': {
      'TR': 'Ekip Durumu',
      'EN': 'Crew Status',
      'DE': 'Besatzungsstatus',
    },
    'compliance.registeredCountry': {
      'TR': 'Kayıtlı Ülke',
      'EN': 'Registered Country',
      'DE': 'Zulassungsland',
    },
    'compliance.weeklyDriving': {
      'TR': 'Haftalık sürüş',
      'EN': 'Weekly driving',
      'DE': 'Wöchentliches Fahren',
    },
    'compliance.biWeeklyTotal': {
      'TR': '2 haftalık toplam',
      'EN': '2-week total',
      'DE': '2-Wochen-Gesamt',
    },

    'compliance.detailsTitle': {
      'TR': 'MOLA VE DİNLENME DETAYLARI',
      'EN': 'BREAK & REST DETAILS',
      'DE': 'PAUSEN- & RUHEZEITDETAILS',
    },
    'compliance.dailyParametersTitle': {
      'TR': 'GÜNLÜK PARAMETRELER',
      'EN': 'DAILY PARAMETERS',
      'DE': 'TAGESPARAMETER',
    },
    'compliance.weeklyParametersTitle': {
      'TR': 'HAFTALIK PARAMETRELER',
      'EN': 'WEEKLY PARAMETERS',
      'DE': 'WOCHENPARAMETER',
    },
    'compliance.compensationDebtsTitle': {
      'TR': 'TELAFİ BORÇLARI',
      'EN': 'COMPENSATION DEBTS',
      'DE': 'AUSGLEICHSSCHULDEN',
    },
    'compliance.noCompensationDebts': {
      'TR': 'Telafi borcunuz yok',
      'EN': 'No compensation owed',
      'DE': 'Keine Ausgleichsschuld',
    },
    'compliance.compensationDeadlineToday': {
      'TR': 'Bugün son gün',
      'EN': 'Due today',
      'DE': 'Heute fällig',
    },
    'compliance.noCompensationNeeded': {
      'TR': 'Bu kısaltma için telafi gerekmez',
      'EN': 'No compensation required for this reduction',
      'DE': 'Für diese Verkürzung ist kein Ausgleich erforderlich',
    },

    'compliance.remaining10h': {
      'TR': 'Sürüşü 10 Saate Uzatma',
      'EN': 'Extend Driving to 10h',
      'DE': 'Lenkzeit auf 10 Std. verlängern',
    },
    'compliance.remaining10hHint': {
      'TR':
          'Bu hafta sürüşünüzü 10 saate uzatabileceğiniz, kalan hakkınız (haftada en fazla 2 kez).',
      'EN':
          'How many times you can still extend driving to 10h this week (max twice a week).',
      'DE':
          'Wie oft du die Lenkzeit diese Woche noch auf 10 Std. verlängern kannst (höchstens zweimal).',
    },

    'compliance.remainingReducedRest': {
      'TR': 'Kısaltılmış Dinlenme',
      'EN': 'Reduced Rest',
      'DE': 'Verkürzte Ruhezeit',
    },
    'compliance.remainingReducedRestHint': {
      'TR':
          'İki haftalık dinlenme arasında kısaltılmış (en az 9 saat) günlük dinlenme kullanabileceğiniz, kalan hakkınız (en fazla 3 kez).',
      'EN':
          'How many reduced (min. 9h) daily rests you can still take before your next weekly rest (max 3).',
      'DE':
          'Wie viele verkürzte (mind. 9 Std.) Tagesruhezeiten dir bis zur nächsten Wochenruhezeit noch bleiben (max. 3).',
    },

    'compliance.nextBreakDuration': {
      'TR': 'Almanız Gereken Minimum Mola Süresi',
      'EN': 'Required Minimum Next Break Duration',
      'DE': 'Erforderliche Mindestdauer der nächsten Pause',
    },
    'compliance.nextBreakDurationHint': {
      'TR':
          'Sıradaki molanın geçerli sayılması için almanız gereken toplam süre.',
      'EN': 'The total duration your next break must last to count as valid.',
      'DE':
          'Die Gesamtdauer, die deine nächste Pause haben muss, um gültig zu sein.',
    },

    'compliance.deviceReportsNoData': {
      'TR': 'Yok',
      'EN': 'N/A',
      'DE': 'Keine Daten',
    },

    'compliance.currentBreakRemaining': {
      'TR': 'Şu Anki Moladan Kalan',
      'EN': 'Remaining Time in Current Break',
      'DE': 'Verbleibende Zeit der aktuellen Pause',
    },
    'compliance.currentBreakRemainingHint': {
      'TR':
          'Şu anki molanın geçerli sayılması için ne kadar daha beklemeniz gerektiği.',
      'EN':
          'How much longer your current break needs to last to count as valid.',
      'DE':
          'Wie viel länger deine aktuelle Pause dauern muss, um gültig zu sein.',
    },

    'compliance.lastDailyRestEnd': {
      'TR': 'Son Günlük Dinlenmenizi Yaptığınız Tarih',
      'EN': 'When You Took Your Last Daily Rest',
      'DE': 'Zeitpunkt Ihrer letzten Tagesruhezeit',
    },
    'compliance.lastDailyRestEndHint': {
      'TR': 'En son geçerli günlük dinlenmenizi bitirdiğiniz tarih ve saat.',
      'EN': 'The date and time your last valid daily rest ended.',
      'DE':
          'Datum und Uhrzeit, zu der deine letzte gültige Tagesruhezeit endete.',
    },
    'compliance.lastWeeklyRestEnd': {
      'TR': 'Son Haftalık Dinlenmenin Bitiş Tarihi',
      'EN': 'End Date of Last Weekly Rest',
      'DE': 'Enddatum der letzten Wochenruhezeit',
    },
    'compliance.lastWeeklyRestEndHint': {
      'TR': 'En son geçerli haftalık dinlenmenin bittiği tarih ve saat.',
      'EN': 'The date and time your last valid weekly rest ended.',
      'DE':
          'Datum und Uhrzeit, zu der deine letzte gültige Wochenruhezeit endete.',
    },

    'compliance.compensationLastWeek': {
      'TR': 'Bu Haftanın Telafi Borcu',
      'EN': "This Week's Compensation Owed",
      'DE': 'Ausgleichsschuld dieser Woche',
    },
    'compliance.compensationLastWeekHint': {
      'TR':
          'Bu hafta kısa (45 saatten az) dinlenme aldıysanız, 3 hafta içinde telafi etmeniz gereken süre.',
      'EN':
          'If you took a short (under 45h) weekly rest this week, how much you must add to a later rest within 3 weeks.',
      'DE':
          'Falls du diese Woche eine kurze Wochenruhezeit (unter 45 Std.) genommen hast, die Zeit, die du innerhalb von 3 Wochen nachholen musst.',
    },

    'compliance.compensationWeekBeforeLast': {
      'TR': 'Geçen Haftanın Telafi Borcu',
      'EN': "Last Week's Compensation Owed",
      'DE': 'Ausgleichsschuld der letzten Woche',
    },
    'compliance.compensationWeekBeforeLastHint': {
      'TR':
          'Geçen hafta kısa (45 saatten az) dinlenme aldıysanız, 3 hafta içinde telafi etmeniz gereken süre.',
      'EN':
          'If you took a short (under 45h) weekly rest last week, how much you must add to a later rest within 3 weeks.',
      'DE':
          'Falls du letzte Woche eine kurze Wochenruhezeit (unter 45 Std.) genommen hast, die Zeit, die du innerhalb von 3 Wochen nachholen musst.',
    },

    'compliance.compensation2ndWeekBeforeLast': {
      'TR': '2 Hafta Önceki Telafi Borcu',
      'EN': 'Compensation Owed From 2 Weeks Ago',
      'DE': 'Ausgleichsschuld von vor 2 Wochen',
    },
    'compliance.compensation2ndWeekBeforeLastHint': {
      'TR':
          '2 hafta önce kısa (45 saatten az) dinlenme aldıysanız, 3 hafta içinde telafi etmeniz gereken süre.',
      'EN':
          'If you took a short (under 45h) weekly rest 2 weeks ago, how much you must add to a later rest within 3 weeks.',
      'DE':
          'Falls du vor 2 Wochen eine kurze Wochenruhezeit (unter 45 Std.) genommen hast, die Zeit, die du innerhalb von 3 Wochen nachholen musst.',
    },

    'compliance.minimumDailyRest': {
      'TR': 'Şu An İçin Asgari Günlük Dinlenme',
      'EN': 'Minimum Daily Rest Right Now',
      'DE': 'Aktuelle Mindest-Tagesruhezeit',
    },
    'compliance.minimumDailyRestHint': {
      'TR':
          'Şu anki hakkınıza göre (normal ya da kısaltılmış) almanız gereken en az günlük dinlenme süresi.',
      'EN':
          'The minimum daily rest you must take right now, based on your current (normal or reduced) entitlement.',
      'DE':
          'Die minimale Tagesruhezeit, die du aktuell nehmen musst (normaler oder verkürzter Anspruch).',
    },

    'compliance.minimumWeeklyRest': {
      'TR': 'Şu An İçin Asgari Haftalık Dinlenme',
      'EN': 'Minimum Weekly Rest Right Now',
      'DE': 'Aktuelle Mindest-Wochenruhezeit',
    },
    'compliance.minimumWeeklyRestHint': {
      'TR':
          'Şu anki hakkınıza göre (normal ya da kısaltılmış) almanız gereken en az haftalık dinlenme süresi.',
      'EN':
          'The minimum weekly rest you must take right now, based on your current (normal or reduced) entitlement.',
      'DE':
          'Die minimale Wochenruhezeit, die du aktuell nehmen musst (normaler oder verkürzter Anspruch).',
    },

    'compliance.splitBreakStatus': {
      'TR': 'Bölünmüş Mola Durumu',
      'EN': 'Split-Break Status',
      'DE': 'Status der geteilten Pause',
    },
    'compliance.splitBreakStatusHint': {
      'TR':
          'Bölünmüş molada sıra önemli: önce en az 15 dk, sonra en az 30 dk — ters sırayla alınırsa geçerli sayılmaz.',
      'EN':
          'Order matters for a split break: at least 15 min first, then 30 min — the wrong order doesn\'t count.',
      'DE':
          'Bei der geteilten Pause zählt die Reihenfolge: zuerst mind. 15 Min., dann mind. 30 Min. — falsche Reihenfolge zählt nicht.',
    },
    'compliance.splitBreakValid': {
      'TR': 'Sorun yok',
      'EN': 'No issue',
      'DE': 'Kein Problem',
    },
    'compliance.splitBreakIncomplete': {
      'TR': 'Tamamlanmadı',
      'EN': 'Incomplete',
      'DE': 'Unvollständig',
    },

    'compliance.timeUntilBreakHint': {
      'TR': 'Zorunlu molaya kadar kalan kesintisiz sürüş süreniz.',
      'EN': 'Continuous driving time left before a mandatory break.',
      'DE': 'Verbleibende ununterbrochene Lenkzeit bis zur Pflichtpause.',
    },
    'compliance.cumulativeBreakHint': {
      'TR':
          'Bugün kesintisiz sürüşü bölmek için şimdiye kadar alınan toplam mola süresi (4 sa 30 dk sürüşe en az 45 dk gerekir).',
      'EN':
          'Total break time taken today to interrupt continuous driving (at least 45 min required per 4h30 of driving).',
      'DE':
          'Heute bisher genommene Gesamtpausenzeit zur Unterbrechung der Lenkzeit (mind. 45 Min. je 4:30 Std. Lenkzeit).',
    },
    'compliance.weeklyDrivingHint': {
      'TR':
          'Bu haftaki (pazartesiden itibaren) toplam sürüş süreniz — yasal sınır 56 saat.',
      'EN':
          'Total driving time this week from Monday — legal limit is 56 hours.',
      'DE':
          'Gesamtlenkzeit dieser Woche ab Montag — gesetzliche Grenze 56 Stunden.',
    },
    'compliance.biWeeklyTotalHint': {
      'TR':
          'Bu hafta ve geçen hafta birlikte toplam sürüş süreniz — yasal sınır 90 saat.',
      'EN':
          'Total driving time across this week and last week — legal limit is 90 hours.',
      'DE':
          'Gesamtlenkzeit dieser und letzter Woche zusammen — gesetzliche Grenze 90 Stunden.',
    },
    'compliance.continuousUsageHint': {
      'TR':
          'Son moladan bu yana kesintisiz sürüş süreniz — en fazla 4 sa 30 dk, sonra en az 45 dk mola zorunlu.',
      'EN':
          'Continuous driving time since your last break — max 4h30, then a 45-minute break is mandatory.',
      'DE':
          'Ununterbrochene Lenkzeit seit der letzten Pause — max. 4:30 Std., danach ist eine 45-minütige Pause Pflicht.',
    },
    'compliance.dailyUsageHint': {
      'TR':
          'Son dinlenmenizden bu yana kesintisiz sürüş süreniz — gece yarısı değil, ancak yeterli (en az 9 saat) dinlenme aldığınızda sıfırlanır; normal sınır 9 saat (haftada 2 kez 10 saate uzatılabilir).',
      'EN':
          'Driving time since your last rest — resets only on a qualifying (min. 9h) rest, not at midnight; normal limit is 9 hours (extendable to 10h twice a week).',
      'DE':
          'Lenkzeit seit deiner letzten Ruhezeit — wird nicht um Mitternacht, sondern erst bei einer ausreichenden (mind. 9 Std.) Ruhezeit zurückgesetzt; normale Grenze 9 Std. (zweimal wöchentlich auf 10 Std. verlängerbar).',
    },
    'compliance.warningsTitle': {
      'TR': 'Uyarılar ve Durum',
      'EN': 'Warnings and Status',
      'DE': 'Warnungen und Status',
    },
    'compliance.driverCard': {
      'TR': 'Sürücü kartı',
      'EN': 'Driver card',
      'DE': 'Fahrerkarte',
    },
    'compliance.driverCardExpiring': {
      'TR': 'Son kullanma yaklaşıyor',
      'EN': 'Expiry approaching',
      'DE': 'Ablauf naht',
    },
    'compliance.driverCardExpired': {
      'TR': 'Süresi doldu',
      'EN': 'Expired',
      'DE': 'Abgelaufen',
    },
    'compliance.daysLeft': {
      'TR': '{d} gün kaldı',
      'EN': '{d} days left',
      'DE': '{d} Tage übrig',
    },
    'compliance.calibration': {
      'TR': 'Kalibrasyon',
      'EN': 'Calibration',
      'DE': 'Kalibrierung',
    },
    'compliance.calibrationDesc': {
      'TR': 'Takograf hassasiyet kontrolü',
      'EN': 'Tachograph precision check',
      'DE': 'Präzisionsprüfung des Fahrtenschreibers',
    },
    'compliance.calibrationUpToDate': {
      'TR': 'GÜNCEL',
      'EN': 'UP TO DATE',
      'DE': 'AKTUELL',
    },
    'compliance.calibrationDueSoon': {
      'TR': 'YAKINDA GEREKLİ',
      'EN': 'DUE SOON',
      'DE': 'BALD FÄLLIG',
    },
    'compliance.calibrationOverdue': {
      'TR': 'GECİKTİ',
      'EN': 'OVERDUE',
      'DE': 'ÜBERFÄLLIG',
    },
    'compliance.noViolations': {
      'TR': 'İhlal Yok',
      'EN': 'No Violations',
      'DE': 'Keine Verstöße',
    },
    'compliance.noViolationsDesc': {
      'TR': 'Yönetmelik sınırları içindesiniz.',
      'EN': 'You are within regulation limits.',
      'DE': 'Sie befinden sich innerhalb der Vorschriftsgrenzen.',
    },

    'notifications.title': {
      'TR': 'Bildirimler',
      'EN': 'Notifications',
      'DE': 'Benachrichtigungen',
    },
    'notifications.empty': {
      'TR': 'Aktif sürüş/dinlenme ihlali veya uyarısı yok.',
      'EN': 'No active driving/rest violations or warnings.',
      'DE': 'Keine aktiven Lenk-/Ruhezeitverstöße oder -warnungen.',
    },
    'notifications.since': {
      'TR': 'saatinden beri',
      'EN': 'since',
      'DE': 'seit',
    },
    'notifications.violationTitle': {
      'TR': 'Sürüş/Dinlenme İhlali',
      'EN': 'Driving/Rest Violation',
      'DE': 'Lenk-/Ruhezeitverstoß',
    },
    'notifications.violationSummaryBody': {
      'TR':
          '{count} adet sürüş/dinlenme ihlaliniz var. Detaylar için Uyarılar sekmesine bakın.',
      'EN':
          'You have {count} driving/rest violation(s). See the Alerts tab for details.',
      'DE':
          'Sie haben {count} Lenk-/Ruhezeitverstoß/-verstöße. Details im Tab „Warnungen“.',
    },
    'notifications.noticeTitle': {
      'TR': 'Uyarı',
      'EN': 'Warning',
      'DE': 'Warnung',
    },
    'notifications.compensationDebtTitle': {
      'TR': 'Telafi Borcu Hatırlatması',
      'EN': 'Compensation Debt Reminder',
      'DE': 'Erinnerung an Ausgleichsschuld',
    },
    'notifications.compensationDebtBody': {
      'TR':
          'Henüz telafi edilmemiş bir dinlenme borcunuz var. Detaylar için Panel\'e bakın.',
      'EN':
          'You have an outstanding rest compensation debt. See the Dashboard for details.',
      'DE':
          'Sie haben eine noch nicht ausgeglichene Ruhezeitschuld. Details im Dashboard.',
    },

    'role.viewAs': {'TR': 'Görünüm Rolü', 'EN': 'View As', 'DE': 'Ansicht als'},
    'role.viewAsDesc': {
      'TR':
          'Verileri hangi rolün yetkisiyle görüntülediğinizi seçin. Bu bir simülasyondur, gerçek kimlik doğrulama değildir.',
      'EN':
          'Choose which role\'s authority you are viewing the data with. This is a simulation, not real authentication.',
      'DE':
          'Wählen Sie, mit welcher Rolle Sie die Daten betrachten. Dies ist eine Simulation, keine echte Authentifizierung.',
    },
    'role.driver': {'TR': 'Sürücü', 'EN': 'Driver', 'DE': 'Fahrer'},
    'role.company': {'TR': 'Şirket', 'EN': 'Company', 'DE': 'Unternehmen'},
    'role.police': {'TR': 'Polis', 'EN': 'Police', 'DE': 'Polizei'},

    'ddd.filesTitle': {
      'TR': '.ddd Dosyaları',
      'EN': '.ddd Files',
      'DE': '.ddd-Dateien',
    },
    'ddd.filesEmpty': {
      'TR':
          'Henüz indirilmiş bir dosya yok. Bir kart takıldığında otomatik olarak indirilir.',
      'EN':
          'No files downloaded yet. One is downloaded automatically when a card is inserted.',
      'DE':
          'Noch keine Dateien heruntergeladen. Beim Einstecken einer Karte wird automatisch eine heruntergeladen.',
    },
    'ddd.fetchRealData': {
      'TR': '.ddd Verisi Al',
      'EN': 'Get .ddd Data',
      'DE': '.ddd-Daten abrufen',
    },
    'ddd.fetchSampleData': {
      'TR': 'Örnek .ddd Verisi Al',
      'EN': 'Get Sample .ddd Data',
      'DE': 'Beispiel-.ddd-Daten abrufen',
    },
    'ddd.connectingStatus': {
      'TR': 'Cihaza bağlanılıyor...',
      'EN': 'Connecting to device...',
      'DE': 'Verbindung zum Gerät wird hergestellt...',
    },
    'ddd.receivingDataStatus': {
      'TR': 'Veri alınıyor...',
      'EN': 'Receiving data...',
      'DE': 'Daten werden empfangen...',
    },
    'ddd.samplePairSuccess': {
      'TR': '2 dosya alındı: kart ve takograf verisi.',
      'EN': '2 files received: card and vehicle-unit data.',
      'DE': '2 Dateien empfangen: Karten- und Fahrzeugeinheitsdaten.',
    },
    'ddd.cardOnlySuccess': {
      'TR': 'Kart verisi alındı.',
      'EN': 'Card data received.',
      'DE': 'Kartendaten empfangen.',
    },
    'ddd.vehicleUnitOnlySuccess': {
      'TR': 'Takograf verisi alındı.',
      'EN': 'Vehicle-unit data received.',
      'DE': 'Fahrzeugeinheitsdaten empfangen.',
    },
    'ddd.fetchChooserTitle': {
      'TR': 'Ne indirmek istiyorsunuz?',
      'EN': 'What would you like to fetch?',
      'DE': 'Was möchten Sie abrufen?',
    },
    'ddd.fetchCardOption': {
      'TR': 'Kart Verisi',
      'EN': 'Card Data',
      'DE': 'Kartendaten',
    },
    'ddd.fetchCardOptionDesc': {
      'TR': 'Sürücü kartındaki sürüş geçmişi',
      'EN': 'Driving history stored on the driver card',
      'DE': 'Fahrverlauf auf der Fahrerkarte',
    },
    'ddd.fetchVehicleUnitOption': {
      'TR': 'Takograf Verisi',
      'EN': 'Vehicle-Unit Data',
      'DE': 'Fahrzeugeinheitsdaten',
    },
    'ddd.fetchVehicleUnitOptionDesc': {
      'TR': 'Aracın takograf ünitesindeki kayıt',
      'EN': 'Record stored on the vehicle\'s tachograph unit',
      'DE': 'Aufzeichnung der Fahrzeugeinheit',
    },
    'ddd.fetchBothOption': {
      'TR': 'Kart + Takograf Verisi',
      'EN': 'Card + Vehicle-Unit Data',
      'DE': 'Karten- + Fahrzeugeinheitsdaten',
    },
    'ddd.fetchBothOptionDesc': {
      'TR': 'İkisini birden al',
      'EN': 'Fetch both at once',
      'DE': 'Beide auf einmal abrufen',
    },
    'ddd.dongleNotPaired': {
      'TR':
          'Eşleştirilmiş STC dongle’ı bulunamadı. Önce telefonun Bluetooth ayarlarından eşleştirin.',
      'EN':
          'No paired STC dongle was found. Pair it in the phone’s Bluetooth settings first.',
      'DE':
          'Kein gekoppelter STC-Dongle gefunden. Koppeln Sie ihn zuerst in den Bluetooth-Einstellungen des Telefons.',
    },
    'ddd.bluetoothPermissionRequired': {
      'TR': 'İndirmek için Bluetooth ve yakındaki cihazlar izni gerekli.',
      'EN': 'Bluetooth and nearby devices permission is required to download.',
      'DE':
          'Zum Herunterladen sind Bluetooth- und Geräte-in-der-Nähe-Berechtigungen erforderlich.',
    },
    'ddd.downloadNoData': {
      'TR': 'Takograf seçilen veri için dosya göndermedi.',
      'EN': 'The tachograph did not send a file for the selected data.',
      'DE':
          'Der Tachograph hat für die ausgewählten Daten keine Datei gesendet.',
    },
    'ddd.downloadFailed': {
      'TR': 'Dongle üzerinden indirme başarısız: {error}',
      'EN': 'Dongle download failed: {error}',
      'DE': 'Download über den Dongle fehlgeschlagen: {error}',
    },
    'ddd.cardBadge': {
      'TR': 'CARD DOWNLOAD',
      'EN': 'CARD DOWNLOAD',
      'DE': 'CARD DOWNLOAD',
    },
    'ddd.vehicleUnitBadge': {
      'TR': 'VU DOWNLOAD',
      'EN': 'VU DOWNLOAD',
      'DE': 'VU DOWNLOAD',
    },
    'ddd.bothBadge': {
      'TR': 'VU + CARD DOWNLOAD',
      'EN': 'VU + CARD DOWNLOAD',
      'DE': 'VU + CARD DOWNLOAD',
    },
    'ddd.driveUploading': {
      'TR': 'Drive\'a yükleniyor...',
      'EN': 'Uploading to Drive...',
      'DE': 'Wird zu Drive hochgeladen...',
    },
    'ddd.driveConnect': {
      'TR': 'Google Hesabını Bağla',
      'EN': 'Connect Google Account',
      'DE': 'Google-Konto verbinden',
    },
    'ddd.driveDisconnect': {
      'TR': 'Bağlantıyı Kaldır',
      'EN': 'Disconnect',
      'DE': 'Verbindung trennen',
    },
    'ddd.driveConnectError': {
      'TR': 'Google hesabı bağlanamadı.',
      'EN': 'Could not connect the Google account.',
      'DE': 'Das Google-Konto konnte nicht verbunden werden.',
    },
    'ddd.driveBackupSuccess': {
      'TR': 'Google Drive\'a yedeklendi.',
      'EN': 'Backed up to Google Drive.',
      'DE': 'In Google Drive gesichert.',
    },
    'ddd.driveBackupError': {
      'TR': 'Google Drive\'a yedeklenemedi.',
      'EN': 'Could not back up to Google Drive.',
      'DE': 'Sicherung in Google Drive fehlgeschlagen.',
    },
    'ddd.cardType': {'TR': 'Kart Türü', 'EN': 'Card Type', 'DE': 'Kartentyp'},
    'ddd.simulatedBadge': {
      'TR': 'Simüle Edildi',
      'EN': 'Simulated',
      'DE': 'Simuliert',
    },
    'ddd.detailTitle': {
      'TR': 'Dosya Detayı',
      'EN': 'File Detail',
      'DE': 'Dateidetail',
    },
    'ddd.cardHolder': {
      'TR': 'Kart Sahibi',
      'EN': 'Card Holder',
      'DE': 'Karteninhaber',
    },
    'ddd.cardNumber': {
      'TR': 'Kart No',
      'EN': 'Card Number',
      'DE': 'Kartennummer',
    },
    'ddd.issuingState': {
      'TR': 'Düzenleyen Ülke',
      'EN': 'Issuing State',
      'DE': 'Ausstellerstaat',
    },
    'ddd.expiryDate': {
      'TR': 'Son Geçerlilik',
      'EN': 'Expiry Date',
      'DE': 'Ablaufdatum',
    },
    'ddd.activityLog': {
      'TR': 'Aktivite Kaydı',
      'EN': 'Activity Log',
      'DE': 'Aktivitätsprotokoll',
    },
    'ddd.manualEntryBadge': {'TR': 'Manuel', 'EN': 'Manual', 'DE': 'Manuell'},
    'ddd.violations': {'TR': 'İhlaller', 'EN': 'Violations', 'DE': 'Verstöße'},
    'ddd.noViolations': {
      'TR': 'Tespit edilen ihlal yok.',
      'EN': 'No violations detected.',
      'DE': 'Keine Verstöße festgestellt.',
    },
    'ddd.exportPdf': {
      'TR': 'PDF Dışa Aktar',
      'EN': 'Export PDF',
      'DE': 'PDF exportieren',
    },
    'ddd.exporting': {
      'TR': 'Dışa aktarılıyor...',
      'EN': 'Exporting...',
      'DE': 'Wird exportiert...',
    },
    'ddd.exportSuccess': {
      'TR': 'PDF başarıyla oluşturuldu.',
      'EN': 'PDF exported successfully.',
      'DE': 'PDF erfolgreich exportiert.',
    },
    'ddd.exportError': {
      'TR': 'PDF oluşturulurken hata oluştu.',
      'EN': 'An error occurred while exporting the PDF.',
      'DE': 'Beim Exportieren des PDFs ist ein Fehler aufgetreten.',
    },

    'ddd.vuHeader': {
      'TR': 'Araç Birimi Verisi',
      'EN': 'Vehicle-Unit Data',
      'DE': 'Fahrzeugeinheitsdaten',
    },
    'ddd.vuHeaderDesc': {
      'TR':
          'Bu, sürücü kartından değil aracın takograf ünitesinden alınan bir indirmedir. Aşağıdaki bilgiler dosyada bulunan ham metinlerden çıkarılmıştır; eksiksiz olmayabilir.',
      'EN':
          'This download came from the vehicle\'s tachograph unit, not a driver card. The fields below were extracted from raw text found in the file and may be incomplete.',
      'DE':
          'Dieser Download stammt von der Fahrzeugeinheit, nicht von einer Fahrerkarte. Die folgenden Felder wurden aus im File gefundenem Rohtext extrahiert und können unvollständig sein.',
    },
    'ddd.vin': {
      'TR': 'Şasi No (VIN)',
      'EN': 'VIN',
      'DE': 'Fahrgestellnummer (VIN)',
    },
    'ddd.vehicleReg': {
      'TR': 'Plaka',
      'EN': 'Registration Number',
      'DE': 'Kennzeichen',
    },
    'ddd.vuCurrentDateTime': {
      'TR': 'Takoğrafın Kendi Saati',
      'EN': "Tachograph's Own Clock",
      'DE': 'Eigene Uhrzeit des Tachographen',
    },
    'ddd.vuDownloadablePeriod': {
      'TR': 'İndirilebilir Aralık',
      'EN': 'Downloadable Period',
      'DE': 'Herunterladbarer Zeitraum',
    },
    'ddd.vuIdentificationTexts': {
      'TR': 'Bulunan Kimlik Bilgileri',
      'EN': 'Identification Info Found',
      'DE': 'Gefundene Identifikationsdaten',
    },
    'ddd.vuIdentificationTextsHint': {
      'TR':
          'Dosyada okunan tüm metin alanları. Hangi kayda ait olduğu bilinenlerin yanında bir etiket var (ör. Atölye Kaydı, Sürücü Kartı); etiketsiz olanların kesin hangi kayda ait olduğu bilinmiyor. Bir isim ve sonunda bir referans/seri numarası aynı alanda birlikte gelmiş olabilir.',
      'EN':
          'Every text field read from the file. Ones matched to a known record show a tag (e.g. Workshop Record, Driver Card); untagged ones have no confirmed record. A name and a trailing reference/serial number may be packed into the same field.',
      'DE':
          'Alle aus der Datei gelesenen Textfelder. Bekannten Datensätzen zugeordnete Felder zeigen ein Tag (z. B. Werkstatteintrag, Fahrerkarte); nicht getaggte Felder haben keinen bestätigten Datensatz. Ein Name und eine nachgestellte Referenz-/Seriennummer können im selben Feld stehen.',
    },
    'ddd.vuNoData': {
      'TR': 'Bu dosyada okunabilir bir kimlik bilgisi bulunamadı.',
      'EN': 'No readable identification info was found in this file.',
      'DE':
          'In dieser Datei wurden keine lesbaren Identifikationsdaten gefunden.',
    },
    'ddd.vuSpeedSessions': {
      'TR': 'Sürüş Oturumları (Hız Kaydı)',
      'EN': 'Driving Sessions (Speed Log)',
      'DE': 'Fahrsitzungen (Geschwindigkeitsprotokoll)',
    },
    'ddd.vuNoSpeedSessions': {
      'TR': 'Bu dosyada hız kaydı bulunamadı.',
      'EN': 'No speed log found in this file.',
      'DE': 'In dieser Datei wurde kein Geschwindigkeitsprotokoll gefunden.',
    },
    'ddd.vuSpeedSessionsTotal': {
      'TR': 'Toplam {hours} saatlik gerçek sürüş verisi bulundu.',
      'EN': 'Found {hours} hours of real driving data.',
      'DE': '{hours} Stunden echte Fahrdaten gefunden.',
    },
    'ddd.minutesShort': {'TR': 'dk', 'EN': 'min', 'DE': 'Min.'},
    'ddd.maxSpeed': {
      'TR': 'Maks. Hız',
      'EN': 'Max Speed',
      'DE': 'Höchstgeschwindigkeit',
    },
    'ddd.vuDailyActivity': {
      'TR': 'Günlük Aktivite (Araç Birimi)',
      'EN': 'Daily Activity (Vehicle Unit)',
      'DE': 'Tagesaktivität (Fahrzeugeinheit)',
    },
    'ddd.vuNoDailyActivity': {
      'TR': 'Bu dosyada günlük aktivite kaydı bulunamadı.',
      'EN': 'No daily activity records found in this file.',
      'DE': 'In dieser Datei wurden keine täglichen Aktivitätsdaten gefunden.',
    },
    'ddd.vuNoCardSessions': {
      'TR': 'Bu gün kart takılıp çıkarılmamış.',
      'EN': 'No card was inserted/withdrawn this day.',
      'DE': 'An diesem Tag wurde keine Karte eingesteckt/entnommen.',
    },
    'ddd.cardTypeDriver': {
      'TR': 'Sürücü Kartı',
      'EN': 'Driver Card',
      'DE': 'Fahrerkarte',
    },
    'ddd.cardTypeWorkshop': {
      'TR': 'Atölye Kartı',
      'EN': 'Workshop Card',
      'DE': 'Werkstattkarte',
    },
    'ddd.cardTypeControl': {
      'TR': 'Kontrol Kartı',
      'EN': 'Control Card',
      'DE': 'Kontrollkarte',
    },
    'ddd.cardTypeCompany': {
      'TR': 'Şirket Kartı',
      'EN': 'Company Card',
      'DE': 'Unternehmenskarte',
    },
    'ddd.cardTypeManufacturer': {
      'TR': 'Üretici Kartı',
      'EN': 'Manufacturer Card',
      'DE': 'Herstellerkarte',
    },
    'ddd.cardTypeUnknown': {
      'TR': 'Bilinmeyen Kart',
      'EN': 'Unknown Card',
      'DE': 'Unbekannte Karte',
    },
    'ddd.identitySourceManufacturer': {
      'TR': 'Üretici Bilgisi',
      'EN': 'Manufacturer Info',
      'DE': 'Herstellerangabe',
    },
    'ddd.identitySourceWorkshop': {
      'TR': 'Atölye Kaydı',
      'EN': 'Workshop Record',
      'DE': 'Werkstatteintrag',
    },
    'ddd.vuEventsAndFaults': {
      'TR': 'Olaylar ve Arızalar',
      'EN': 'Events and Faults',
      'DE': 'Ereignisse und Störungen',
    },
    'ddd.eventFrequencyTitle': {
      'TR': 'Türe Göre Sıklık',
      'EN': 'Frequency by Type',
      'DE': 'Häufigkeit nach Typ',
    },
    'ddd.vuNoEventsAndFaults': {
      'TR': 'Kayıtlı olay veya arıza bulunamadı.',
      'EN': 'No recorded events or faults found.',
      'DE': 'Keine aufgezeichneten Ereignisse oder Störungen gefunden.',
    },
    'ddd.vuOverspeeding': {
      'TR': 'Hız Aşımı Kayıtları',
      'EN': 'Overspeeding Records',
      'DE': 'Geschwindigkeitsüberschreitungen',
    },
    'ddd.vuNoOverspeeding': {
      'TR': 'Kayıtlı hız aşımı bulunamadı.',
      'EN': 'No recorded overspeeding found.',
      'DE': 'Keine aufgezeichneten Geschwindigkeitsüberschreitungen gefunden.',
    },
    'ddd.vuCalibration': {
      'TR': 'Kalibrasyon Geçmişi',
      'EN': 'Calibration History',
      'DE': 'Kalibrierungsverlauf',
    },
    'ddd.vuNoCalibration': {
      'TR': 'Kayıtlı kalibrasyon bulunamadı.',
      'EN': 'No recorded calibration found.',
      'DE': 'Keine aufgezeichnete Kalibrierung gefunden.',
    },
    'ddd.authorisedSpeed': {
      'TR': 'İzin Verilen Hız',
      'EN': 'Authorised Speed',
      'DE': 'Zulässige Geschwindigkeit',
    },
    'ddd.odometer': {
      'TR': 'Kilometre',
      'EN': 'Odometer',
      'DE': 'Kilometerstand',
    },
    'ddd.nextCalibration': {
      'TR': 'Sonraki Kalibrasyon',
      'EN': 'Next Calibration',
      'DE': 'Nächste Kalibrierung',
    },
    'ddd.vuTechnicalData': {
      'TR': 'Teknik Veri',
      'EN': 'Technical Data',
      'DE': 'Technische Daten',
    },
    'ddd.vuTechnicalDataVu': {
      'TR': 'Takograf Ünitesi',
      'EN': 'Vehicle Unit',
      'DE': 'Fahrzeugeinheit',
    },
    'ddd.vuTechnicalDataSensor': {
      'TR': 'Hareket Sensörü',
      'EN': 'Motion Sensor',
      'DE': 'Bewegungssensor',
    },
    'ddd.vuManufacturerName': {
      'TR': 'Üretici',
      'EN': 'Manufacturer',
      'DE': 'Hersteller',
    },
    'ddd.vuManufacturerAddress': {
      'TR': 'Üretici Adresi',
      'EN': 'Manufacturer Address',
      'DE': 'Herstelleradresse',
    },
    'ddd.vuPartNumber': {
      'TR': 'Parça No',
      'EN': 'Part Number',
      'DE': 'Teilenummer',
    },
    'ddd.vuSerialNumber': {
      'TR': 'Seri No',
      'EN': 'Serial Number',
      'DE': 'Seriennummer',
    },
    'ddd.vuSoftwareVersion': {
      'TR': 'Yazılım Sürümü',
      'EN': 'Software Version',
      'DE': 'Softwareversion',
    },
    'ddd.vuManufacturingDate': {
      'TR': 'Üretim Tarihi',
      'EN': 'Manufacturing Date',
      'DE': 'Herstellungsdatum',
    },
    'ddd.vuApprovalNumber': {
      'TR': 'Onay No',
      'EN': 'Approval Number',
      'DE': 'Genehmigungsnummer',
    },
    'ddd.vuSensorSerialNumber': {
      'TR': 'Sensör Seri No',
      'EN': 'Sensor Serial Number',
      'DE': 'Sensor-Seriennummer',
    },
    'ddd.vuSensorApprovalNumber': {
      'TR': 'Sensör Onay No',
      'EN': 'Sensor Approval Number',
      'DE': 'Sensor-Genehmigungsnummer',
    },
    'ddd.vuSensorPairingDate': {
      'TR': 'İlk Eşleştirme Tarihi',
      'EN': 'First Pairing Date',
      'DE': 'Erstes Kopplungsdatum',
    },

    'ddd.licenceAndUsage': {
      'TR': 'Ehliyet ve Kullanım Bilgisi',
      'EN': 'Licence & Usage Info',
      'DE': 'Führerschein- & Nutzungsdaten',
    },
    'ddd.drivingLicenceAuthority': {
      'TR': 'Ehliyet Veren Makam',
      'EN': 'Licence Issuing Authority',
      'DE': 'Ausstellende Führerscheinbehörde',
    },
    'ddd.lastDownloadDate': {
      'TR': 'Son İndirme Tarihi',
      'EN': 'Last Download Date',
      'DE': 'Letztes Download-Datum',
    },
    'ddd.currentUsageSession': {
      'TR': 'Oturum Açılışı',
      'EN': 'Session Opened',
      'DE': 'Sitzung geöffnet',
    },
    'ddd.currentUsageVehicle': {
      'TR': 'Kullanımdaki Araç',
      'EN': 'Vehicle In Use',
      'DE': 'Verwendetes Fahrzeug',
    },
    'ddd.vehiclesUsed': {
      'TR': 'Kullanılan Araçlar',
      'EN': 'Vehicles Used',
      'DE': 'Verwendete Fahrzeuge',
    },
    'ddd.noVehiclesUsed': {
      'TR': 'Kayıtlı araç kullanım geçmişi bulunamadı.',
      'EN': 'No vehicle usage history recorded.',
      'DE': 'Kein Fahrzeugnutzungsverlauf erfasst.',
    },
    'ddd.stillInUse': {
      'TR': 'kullanımda',
      'EN': 'still in use',
      'DE': 'noch in Verwendung',
    },
    'ddd.lastControl': {
      'TR': 'Son Yol Kontrolü',
      'EN': 'Last Roadside Control',
      'DE': 'Letzte Straßenkontrolle',
    },
    'ddd.noControlRecord': {
      'TR': 'Bu kart hiç yol kontrolünden geçmemiş.',
      'EN': 'This card has never been through a roadside control.',
      'DE': 'Diese Karte wurde noch nie einer Straßenkontrolle unterzogen.',
    },
    'ddd.controlTime': {
      'TR': 'Kontrol Zamanı',
      'EN': 'Control Time',
      'DE': 'Kontrollzeit',
    },
    'ddd.controlVehicle': {
      'TR': 'Kontrol Aracı',
      'EN': 'Control Vehicle',
      'DE': 'Kontrollfahrzeug',
    },
    'ddd.controlCardNumber': {
      'TR': 'Kontrol Kartı No',
      'EN': 'Control Card No.',
      'DE': 'Kontrollkartennr.',
    },
    'ddd.controlPeriod': {
      'TR': 'İndirme Aralığı',
      'EN': 'Download Period',
      'DE': 'Download-Zeitraum',
    },
    'ddd.places': {
      'TR': 'Konum Kayıtları (Sınır Geçişleri)',
      'EN': 'Place Records (Border Crossings)',
      'DE': 'Ortsangaben (Grenzübertritte)',
    },
    'ddd.noPlaces': {
      'TR': 'Kayıtlı konum girişi bulunamadı.',
      'EN': 'No place entries recorded.',
      'DE': 'Keine Ortsangaben erfasst.',
    },
    'ddd.specificConditions': {
      'TR': 'Özel Durum Kayıtları',
      'EN': 'Specific Condition Records',
      'DE': 'Sonderbedingungen',
    },
    'ddd.noSpecificConditions': {
      'TR': 'Özel durum kaydı yok.',
      'EN': 'No specific condition records.',
      'DE': 'Keine Sonderbedingungen erfasst.',
    },
    'ddd.specificConditionOutOfScopeBegin': {
      'TR': 'Kapsam Dışı Başlangıç',
      'EN': 'Out-of-Scope Begin',
      'DE': 'Beginn außerhalb des Geltungsbereichs',
    },
    'ddd.specificConditionOutOfScopeEnd': {
      'TR': 'Kapsam Dışı Bitiş',
      'EN': 'Out-of-Scope End',
      'DE': 'Ende außerhalb des Geltungsbereichs',
    },
    'ddd.specificConditionFerryTrain': {
      'TR': 'Feribot/Tren Geçişi',
      'EN': 'Ferry/Train Crossing',
      'DE': 'Fähr-/Zugüberfahrt',
    },
    'ddd.specificConditionUnknown': {
      'TR': 'Bilinmeyen ({code})',
      'EN': 'Unknown ({code})',
      'DE': 'Unbekannt ({code})',
    },

    'ddd.select': {'TR': 'Seç', 'EN': 'Select', 'DE': 'Auswählen'},
    'ddd.cancel': {'TR': 'Vazgeç', 'EN': 'Cancel', 'DE': 'Abbrechen'},
    'ddd.delete': {'TR': 'Sil', 'EN': 'Delete', 'DE': 'Löschen'},
    'ddd.deleteConfirmTitle': {
      'TR': 'Dosyaları Sil',
      'EN': 'Delete Files',
      'DE': 'Dateien löschen',
    },
    'ddd.deleteConfirmSingle': {
      'TR':
          'Bu dosyayı silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
      'EN': 'Are you sure you want to delete this file? This cannot be undone.',
      'DE':
          'Möchten Sie diese Datei wirklich löschen? Dies kann nicht rückgängig gemacht werden.',
    },
    'ddd.deleteConfirmMulti': {
      'TR':
          '{count} dosyayı silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
      'EN':
          'Are you sure you want to delete {count} files? This cannot be undone.',
      'DE':
          'Möchten Sie {count} Dateien wirklich löschen? Dies kann nicht rückgängig gemacht werden.',
    },
    'ddd.deleteSuccess': {
      'TR': 'Seçili dosyalar silindi.',
      'EN': 'Selected files deleted.',
      'DE': 'Ausgewählte Dateien gelöscht.',
    },
    'ddd.moveToTrash': {
      'TR': 'Çöp Kutusuna Taşı',
      'EN': 'Move to Trash',
      'DE': 'In den Papierkorb',
    },
    'ddd.share': {'TR': 'Paylaş', 'EN': 'Share', 'DE': 'Teilen'},
    'ddd.shareError': {
      'TR': 'Dosya paylaşılamadı.',
      'EN': 'The file could not be shared.',
      'DE': 'Die Datei konnte nicht geteilt werden.',
    },
    'ddd.availableFiles': {
      'TR': 'Kullanılabilir Dosyalar',
      'EN': 'Available Files',
      'DE': 'Verfügbare Dateien',
    },
    'ddd.sortByDate': {
      'TR': 'Tarihe Göre Sırala',
      'EN': 'Sort by Date',
      'DE': 'Nach Datum sortieren',
    },
    'ddd.instructionText': {
      'TR':
          'Takograftan indirilen .ddd dosyalarınız aşağıda listelenir. Bir dosyaya uzun basarak seçim yapabilir, seçtiğiniz dosyaları paylaşabilir veya çöp kutusuna taşıyabilirsiniz.\n\nNot: Gerçek cihazdan toplu .ddd indirme bu model için henüz deneysel/doğrulanmamıştır ve genelde reddedilir. Böyle bir durumda uygulama otomatik olarak test amaçlı simüle edilmiş bir dosya oluşturur ("Simüle Edildi" etiketiyle işaretlenir).',
      'EN':
          'Your .ddd files downloaded from the tachograph are listed below. Long-press a file to select it, then share or move the selected files to trash.\n\nNote: bulk .ddd download from the real device is still experimental/unverified for this model and will usually be rejected. When that happens, the app automatically creates a simulated file for testing instead (marked "Simulated").',
      'DE':
          'Ihre vom Fahrtenschreiber heruntergeladenen .ddd-Dateien werden unten aufgelistet. Halten Sie eine Datei gedrückt, um sie auszuwählen, und teilen Sie sie oder verschieben Sie sie in den Papierkorb.\n\nHinweis: Die .ddd-Massenübertragung vom echten Gerät ist für dieses Modell noch experimentell/unverifiziert und wird meist abgelehnt. In diesem Fall erstellt die App automatisch eine simulierte Datei zu Testzwecken (gekennzeichnet als "Simuliert").',
    },
    'ddd.selectedStatus': {
      'TR': 'Seçildi',
      'EN': 'Selected',
      'DE': 'Ausgewählt',
    },
    'ddd.selectedCountHeader': {
      'TR': '{count} Seçildi',
      'EN': '{count} Selected',
      'DE': '{count} Ausgewählt',
    },
    'ddd.trash': {'TR': 'Çöp Kutusu', 'EN': 'Trash', 'DE': 'Papierkorb'},
    'ddd.trashTitle': {'TR': 'Çöp Kutusu', 'EN': 'Trash', 'DE': 'Papierkorb'},
    'ddd.trashEmpty': {
      'TR': 'Çöp kutusu boş.',
      'EN': 'Trash is empty.',
      'DE': 'Der Papierkorb ist leer.',
    },
    'ddd.restore': {
      'TR': 'Geri Yükle',
      'EN': 'Restore',
      'DE': 'Wiederherstellen',
    },
    'ddd.restoreSuccess': {
      'TR': 'Dosya geri yüklendi.',
      'EN': 'File restored.',
      'DE': 'Datei wiederhergestellt.',
    },
    'ddd.deletePermanently': {
      'TR': 'Kalıcı Olarak Sil',
      'EN': 'Delete Permanently',
      'DE': 'Endgültig löschen',
    },
    'ddd.deletePermanentlyConfirmSingle': {
      'TR':
          'Bu dosya kalıcı olarak silinecek ve geri getirilemeyecek. Emin misiniz?',
      'EN':
          'This file will be permanently deleted and cannot be recovered. Are you sure?',
      'DE':
          'Diese Datei wird endgültig gelöscht und kann nicht wiederhergestellt werden. Sind Sie sicher?',
    },
    'ddd.deleteAll': {
      'TR': 'Hepsini Sil',
      'EN': 'Delete All',
      'DE': 'Alle löschen',
    },
    'ddd.deletePermanentlyConfirmAll': {
      'TR':
          'Çöp kutusundaki {count} dosyanın tamamı kalıcı olarak silinecek ve geri getirilemeyecek. Emin misiniz?',
      'EN':
          'All {count} files in the trash will be permanently deleted and cannot be recovered. Are you sure?',
      'DE':
          'Alle {count} Dateien im Papierkorb werden endgültig gelöscht und können nicht wiederhergestellt werden. Sind Sie sicher?',
    },
    'ddd.trashedAt': {'TR': 'Silinme', 'EN': 'Deleted', 'DE': 'Gelöscht'},

    'ddd.dateOfBirth': {
      'TR': 'Doğum Tarihi',
      'EN': 'Date of Birth',
      'DE': 'Geburtsdatum',
    },
    'ddd.language': {'TR': 'Dil', 'EN': 'Language', 'DE': 'Sprache'},
    'ddd.licenseNumber': {
      'TR': 'Ehliyet No',
      'EN': 'License No.',
      'DE': 'Führerscheinnr.',
    },
    'ddd.cardIssueDate': {
      'TR': 'Kart Başlangıç',
      'EN': 'Card Issued',
      'DE': 'Karte ausgestellt',
    },

    'ddd.eventsAndFaults': {
      'TR': 'Olaylar ve Hatalar',
      'EN': 'Events & Faults',
      'DE': 'Ereignisse & Fehler',
    },
    'ddd.noEvents': {
      'TR': 'Kayıtlı olay veya hata yok.',
      'EN': 'No recorded events or faults.',
      'DE': 'Keine erfassten Ereignisse oder Fehler.',
    },
    'ddd.faultBadge': {'TR': 'Arıza', 'EN': 'Fault', 'DE': 'Fehler'},
    'ddd.eventBadge': {'TR': 'Olay', 'EN': 'Event', 'DE': 'Ereignis'},
    'ddd.eventsSubheader': {
      'TR': 'Olaylar',
      'EN': 'Events',
      'DE': 'Ereignisse',
    },
    'ddd.faultsSubheader': {'TR': 'Arızalar', 'EN': 'Faults', 'DE': 'Fehler'},

    'ddd.crewBadge': {'TR': 'Ekip', 'EN': 'Crew', 'DE': 'Team'},
    'ddd.soloBadge': {'TR': 'Tekil', 'EN': 'Solo', 'DE': 'Einzeln'},
    'ddd.slotDriver': {'TR': 'Sürücü', 'EN': 'Driver', 'DE': 'Fahrer'},
    'ddd.slotCoDriver': {
      'TR': 'Yardımcı Sürücü',
      'EN': 'Co-Driver',
      'DE': 'Beifahrer',
    },

    'gap.title': {
      'TR': 'Eksik Zaman Tespit Edildi',
      'EN': 'Missing Time Detected',
      'DE': 'Fehlende Zeit erkannt',
    },
    'gap.message': {
      'TR': 'Bu aralıkta bir kayıt bulunamadı. O sırada ne yapıyordunuz?',
      'EN':
          'No record was found for this time range. What were you doing then?',
      'DE':
          'Für diesen Zeitraum wurde kein Eintrag gefunden. Was haben Sie in dieser Zeit gemacht?',
    },
    'gap.selectActivity': {
      'TR': 'Aktivite Seçin',
      'EN': 'Select Activity',
      'DE': 'Aktivität auswählen',
    },
    'gap.splitHint': {
      'TR':
          'Bu sürede farklı şeyler yaptıysanız aralığı bölün ve her parçaya kendi aktivitesini seçin. Parçaların sınırını değiştirmek için tarih ve saate dokunun.',
      'EN':
          'If you did different things during this time, split the range and choose an activity for each part. Tap a date and time to move the boundary between parts.',
      'DE':
          'Wenn Sie in dieser Zeit Verschiedenes gemacht haben, teilen Sie den Zeitraum und wählen Sie für jeden Teil eine Aktivität. Tippen Sie auf Datum und Uhrzeit, um die Grenze zwischen den Teilen zu verschieben.',
    },
    'gap.split': {
      'TR': 'Aralığı böl',
      'EN': 'Split range',
      'DE': 'Zeitraum teilen',
    },
    'gap.removePart': {
      'TR': 'Bu parçayı kaldır',
      'EN': 'Remove this part',
      'DE': 'Diesen Teil entfernen',
    },
    'gap.save': {'TR': 'Kaydet', 'EN': 'Save', 'DE': 'Speichern'},
    'gap.chooseEach': {
      'TR': 'Her parça için bir aktivite seçin.',
      'EN': 'Choose an activity for each part.',
      'DE': 'Wählen Sie für jeden Teil eine Aktivität.',
    },
    'gap.outOfRange': {
      'TR': 'Sınır {from} ile {to} arasında olmalı.',
      'EN': 'The boundary has to fall between {from} and {to}.',
      'DE': 'Die Grenze muss zwischen {from} und {to} liegen.',
    },
    'gap.duration': {
      'TR': '{h} sa {m} dk',
      'EN': '{h} h {m} min',
      'DE': '{h} Std. {m} Min.',
    },
    'gap.progress': {
      'TR': 'Kayıtsız aralık {n} / {total}',
      'EN': 'Unrecorded range {n} of {total}',
      'DE': 'Zeitraum ohne Aufzeichnung {n} von {total}',
    },

    'violation.continuousDrivingExceeded': {
      'TR': 'Sürekli sürüş limiti aşıldı (4s 30d)',
      'EN': 'Continuous driving limit exceeded (4h 30m)',
      'DE': 'Dauerlenkzeit überschritten (4Std 30Min)',
    },
    'violation.dailyDrivingExceeded': {
      'TR': 'Günlük sürüş limiti aşıldı (9 saat)',
      'EN': 'Daily driving limit exceeded (9 hours)',
      'DE': 'Tageslenkzeit überschritten (9 Stunden)',
    },
    'violation.weeklyDrivingExceeded': {
      'TR': 'Haftalık sürüş limiti aşıldı (56 saat)',
      'EN': 'Weekly driving limit exceeded (56 hours)',
      'DE': 'Wochenlenkzeit überschritten (56 Stunden)',
    },
    'violation.biWeeklyDrivingExceeded': {
      'TR': 'İki haftalık sürüş limiti aşıldı (90 saat)',
      'EN': 'Bi-weekly driving limit exceeded (90 hours)',
      'DE': 'Zweiwöchentliche Lenkzeit überschritten (90 Stunden)',
    },
    'violation.dailyRestInsufficient': {
      'TR': 'Günlük dinlenme süresi yetersiz',
      'EN': 'Insufficient daily rest period',
      'DE': 'Unzureichende tägliche Ruhezeit',
    },
    'violation.weeklyRestInsufficient': {
      'TR': 'Haftalık dinlenme süresi yetersiz',
      'EN': 'Insufficient weekly rest period',
      'DE': 'Unzureichende wöchentliche Ruhezeit',
    },
    'violation.dailyDrivingExceededExtended': {
      'TR': 'Uzatmalı günlük sürüş limiti aşıldı (10 saat)',
      'EN': 'Extended daily driving limit exceeded (10 hours)',
      'DE': 'Verlängerte Tageslenkzeit überschritten (10 Stunden)',
    },
    'violation.weeklyRestDelayed': {
      'TR': 'Haftalık dinlenme geç başladı (6×24 saat aşıldı)',
      'EN': 'Weekly rest started late (after six 24-hour periods)',
      'DE': 'Wöchentliche Ruhezeit zu spät begonnen (nach 6×24 Stunden)',
    },
    'violation.weeklyRestNotRegular': {
      'TR':
          'Üst üste ikinci indirgenmiş haftalık dinlenme (45 saat gerekiyordu)',
      'EN': 'Second reduced weekly rest in a row (45 hours were due)',
      'DE': 'Zweite reduzierte Wochenruhezeit in Folge (45 Stunden fällig)',
    },
    'violation.missingRecord': {
      'TR': 'Kayıtsız zaman aralığı',
      'EN': 'Unrecorded time range',
      'DE': 'Nicht erfasster Zeitraum',
    },
    'violation.severityViolation': {
      'TR': 'İhlal',
      'EN': 'Violation',
      'DE': 'Verstoß',
    },

    'nav.analysis': {'TR': 'Analiz', 'EN': 'Analysis', 'DE': 'Analyse'},
    'analysis.pageTitle': {'TR': 'Analiz', 'EN': 'Analysis', 'DE': 'Analyse'},
    'analysis.driverLabel': {'TR': 'Sürücü', 'EN': 'Driver', 'DE': 'Fahrer'},
    'analysis.vehicleLabel': {'TR': 'Araç', 'EN': 'Vehicle', 'DE': 'Fahrzeug'},
    'analysis.riskScoreLabel': {
      'TR': 'Uyum Risk Skoru',
      'EN': 'Compliance Risk Score',
      'DE': 'Compliance-Risikowert',
    },
    'analysis.riskLevelLow': {
      'TR': 'Düşük Risk',
      'EN': 'Low Risk',
      'DE': 'Geringes Risiko',
    },
    'analysis.riskLevelMedium': {
      'TR': 'Orta Seviye Risk',
      'EN': 'Medium Risk',
      'DE': 'Mittleres Risiko',
    },
    'analysis.riskLevelHigh': {
      'TR': 'Yüksek Risk',
      'EN': 'High Risk',
      'DE': 'Hohes Risiko',
    },
    'analysis.riskSummary': {
      'TR':
          'Son 28 günlük sürüş verilerinize göre uyumluluk puanınız {count} ihlalden hesaplandı.',
      'EN':
          'Your compliance score was calculated from {count} violations in your last 28 days of driving data.',
      'DE':
          'Ihr Compliance-Wert wurde aus {count} Verstößen in Ihren Fahrdaten der letzten 28 Tage berechnet.',
    },
    'analysis.riskSummaryClean': {
      'TR':
          'Son 28 günde tespit edilen bir ihlal yok — uyumluluk puanınız tam.',
      'EN':
          'No violations detected in the last 28 days — your compliance score is perfect.',
      'DE':
          'In den letzten 28 Tagen wurden keine Verstöße festgestellt — Ihr Compliance-Wert ist perfekt.',
    },
    'analysis.penaltyExposureLabel': {
      'TR': 'Tahmini Ceza Tutarı',
      'EN': 'Estimated Penalty Exposure',
      'DE': 'Geschätztes Bußgeldrisiko',
    },
    'analysis.penaltyExposureTrend': {
      'TR': 'Son 4 haftanın gerçek ihlal verilerine göre haftalık dağılım.',
      'EN':
          'Weekly breakdown based on real violation data from the last 4 weeks.',
      'DE':
          'Wöchentliche Aufschlüsselung basierend auf echten Verstoßdaten der letzten 4 Wochen.',
    },
    'analysis.penaltyBreakdownLabel': {
      'TR': 'İhlal Türüne Göre Sıralama',
      'EN': 'Ranked by Violation Type',
      'DE': 'Rangfolge nach Verstoßart',
    },
    'analysis.companyMultiplierFootnote': {
      'TR':
          'İşleten cezaları tescil plakası üzerinden bu tutarların 2 katıdır.',
      'EN':
          'Company/operator fines are double these amounts, applied per vehicle registration.',
      'DE':
          'Bußgelder für den Halter/Betreiber sind doppelt so hoch, angewendet pro Fahrzeugkennzeichen.',
    },
    'analysis.missingRecordNotFine': {
      'TR': 'Gerçek bir ceza maddesi değil',
      'EN': 'Not a real fine category',
      'DE': 'Keine reale Bußgeldkategorie',
    },
    'analysis.remainingDriving': {
      'TR': 'Kalan Sürüş',
      'EN': 'Remaining Driving',
      'DE': 'Verbleibende Fahrzeit',
    },
    'analysis.activityTimelineLabel': {
      'TR': 'Aktivite Zaman Çizelgesi',
      'EN': 'Activity Timeline',
      'DE': 'Aktivitätszeitleiste',
    },
    'analysis.trend28DaysLabel': {
      'TR': 'SON 28 GÜN TRENDİ',
      'EN': '28-DAY TREND',
      'DE': '28-TAGE-TREND',
    },
    'analysis.routeMapLabel': {
      'TR': 'Rota Haritası',
      'EN': 'Route Map',
      'DE': 'Streckenkarte',
    },
    'analysis.routeMapNote': {
      'TR':
          'Gerçek GPS ile kaydedilir — .ddd dosyalarında konum verisi bulunmaz.',
      'EN': 'Recorded via real GPS — .ddd files carry no location data.',
      'DE':
          'Aufgezeichnet über echtes GPS — .ddd-Dateien enthalten keine Standortdaten.',
    },
    'analysis.routeMapStart': {
      'TR': 'Takibi Başlat',
      'EN': 'Start Tracking',
      'DE': 'Verfolgung starten',
    },
    'analysis.routeMapStop': {
      'TR': 'Takibi Durdur',
      'EN': 'Stop Tracking',
      'DE': 'Verfolgung stoppen',
    },
    'analysis.routeMapClear': {
      'TR': 'Rotayı Temizle',
      'EN': 'Clear Route',
      'DE': 'Strecke löschen',
    },
    'analysis.routeMapEmpty': {
      'TR':
          'Henüz rota kaydı yok. Sürüşe başlamadan önce "Takibi Başlat"a dokunun.',
      'EN':
          'No route recorded yet. Tap "Start Tracking" before you begin driving.',
      'DE':
          'Noch keine Strecke aufgezeichnet. Tippen Sie vor Fahrtbeginn auf "Verfolgung starten".',
    },
    'analysis.routeMapPermissionDenied': {
      'TR':
          'Konum izni verilmedi. Rota haritasını kullanmak için ayarlardan izin verin.',
      'EN':
          'Location permission was denied. Grant it in settings to use the route map.',
      'DE':
          'Standortberechtigung wurde verweigert. Erteilen Sie sie in den Einstellungen, um die Streckenkarte zu nutzen.',
    },
    'analysis.routeMapServiceDisabled': {
      'TR':
          'Cihazınızda konum servisi kapalı. Rota haritası için açmanız gerekir.',
      'EN':
          'Location services are turned off on this device. Turn them on to use the route map.',
      'DE':
          'Standortdienste sind auf diesem Gerät deaktiviert. Aktivieren Sie sie für die Streckenkarte.',
    },
    'analysis.routeMapRequesting': {
      'TR': 'Konum izni isteniyor…',
      'EN': 'Requesting location permission…',
      'DE': 'Standortberechtigung wird angefordert…',
    },
    'analysis.routeMapError': {
      'TR': 'Konum takibinde bir sorun oluştu.',
      'EN': 'Something went wrong with location tracking.',
      'DE': 'Bei der Standortverfolgung ist ein Fehler aufgetreten.',
    },
    'analysis.thisWeekDrivingLabel': {
      'TR': 'Bu Hafta Sürüş',
      'EN': 'This Week Driving',
      'DE': 'Fahrzeit diese Woche',
    },
    'analysis.thisWeekViolationsLabel': {
      'TR': 'Bu Hafta İhlal',
      'EN': 'This Week Violations',
      'DE': 'Verstöße diese Woche',
    },
    'analysis.violationZone': {
      'TR': 'İhlal Bölgesi',
      'EN': 'Violation Zone',
      'DE': 'Verstoßbereich',
    },
    'analysis.violationsListLabel': {
      'TR': 'Tespit Edilen İhlaller',
      'EN': 'Detected Violations',
      'DE': 'Erkannte Verstöße',
    },
    'analysis.last28Days': {
      'TR': 'Son 28 Gün',
      'EN': 'Last 28 Days',
      'DE': 'Letzte 28 Tage',
    },
    'analysis.estimatedPenalty': {
      'TR': 'Tahmini Ceza',
      'EN': 'Estimated Penalty',
      'DE': 'Geschätztes Bußgeld',
    },
    'analysis.noViolationsInWindow': {
      'TR': 'Son 28 günde tespit edilen ihlal yok.',
      'EN': 'No violations detected in the last 28 days.',
      'DE': 'Keine Verstöße in den letzten 28 Tagen festgestellt.',
    },
    'analysis.viewAllHistory': {
      'TR': 'Tüm Geçmişi Görüntüle',
      'EN': 'View Full History',
      'DE': 'Gesamten Verlauf Anzeigen',
    },
    'analysis.noIssuesThisDay': {
      'TR': 'Sorunsuz',
      'EN': 'No issues',
      'DE': 'Unauffällig',
    },
    'analysis.lockedTitle': {
      'TR': 'Detaylı Analiz Kilidi',
      'EN': 'Detailed Analysis Locked',
      'DE': 'Detailanalyse gesperrt',
    },
    'analysis.lockedMessage': {
      'TR':
          'Haftalık ihlal dökümleri, sürüş takvimi ve detaylı risk raporlarına erişmek için Premium plana geçin.',
      'EN':
          'Upgrade to Premium to access weekly violation breakdowns, the driving calendar, and detailed risk reports.',
      'DE':
          'Wechseln Sie zu Premium, um wöchentliche Verstoßübersichten, den Fahrkalender und detaillierte Risikoberichte zu erhalten.',
    },
    'analysis.featureViolationTracking': {
      'TR': 'Gelişmiş İhlal Takibi',
      'EN': 'Advanced Violation Tracking',
      'DE': 'Erweiterte Verstoßverfolgung',
    },
    'analysis.featureExport': {
      'TR': 'Resmi Belge Dışa Aktarma',
      'EN': 'Official Report Export',
      'DE': 'Export offizieller Berichte',
    },
    'analysis.featurePredictiveAlerts': {
      'TR': 'Prediktif Risk Uyarıları',
      'EN': 'Predictive Risk Alerts',
      'DE': 'Prädiktive Risikowarnungen',
    },
    'analysis.upgradeButton': {
      'TR': 'Premium\'a Geç',
      'EN': 'Upgrade to Premium',
      'DE': 'Auf Premium upgraden',
    },
    'analysis.priceFootnote': {
      'TR': 'Aylık sadece ₺49,99\'dan başlayan fiyatlarla',
      'EN': 'Starting from just ₺49.99/month',
      'DE': 'Ab nur ₺49,99 pro Monat',
    },
    'analysis.previewTogglePremium': {
      'TR': 'Önizleme: Premium',
      'EN': 'Preview: Premium',
      'DE': 'Vorschau: Premium',
    },
    'analysis.previewToggleLocked': {
      'TR': 'Önizleme: Kilitli',
      'EN': 'Preview: Locked',
      'DE': 'Vorschau: Gesperrt',
    },
    'analysis.connectionConnected': {
      'TR': 'Takograf Bağlı',
      'EN': 'Tachograph Connected',
      'DE': 'Fahrtenschreiber verbunden',
    },
    'analysis.connectionDisconnected': {
      'TR': 'Takograf Bağlı Değil',
      'EN': 'Tachograph Not Connected',
      'DE': 'Fahrtenschreiber nicht verbunden',
    },
    'analysis.prevWeek': {'TR': 'Önceki', 'EN': 'Previous', 'DE': 'Zurück'},
    'analysis.nextWeek': {'TR': 'Sonraki', 'EN': 'Next', 'DE': 'Weiter'},
    'analysis.penaltyTrendTitle': {
      'TR': 'Haftalık Ceza Trendi',
      'EN': 'Weekly Penalty Trend',
      'DE': 'Wöchentlicher Bußgeldtrend',
    },
    'analysis.openSeverityListButton': {
      'TR': 'Cezalar ve Ciddiyetleri',
      'EN': 'Penalties & Severities',
      'DE': 'Bußgelder & Schweregrade',
    },
    'analysis.regulationLinkLabel': {
      'TR': 'EC 561/2006 Yönetmeliğine ulaşmak için tıklayınız',
      'EN': 'Click to open EC Regulation 561/2006',
      'DE': 'Klicken Sie hier, um die EG-Verordnung 561/2006 zu öffnen',
    },
    'analysis.notificationsCardTitle': {
      'TR': 'Bildirimleri açın',
      'EN': 'Turn on notifications',
      'DE': 'Benachrichtigungen aktivieren',
    },
    'analysis.notificationsCardSubtitle': {
      'TR': 'Mola süresi ve limit aşımlarında anında sesli uyarı alın',
      'EN': 'Get instant audio alerts on break time and limit overruns',
      'DE':
          'Erhalten Sie sofort akustische Warnungen bei Pausen- und Grenzüberschreitungen',
    },
    'analysis.backupSectionTitle': {
      'TR': 'Verileri Otomatik İndirme ve Yedekleme',
      'EN': 'Automatic Data Download & Backup',
      'DE': 'Automatischer Datendownload & Backup',
    },
    'analysis.backupSectionSubtitle': {
      'TR': 'Mevzuata uygun dijital arşivleme',
      'EN': 'Compliant digital archiving',
      'DE': 'Konforme digitale Archivierung',
    },
    'analysis.autoDddTitle': {
      'TR': 'Otomatik .ddd İndirme',
      'EN': 'Automatic .ddd Download',
      'DE': 'Automatischer .ddd-Download',
    },
    'analysis.autoDddSubtitle': {
      'TR': 'Bağlantı kesilip yeniden bağlanınca kalan dosyaları eşitler.',
      'EN': 'Syncs remaining files when reconnected after a disconnect.',
      'DE':
          'Synchronisiert verbleibende Dateien nach einer erneuten Verbindung.',
    },
    'analysis.googleDriveTitle': {
      'TR': 'Google Drive Yedekleme',
      'EN': 'Google Drive Backup',
      'DE': 'Google Drive-Backup',
    },
    'analysis.googleDriveNotConnected': {
      'TR': 'Bağlı değil',
      'EN': 'Not connected',
      'DE': 'Nicht verbunden',
    },
    'analysis.googleDriveConnected': {
      'TR': 'Bağlandı',
      'EN': 'Connected',
      'DE': 'Verbunden',
    },
    'analysis.googleDriveDescription': {
      'TR':
          'İndirdiğiniz her .ddd dosyasının güvenli bulut yedeği saklanır, veri kaybı riski ortadan kalkar.',
      'EN':
          'A secure cloud backup of every downloaded .ddd file is kept, removing data-loss risk.',
      'DE':
          'Von jeder heruntergeladenen .ddd-Datei wird ein sicheres Cloud-Backup gespeichert, das Risiko von Datenverlust entfällt.',
    },
    'analysis.googleDriveConnectButton': {
      'TR': 'Google Hesabını Bağla',
      'EN': 'Connect Google Account',
      'DE': 'Google-Konto verbinden',
    },
    'analysis.googleDriveDisconnectButton': {
      'TR': 'Bağlantıyı Kes',
      'EN': 'Disconnect',
      'DE': 'Trennen',
    },
    'analysis.insightDetailsButton': {
      'TR': 'Detaylar',
      'EN': 'Details',
      'DE': 'Details',
    },
    'analysis.insightFixPlanButton': {
      'TR': 'Planı Düzelt',
      'EN': 'Fix Plan',
      'DE': 'Plan anpassen',
    },
    'analysis.insightRestIssueTitle': {
      'TR': 'Dinlenme sürenizi genelde aksatıyorsunuz',
      'EN': 'You often fall short on rest time',
      'DE': 'Sie unterschreiten Ihre Ruhezeit häufig',
    },
    'analysis.insightDrivingIssueTitle': {
      'TR': 'Sürüş süresi limitlerini zorluyorsunuz',
      'EN': 'You are pushing driving-time limits',
      'DE': 'Sie reizen die Lenkzeitgrenzen aus',
    },
    'analysis.insightCleanTitle': {
      'TR': 'Bu hafta mevzuata tam uyum sağladınız',
      'EN': 'Full compliance this week',
      'DE': 'Diese Woche vollständige Konformität',
    },
    'analysis.insightAveragePrefix': {'TR': 'Ort', 'EN': 'Avg', 'DE': 'Ø'},
    'analysis.riskGaugeTaglineLow': {
      'TR': 'Kusursuz Mevzuat Uyumu',
      'EN': 'Perfect Regulatory Compliance',
      'DE': 'Perfekte Vorschrifteneinhaltung',
    },
    'analysis.riskGaugeTaglineMedium': {
      'TR': 'Genel Olarak Uyumlu',
      'EN': 'Generally Compliant',
      'DE': 'Im Allgemeinen konform',
    },
    'analysis.riskGaugeTaglineHigh': {
      'TR': 'Yüksek İhlal Riski',
      'EN': 'High Violation Risk',
      'DE': 'Hohes Verstoßrisiko',
    },
    'analysis.violationCountNone': {
      'TR': 'İhlal Yok',
      'EN': 'No Violations',
      'DE': 'Keine Verstöße',
    },
    'analysis.violationCountSuffix': {
      'TR': '{count} İhlal',
      'EN': '{count} Violations',
      'DE': '{count} Verstöße',
    },
    'analysis.googleDriveBackupToggleLabel': {
      'TR': 'Otomatik yedekleme',
      'EN': 'Automatic backup',
      'DE': 'Automatische Sicherung',
    },
    'analysis.penaltyTierUpToOneHour': {
      'TR': '1 saate kadar aşım',
      'EN': 'Exceeded by up to 1 h',
      'DE': 'Bis zu 1 Std. überschritten',
    },
    'analysis.penaltyTierOverOneHour': {
      'TR': '1 saatten fazla aşım',
      'EN': 'Exceeded by more than 1 h',
      'DE': 'Mehr als 1 Std. überschritten',
    },
    'analysis.penaltyTierOneToThreeHours': {
      'TR': '1–3 saat aşım',
      'EN': 'Exceeded by 1–3 h',
      'DE': '1–3 Std. überschritten',
    },
    'analysis.penaltyTierThreeHoursOrMore': {
      'TR': '3 saat ve üzeri aşım',
      'EN': 'Exceeded by 3 h or more',
      'DE': '3 Std. oder mehr überschritten',
    },
    'analysis.penaltyTierUpToFourHours': {
      'TR': '4 saate kadar aşım',
      'EN': 'Exceeded by up to 4 h',
      'DE': 'Bis zu 4 Std. überschritten',
    },
    'analysis.penaltyTierFourToFifteenHours': {
      'TR': '4–15 saat aşım',
      'EN': 'Exceeded by 4–15 h',
      'DE': '4–15 Std. überschritten',
    },
    'analysis.penaltyTierOverFifteenHours': {
      'TR': '15 saat ve üzeri aşım',
      'EN': 'Exceeded by 15 h or more',
      'DE': '15 Std. oder mehr überschritten',
    },
    'analysis.penaltyTierFlatRate': {
      'TR': 'Sabit tutar',
      'EN': 'Flat rate',
      'DE': 'Pauschalbetrag',
    },
    'analysis.insightRestDescription': {
      'TR':
          'Bu hafta {count} kez yetersiz dinlenme tespit edildi; dinlenme ortalama {minutes} dakika kısa kaldı.',
      'EN':
          'Insufficient rest was detected {count} time(s) this week, averaging {minutes} minutes short.',
      'DE':
          'Diese Woche wurde {count} Mal unzureichende Ruhezeit festgestellt, im Schnitt {minutes} Minuten zu kurz.',
    },
    'analysis.insightDrivingDescription': {
      'TR': 'Bu hafta sürüş süresi limitleri {count} kez aşıldı.',
      'EN': 'Driving-time limits were exceeded {count} time(s) this week.',
      'DE': 'Diese Woche wurden die Lenkzeitgrenzen {count} Mal überschritten.',
    },
    'analysis.insightCleanDescription': {
      'TR':
          'Bu hafta hiçbir sürüş veya dinlenme ihlali tespit edilmedi. Böyle devam edin!',
      'EN':
          'No driving or rest violations were detected this week. Keep it up!',
      'DE':
          'Diese Woche wurden keine Lenk- oder Ruhezeitverstöße festgestellt. Weiter so!',
    },
    'analysis.dayFineSummary': {
      'TR': '{count} ihlal · {points} ceza puanı',
      'EN': '{count} violation(s) · {points} penalty points',
      'DE': '{count} Verstoß/Verstöße · {points} Strafpunkte',
    },
    'analysis.notesTitle': {
      'TR': 'Açıklamalar',
      'EN': 'Notes',
      'DE': 'Hinweise',
    },
    'analysis.noteEarlyPaymentTitle': {
      'TR': '%25 erken ödeme indirimi',
      'EN': '25% early-payment discount',
      'DE': '25 % Rabatt bei früher Zahlung',
    },
    'analysis.noteOperatorDoubleTitle': {
      'TR': 'İşletene 2 katı',
      'EN': 'Double for the operator',
      'DE': 'Doppelt für den Halter',
    },
    'analysis.noteOperatorDouble': {
      'TR':
          'Sürücü aracın işleteni değilse işletene ayrıca sürücü cezasının 2 katı kesilir. Sürücü aynı zamanda işletense 2 katı sürücüye uygulanır.',
      'EN':
          'If the driver is not the vehicle operator, the operator is also fined twice the driver amount. If the driver is also the operator, the double amount applies to the driver.',
      'DE':
          'Ist der Fahrer nicht der Halter, erhält der Halter zusätzlich das Doppelte des Fahrerbußgelds. Ist der Fahrer zugleich Halter, gilt der doppelte Betrag für den Fahrer.',
    },
    'analysis.noteOperatorDoubleCompany': {
      'TR':
          'Gösterilen tutarlar işleten tutarıdır, yani sürücü cezasının 2 katıdır. Sürücüye ayrıca ceza kesilir.',
      'EN':
          'The amounts shown are operator fines, i.e. twice the driver amount. The driver is fined separately as well.',
      'DE':
          'Die angezeigten Beträge sind Halterbußgelder, also das Doppelte des Fahrerbußgelds. Der Fahrer erhält zusätzlich ein eigenes Bußgeld.',
    },
    'analysis.noteOperatorValue': {
      'TR': 'İşletene {amount}',
      'EN': 'Operator: {amount}',
      'DE': 'Halter: {amount}',
    },
    'analysis.noteDriverValue': {
      'TR': 'Sürücüye {amount}',
      'EN': 'Driver: {amount}',
      'DE': 'Fahrer: {amount}',
    },
    'analysis.noteEarlyPaymentBody': {
      'TR':
          'Ceza, tebliğ tarihinden itibaren 15 gün içinde ödenirse %25 indirim uygulanır.',
      'EN':
          'If the fine is paid within 15 days of notification, a 25% discount applies.',
      'DE':
          'Wird das Bußgeld innerhalb von 15 Tagen nach Zustellung bezahlt, gibt es 25 % Rabatt.',
    },
    'analysis.noteEarlyPaymentValue': {
      'TR': '{discounted}\n({full} yerine)',
      'EN': '{discounted}\n(instead of {full})',
      'DE': '{discounted}\n(statt {full})',
    },
    'analysis.notePointsTitle': {
      'TR': 'Ceza puanı',
      'EN': 'Penalty points',
      'DE': 'Strafpunkte',
    },
    'analysis.notePointsBody': {
      'TR': 'Her ihlal sürücü belgesine 20 ceza puanı işler.',
      'EN': 'Each violation adds 20 penalty points to the licence.',
      'DE': 'Jeder Verstoß bringt 20 Strafpunkte auf den Führerschein.',
    },
    'analysis.notePointsValue': {
      'TR': '{points} puan',
      'EN': '{points} points',
      'DE': '{points} Punkte',
    },
    'analysis.noteBanTitle': {
      'TR': 'Araç kullanmaktan men',
      'EN': 'Driving ban',
      'DE': 'Fahrverbot',
    },
    'analysis.noteBanBody': {
      'TR': 'Her ihlalde sürücü araç kullanmaktan men edilir.',
      'EN': 'With every violation the driver is barred from driving on.',
      'DE': 'Bei jedem Verstoß wird die Weiterfahrt untersagt.',
    },
    'analysis.noteBanValue': {'TR': 'Uygulanır', 'EN': 'Applies', 'DE': 'Gilt'},
    'analysis.notesColRule': {'TR': 'Kural', 'EN': 'Rule', 'DE': 'Regel'},
    'analysis.notesColValue': {
      'TR': 'Bu gün',
      'EN': 'This day',
      'DE': 'Dieser Tag',
    },
    'analysis.tableSeverity': {
      'TR': 'Ciddiyet (AB)',
      'EN': 'Severity (EU)',
      'DE': 'Schwere (EU)',
    },
    'analysis.tableLegalBasis': {
      'TR': 'Yasal dayanak',
      'EN': 'Legal basis',
      'DE': 'Rechtsgrundlage',
    },
    'analysis.tableTier': {'TR': 'Kademe', 'EN': 'Tier', 'DE': 'Stufe'},
    'analysis.tableFine': {'TR': 'Ceza tutarı', 'EN': 'Fine', 'DE': 'Bußgeld'},
    'analysis.tableDiscounted': {
      'TR': '%25 indirimli',
      'EN': 'With 25% discount',
      'DE': 'Mit 25 % Rabatt',
    },
    'analysis.tablePoints': {
      'TR': 'Ceza puanı',
      'EN': 'Penalty points',
      'DE': 'Strafpunkte',
    },
    'analysis.tableSanction': {
      'TR': 'Ek yaptırım',
      'EN': 'Further sanction',
      'DE': 'Weitere Sanktion',
    },
    'analysis.riskBreakdownTitle': {
      'TR': 'Puan Dökümü',
      'EN': 'Score Breakdown',
      'DE': 'Punkteaufschlüsselung',
    },
    'analysis.riskBreakdownStart': {
      'TR': 'Başlangıç puanı',
      'EN': 'Starting score',
      'DE': 'Ausgangswert',
    },
    'analysis.riskBreakdownTotal': {
      'TR': 'Toplam düşüş',
      'EN': 'Total deducted',
      'DE': 'Gesamtabzug',
    },
    'analysis.riskBreakdownScore': {
      'TR': 'Uyum risk skoru',
      'EN': 'Compliance risk score',
      'DE': 'Compliance-Risikowert',
    },
    'analysis.riskBreakdownByType': {
      'TR': 'İhlal türüne göre',
      'EN': 'By violation type',
      'DE': 'Nach Verstoßart',
    },
    'analysis.riskBreakdownByViolation': {
      'TR': 'Tek tek ihlaller',
      'EN': 'Violation by violation',
      'DE': 'Einzelne Verstöße',
    },
    'analysis.riskBreakdownColType': {
      'TR': 'İhlal türü',
      'EN': 'Violation type',
      'DE': 'Verstoßart',
    },
    'analysis.riskBreakdownColCount': {
      'TR': 'Adet',
      'EN': 'Count',
      'DE': 'Anzahl',
    },
    'analysis.riskBreakdownColPoints': {
      'TR': 'Düşüş',
      'EN': 'Deducted',
      'DE': 'Abzug',
    },
    'analysis.riskBreakdownColDate': {
      'TR': 'Tarih',
      'EN': 'Date',
      'DE': 'Datum',
    },
    'analysis.riskBreakdownColViolation': {
      'TR': 'İhlal',
      'EN': 'Violation',
      'DE': 'Verstoß',
    },
    'analysis.riskBreakdownCapped': {
      'TR': '(üst sınır)',
      'EN': '(capped)',
      'DE': '(gedeckelt)',
    },
    'analysis.riskBreakdownEmpty': {
      'TR': 'Son 28 günde ihlal yok, puan düşülmedi.',
      'EN': 'No violations in the last 28 days, nothing was deducted.',
      'DE': 'Keine Verstöße in den letzten 28 Tagen, nichts abgezogen.',
    },
    'analysis.riskBreakdownNote': {
      'TR':
          'Son 28 gündeki ihlaller sayılır. Her ihlal türünün bir temel puanı vardır; aşım ne kadar uzunsa düşüş o kadar artar (en fazla 1,75 katı). Aynı türden ihlallerin toplam düşüşü bir üst sınırı geçemez.',
      'EN':
          'Violations from the last 28 days count. Each violation type has a base deduction that grows with the size of the overage (up to 1.75×). The total for one type cannot exceed its cap.',
      'DE':
          'Gezählt werden Verstöße der letzten 28 Tage. Jede Verstoßart hat einen Grundabzug, der mit der Überschreitung wächst (bis 1,75-fach). Der Gesamtabzug einer Art ist gedeckelt.',
    },
    'analysis.sevIntro': {
      'TR':
          'Sürüş ve dinlenme ihlallerinin AB ciddiyet seviyesi ve 2026 Türkiye cezası.',
      'EN':
          'EU severity level and 2026 Turkish fine for driving and rest-time violations.',
      'DE':
          'EU-Schweregrad und türkisches Bußgeld 2026 für Lenk- und Ruhezeitverstöße.',
    },
    'analysis.sevGroupCrew': {
      'TR': 'Mürettebat',
      'EN': 'Crew',
      'DE': 'Fahrpersonal',
    },
    'analysis.sevGroupDriving': {
      'TR': 'Sürüş süreleri',
      'EN': 'Driving times',
      'DE': 'Lenkzeiten',
    },
    'analysis.sevGroupBreaks': {
      'TR': 'Molalar',
      'EN': 'Breaks',
      'DE': 'Fahrtunterbrechungen',
    },
    'analysis.sevGroupRest': {
      'TR': 'Dinlenme süreleri',
      'EN': 'Rest periods',
      'DE': 'Ruhezeiten',
    },
    'analysis.sevGroup12Day': {
      'TR': '12 gün kuralı istisnası',
      'EN': '12-day rule derogation',
      'DE': '12-Tage-Ausnahme',
    },
    'analysis.sevGroupWork': {
      'TR': 'İş organizasyonu',
      'EN': 'Work organisation',
      'DE': 'Arbeitsorganisation',
    },
    'analysis.sevRuleMinAge': {
      'TR': 'Sürücü asgari yaşı',
      'EN': 'Minimum driver age',
      'DE': 'Mindestalter des Fahrers',
    },
    'analysis.sevRuleDaily9': {
      'TR': 'Günlük sürüş (9 saat sınırı)',
      'EN': 'Daily driving (9 h limit)',
      'DE': 'Tageslenkzeit (9-Std.-Grenze)',
    },
    'analysis.sevRuleDaily10': {
      'TR': 'Uzatmalı günlük sürüş (10 saat sınırı)',
      'EN': 'Extended daily driving (10 h limit)',
      'DE': 'Verlängerte Tageslenkzeit (10-Std.-Grenze)',
    },
    'analysis.sevRuleWeekly': {
      'TR': 'Haftalık sürüş (56 saat sınırı)',
      'EN': 'Weekly driving (56 h limit)',
      'DE': 'Wochenlenkzeit (56-Std.-Grenze)',
    },
    'analysis.sevRuleBiWeekly': {
      'TR': 'İki haftalık sürüş (90 saat sınırı)',
      'EN': 'Two-week driving (90 h limit)',
      'DE': 'Doppelwochenlenkzeit (90-Std.-Grenze)',
    },
    'analysis.sevRuleContinuous': {
      'TR': 'Molasız sürüş (4 saat 30 dakika sınırı)',
      'EN': 'Driving without a break (4 h 30 min limit)',
      'DE': 'Lenkzeit ohne Pause (4 Std. 30 Min. Grenze)',
    },
    'analysis.sevRuleDailyRest11': {
      'TR': 'Günlük dinlenme (11 saat gerekli)',
      'EN': 'Daily rest (11 h required)',
      'DE': 'Tägliche Ruhezeit (11 Std. nötig)',
    },
    'analysis.sevRuleDailyRest9': {
      'TR': 'İndirgenmiş günlük dinlenme (9 saat gerekli)',
      'EN': 'Reduced daily rest (9 h required)',
      'DE': 'Reduzierte tägliche Ruhezeit (9 Std. nötig)',
    },
    'analysis.sevRuleSplitRest': {
      'TR': 'Bölünmüş günlük dinlenme (3 + 9 saat gerekli)',
      'EN': 'Split daily rest (3 + 9 h required)',
      'DE': 'Aufgeteilte tägliche Ruhezeit (3 + 9 Std. nötig)',
    },
    'analysis.sevRuleMultiManning': {
      'TR': 'Çok sürücülü araçta günlük dinlenme (9 saat gerekli)',
      'EN': 'Daily rest, multi-manning (9 h required)',
      'DE': 'Tägliche Ruhezeit, Mehrfahrerbetrieb (9 Std. nötig)',
    },
    'analysis.sevRuleReducedWeeklyRest': {
      'TR': 'İndirgenmiş haftalık dinlenme (24 saat gerekli)',
      'EN': 'Reduced weekly rest (24 h required)',
      'DE': 'Reduzierte Wochenruhezeit (24 Std. nötig)',
    },
    'analysis.sevRuleWeeklyRest45': {
      'TR': 'Haftalık dinlenme (45 saat gerekli)',
      'EN': 'Weekly rest (45 h required)',
      'DE': 'Wochenruhezeit (45 Std. nötig)',
    },
    'analysis.sevRuleWeeklyRestLate': {
      'TR': 'Haftalık dinlenmede gecikme (6 × 24 saatten sonra)',
      'EN': 'Late weekly rest (after six 24 h periods)',
      'DE': 'Verspätete Wochenruhezeit (nach 6 × 24 Std.)',
    },
    'analysis.sevRule12Day': {
      'TR': '12 gün kuralında gecikme (12 × 24 saatten sonra)',
      'EN': 'Late rest under the 12-day rule (after twelve 24 h periods)',
      'DE': 'Verspätung bei der 12-Tage-Regel (nach 12 × 24 Std.)',
    },
    'analysis.sevRule12DayRest': {
      'TR': '12 günden sonraki haftalık dinlenme',
      'EN': 'Weekly rest after 12 days',
      'DE': 'Wochenruhezeit nach 12 Tagen',
    },
    'analysis.sevRuleNightDriving': {
      'TR': 'Gece molasız sürüş (22:00–06:00, tek sürücü)',
      'EN': 'Night driving without a break (22:00–06:00, single driver)',
      'DE': 'Nachtlenkzeit ohne Pause (22:00–06:00, ein Fahrer)',
    },
    'analysis.sevRuleWageLink': {
      'TR': 'Ücretin mesafeye veya yüke bağlanması',
      'EN': 'Pay linked to distance or load',
      'DE': 'Lohn nach Strecke oder Ladung',
    },
    'analysis.sevRuleWorkOrganisation': {
      'TR': 'Sürücünün işinin düzenlenmemesi',
      'EN': "Driver's work not organised",
      'DE': 'Arbeit des Fahrers nicht organisiert',
    },
    'analysis.sevConditionNoBreak': {
      'TR': 'molasız',
      'EN': 'no break',
      'DE': 'ohne Pause',
    },
    'analysis.sevNoTrPenalty': {
      'TR': 'Karşılığı yok',
      'EN': 'No equivalent',
      'DE': 'Keine Entsprechung',
    },
    'analysis.sevOperatorDoubleOnly': {
      'TR': 'Ayrı ceza yok',
      'EN': 'No separate fine',
      'DE': 'Kein eigenes Bußgeld',
    },
    'analysis.sevAnyCase': {
      'TR': 'Her durumda',
      'EN': 'In all cases',
      'DE': 'In jedem Fall',
    },
    'analysis.sevColRange': {'TR': 'Süre', 'EN': 'Time', 'DE': 'Zeit'},
    'analysis.sevColSeverity': {'TR': 'Seviye', 'EN': 'Level', 'DE': 'Stufe'},
    'analysis.sevColFine': {'TR': 'Ceza', 'EN': 'Fine', 'DE': 'Bußgeld'},
    'analysis.unitHourShort': {'TR': 'sa', 'EN': 'h', 'DE': 'Std.'},
    'analysis.unitMinuteShort': {'TR': 'dk', 'EN': 'min', 'DE': 'Min.'},
    'analysis.sevFootnoteFine': {
      'TR':
          'Tutarlar sürücü cezasıdır. 15 gün içinde ödenirse %25 indirim uygulanır; işletene 2 katı kesilir.',
      'EN':
          'Amounts are driver fines. Paid within 15 days they are 25% lower; the operator pays double.',
      'DE':
          'Beträge sind Fahrerbußgelder. Bei Zahlung binnen 15 Tagen 25 % weniger; der Halter zahlt das Doppelte.',
    },
    'analysis.sanctionDrivingBan': {
      'TR': 'Araç kullanmaktan men',
      'EN': 'Barred from driving on',
      'DE': 'Weiterfahrt untersagt',
    },
    'analysis.euSeverityMI': {
      'TR': 'Hafif ihlal (MI)',
      'EN': 'Minor (MI)',
      'DE': 'Geringfügig (MI)',
    },
    'analysis.euSeveritySI': {
      'TR': 'Ciddi ihlal (SI)',
      'EN': 'Serious (SI)',
      'DE': 'Schwer (SI)',
    },
    'analysis.euSeverityVSI': {
      'TR': 'Çok ciddi ihlal (VSI)',
      'EN': 'Very serious (VSI)',
      'DE': 'Sehr schwer (VSI)',
    },
    'analysis.euSeverityMSI': {
      'TR': 'En ağır ihlal (MSI)',
      'EN': 'Most serious (MSI)',
      'DE': 'Schwerwiegendster Verstoß (MSI)',
    },
    'analysis.insightDetailsDialogTitle': {
      'TR': 'Bu haftaki ilgili ihlaller',
      'EN': "This week's related violations",
      'DE': 'Verstöße dieser Woche',
    },
    'analysis.activeSuffix': {'TR': 'Aktif', 'EN': 'Active', 'DE': 'Aktiv'},
    'analysis.backupDriverSuffix': {
      'TR': 'Yedek',
      'EN': 'Backup',
      'DE': 'Ersatz',
    },
    'analysis.weekRangeLabel': {
      'TR': '{range} haftası',
      'EN': 'Week of {range}',
      'DE': 'Woche vom {range}',
    },
    'analysis.insightRestChartCaption': {
      'TR': 'Haftalık Dinlenme Eksikliği (Dakika)',
      'EN': 'Weekly Rest Deficit (Minutes)',
      'DE': 'Wöchentliches Ruhezeitdefizit (Minuten)',
    },
    'analysis.insightDrivingChartCaption': {
      'TR': 'Günlük Sürüş İhlali Sayısı',
      'EN': 'Daily Driving Violation Count',
      'DE': 'Tägliche Anzahl an Lenkzeitverstößen',
    },
    'analysis.insightCleanChartCaption': {
      'TR': 'Haftalık Uyum Durumu',
      'EN': 'Weekly Compliance Status',
      'DE': 'Wöchentlicher Konformitätsstatus',
    },
    'analysis.minutesUnit': {'TR': 'dk', 'EN': 'min', 'DE': 'Min'},

    'alerts.pageTitle': {
      'TR': 'Uyarılar ve Durumlar',
      'EN': 'Alerts and Status',
      'DE': 'Warnungen und Status',
    },
    'alerts.pageSubtitle': {
      'TR':
          'Takograf verilerinizden derlenen güncel ihlal ve sistem durumu raporu.',
      'EN':
          'Current violation and system-status report compiled from your tachograph data.',
      'DE':
          'Aktueller Verstoß- und Systemstatusbericht aus Ihren Fahrtenschreiberdaten.',
    },
    'alerts.drivingRestTitle': {
      'TR': 'Sürüş ve Dinlenme Süresi',
      'EN': 'Driving & Rest Time',
      'DE': 'Lenk- und Ruhezeit',
    },
    'alerts.drivingRestDesc': {
      'TR':
          'Sürüş ve dinlenme süresi ihlalleri ve tespit edilen kural aşımları.',
      'EN': 'Driving and rest time violations and detected rule breaches.',
      'DE': 'Verstöße gegen Lenk- und Ruhezeiten sowie erkannte Regelverstöße.',
    },
    'alerts.cardUsageTitle': {
      'TR': 'Kart ve Kullanım İhlalleri',
      'EN': 'Card & Usage Violations',
      'DE': 'Karten- und Nutzungsverstöße',
    },
    'alerts.cardUsageDesc': {
      'TR':
          'Sürücü kartı takılmadan sürüş veya geçersiz/okunamayan kart durumları.',
      'EN':
          'Driving without a driver card, or invalid/unreadable card conditions.',
      'DE':
          'Fahren ohne Fahrerkarte oder ungültige/nicht lesbare Kartenzustände.',
    },
    'alerts.speedingTitle': {
      'TR': 'Hız İhlalleri',
      'EN': 'Speeding',
      'DE': 'Geschwindigkeitsüberschreitungen',
    },
    'alerts.speedingDesc': {
      'TR': 'Yasal hız sınırının üzerindeki anlık ve kayıtlı hız verileri.',
      'EN': 'Live and recorded speed readings above the legal limit.',
      'DE':
          'Aktuelle und aufgezeichnete Geschwindigkeiten über dem gesetzlichen Limit.',
    },
    'alerts.securityTitle': {
      'TR': 'Güvenlik ve Sabotaj',
      'EN': 'Security & Tampering',
      'DE': 'Sicherheit und Manipulation',
    },
    'alerts.securityDesc': {
      'TR': 'Cihaz müdahaleleri, veri bütünlüğü ve güvenlik olayları.',
      'EN': 'Device tampering, data-integrity and security events.',
      'DE': 'Geräteeingriffe, Datenintegritäts- und Sicherheitsereignisse.',
    },
    'alerts.hardwareTitle': {
      'TR': 'Donanım ve Sistem',
      'EN': 'Hardware & System',
      'DE': 'Hardware und System',
    },
    'alerts.hardwareDesc': {
      'TR': 'Takograf cihazı arızaları ve sensör hataları.',
      'EN': 'Tachograph unit faults and sensor errors.',
      'DE': 'Fahrtenschreiber-Gerätefehler und Sensorfehler.',
    },
    'alerts.maintenanceTitle': {
      'TR': 'Bakım ve Rutinler',
      'EN': 'Maintenance & Reminders',
      'DE': 'Wartung und Erinnerungen',
    },
    'alerts.maintenanceDesc': {
      'TR': 'Kalibrasyon ve sürücü kartı geçerlilik hatırlatmaları.',
      'EN': 'Calibration and driver-card validity reminders.',
      'DE': 'Erinnerungen an Kalibrierung und Gültigkeit der Fahrerkarte.',
    },
    'alerts.badgeOk': {
      'TR': 'Sorun Yok',
      'EN': 'No Issues',
      'DE': 'Keine Probleme',
    },
    'alerts.badgeCritical': {
      'TR': 'Kritik',
      'EN': 'Critical',
      'DE': 'Kritisch',
    },
    'alerts.badgeSecure': {'TR': 'Güvenli', 'EN': 'Secure', 'DE': 'Sicher'},
    'alerts.badgeTechnical': {
      'TR': 'Teknik',
      'EN': 'Technical',
      'DE': 'Technisch',
    },
    'alerts.badgeNoData': {
      'TR': 'Veri Yok',
      'EN': 'No Data',
      'DE': 'Keine Daten',
    },
    'alerts.badgeActiveCount': {
      'TR': '{count} Aktif',
      'EN': '{count} Active',
      'DE': '{count} Aktiv',
    },
    'alerts.cardlessDriving': {
      'TR': 'Kartsız sürüş algılandı',
      'EN': 'Cardless driving detected',
      'DE': 'Fahren ohne Karte erkannt',
    },
    'alerts.liveNow': {
      'TR': 'Şimdi (canlı)',
      'EN': 'Now (live)',
      'DE': 'Jetzt (live)',
    },
    'alerts.speedExceededLive': {
      'TR': 'Hız sınırı aşıldı: {speed} km/s (Sınır: {limit} km/s)',
      'EN': 'Speed limit exceeded: {speed} km/h (Limit: {limit} km/h)',
      'DE':
          'Geschwindigkeitslimit überschritten: {speed} km/h (Limit: {limit} km/h)',
    },

    'alerts.speedExceededVu': {
      'TR':
          'Hız aşımı (Takograf): Maks. {maxSpeed} km/s (Ort. {avgSpeed} km/s)',
      'EN':
          'Overspeeding (Tachograph): Max {maxSpeed} km/h (Avg {avgSpeed} km/h)',
      'DE':
          'Geschwindigkeitsüberschreitung (Fahrtenschreiber): Max. {maxSpeed} km/h (Ø {avgSpeed} km/h)',
    },
    'alerts.noDataDesc': {
      'TR':
          'Bu bilgi için önce takograftan gerçek veri okunmalı (Bluetooth bağlantısı / kart indirme).',
      'EN':
          'This requires real data from the tachograph first (Bluetooth connection / card download).',
      'DE':
          'Hierfür werden zunächst echte Daten vom Fahrtenschreiber benötigt (Bluetooth-Verbindung / Kartendownload).',
    },
    'alerts.cardUsageEmpty': {
      'TR': 'İncelenen veride kart/kullanım ihlali bulunmuyor.',
      'EN': 'No card/usage violations found in the examined data.',
      'DE':
          'Im untersuchten Daten wurden keine Karten-/Nutzungsverstöße gefunden.',
    },
    'alerts.securityEmpty': {
      'TR': 'İncelenen veride güvenlik/bütünlük olayı tespit edilmedi.',
      'EN': 'No security/integrity events found in the examined data.',
      'DE':
          'Im untersuchten Daten wurden keine Sicherheits-/Integritätsereignisse gefunden.',
    },
    'alerts.hardwareEmpty': {
      'TR': 'Bildirilen bir donanım arızası yok.',
      'EN': 'No hardware faults reported.',
      'DE': 'Keine gemeldeten Hardwarefehler.',
    },
    'alerts.daysLeftLabel': {
      'TR': '{d} gün kaldı',
      'EN': '{d} days left',
      'DE': 'noch {d} Tage',
    },
    'alerts.eventLogTitle': {
      'TR': 'Son Olay Günlüğü',
      'EN': 'Recent Event Log',
      'DE': 'Letztes Ereignisprotokoll',
    },
    'alerts.eventLogEmpty': {
      'TR': 'Henüz kaydedilmiş bir olay yok.',
      'EN': 'No events recorded yet.',
      'DE': 'Noch keine Ereignisse aufgezeichnet.',
    },

    'driverIdentity.bannerText': {
      'TR': 'Sürücü Kimliği — detaylar için dokunun',
      'EN': 'Driver Identity — tap for details',
      'DE': 'Fahreridentität — für Details tippen',
    },
    'driverIdentity.title': {
      'TR': 'Sürücü Kimliği',
      'EN': 'Driver Identity',
      'DE': 'Fahreridentität',
    },
    'driverIdentity.name': {'TR': 'Ad Soyad', 'EN': 'Full Name', 'DE': 'Name'},
    'driverIdentity.issuingState': {
      'TR': 'Kartı Veren Ülke',
      'EN': 'Issuing State',
      'DE': 'Ausstellender Staat',
    },
    'driverIdentity.cardNumber': {
      'TR': 'Kart Numarası',
      'EN': 'Card Number',
      'DE': 'Kartennummer',
    },
    'driverIdentity.language': {
      'TR': 'Tercih Edilen Dil',
      'EN': 'Preferred Language',
      'DE': 'Bevorzugte Sprache',
    },
    'driverIdentity.expiryDate': {
      'TR': 'Kart Bitiş Tarihi',
      'EN': 'Card Expiry Date',
      'DE': 'Kartenablaufdatum',
    },
    'driverIdentity.nextDownloadDate': {
      'TR': 'Sonraki Zorunlu İndirme Tarihi',
      'EN': 'Next Mandatory Download Date',
      'DE': 'Nächstes Pflicht-Downloaddatum',
    },

    'alerts.deviceReported': {
      'TR': 'Takograf bildirimi (canlı)',
      'EN': 'Tachograph notification (live)',
      'DE': 'Fahrtenschreiber-Meldung (live)',
    },
    'alerts.trsContinuousPreWarning': {
      'TR': 'Sürekli sürüş süresi ön uyarısı (4s30d\'ye 15 dk kaldı)',
      'EN': 'Continuous driving time pre-warning (15 min before 4h30)',
      'DE': 'Vorwarnung Dauerlenkzeit (15 Min. vor 4Std30Min)',
    },
    'alerts.trsDailyPreWarning': {
      'TR': 'Günlük sürüş süresi ön uyarısı',
      'EN': 'Daily driving time pre-warning',
      'DE': 'Vorwarnung Tageslenkzeit',
    },
    'alerts.trsRestPreWarning': {
      'TR': 'Günlük/haftalık dinlenme ön uyarısı',
      'EN': 'Daily/weekly rest pre-warning',
      'DE': 'Vorwarnung tägliche/wöchentliche Ruhezeit',
    },
    'alerts.trsRestWarning': {
      'TR': 'Günlük/haftalık dinlenme uyarısı',
      'EN': 'Daily/weekly rest warning',
      'DE': 'Warnung tägliche/wöchentliche Ruhezeit',
    },
    'alerts.trsWeeklyPreWarning': {
      'TR': 'Haftalık sürüş süresi ön uyarısı',
      'EN': 'Weekly driving time pre-warning',
      'DE': 'Vorwarnung Wochenlenkzeit',
    },
    'alerts.trsBiWeeklyPreWarning': {
      'TR': 'İki haftalık sürüş süresi ön uyarısı',
      'EN': 'Bi-weekly driving time pre-warning',
      'DE': 'Vorwarnung Zweiwochenlenkzeit',
    },
    'alerts.trsCardExpiryWarning': {
      'TR': 'Sürücü kartı süresi doluyor (cihaz uyarısı)',
      'EN': 'Driver card expiring (device warning)',
      'DE': 'Fahrerkarte läuft ab (Gerätewarnung)',
    },
    'alerts.trsNextDownloadWarning': {
      'TR': 'Zorunlu kart indirme yaklaşıyor (cihaz uyarısı)',
      'EN': 'Mandatory card download approaching (device warning)',
      'DE': 'Pflicht-Kartendownload steht bevor (Gerätewarnung)',
    },
    'alerts.trsOther': {
      'TR': 'Diğer takograf uyarısı',
      'EN': 'Other tachograph warning',
      'DE': 'Sonstige Fahrtenschreiber-Warnung',
    },
    'scan.removeBondTitle': {
      'TR': 'Eşleşme kaldırılsın mı?',
      'EN': 'Remove pairing?',
      'DE': 'Kopplung entfernen?',
    },
    'scan.removeBondBody': {
      'TR':
          '{device} bu telefonun eşleşmiş cihazlarından silinecek. Sonraki bağlantıda takograf ekranındaki kodu yeniden onaylamanız gerekir.',
      'EN':
          '{device} will be removed from this phone\'s paired devices. On the next connection you will have to confirm the code on the tachograph display again.',
      'DE':
          '{device} wird aus den gekoppelten Geräten dieses Telefons entfernt. Bei der nächsten Verbindung müssen Sie den Code auf dem Tachographen-Display erneut bestätigen.',
    },
    'scan.removeBondConfirm': {
      'TR': 'Kaldır',
      'EN': 'Remove',
      'DE': 'Entfernen',
    },
    'scan.bondRemoved': {
      'TR': '{device}: eşleşme kaldırıldı.',
      'EN': '{device}: pairing removed.',
      'DE': '{device}: Kopplung entfernt.',
    },
    'scan.bondRemoveFailed': {
      'TR': '{device}: eşleşme kaldırılamadı ({error}).',
      'EN': '{device}: the pairing could not be removed ({error}).',
      'DE': '{device}: Kopplung konnte nicht entfernt werden ({error}).',
    },
    'scan.timeout': {
      'TR': 'Cihaz yanıt vermiyor (zaman aşımı)',
      'EN': 'The device is not responding (timed out)',
      'DE': 'Das Gerät antwortet nicht (Zeitüberschreitung)',
    },
    'scan.connectFailed': {
      'TR': 'Bağlanılamadı ({error})',
      'EN': 'Could not connect ({error})',
      'DE': 'Verbindung fehlgeschlagen ({error})',
    },
    'scan.signalExcellent': {
      'TR': 'Mükemmel Sinyal',
      'EN': 'Excellent Signal',
      'DE': 'Ausgezeichnetes Signal',
    },
    'scan.signalStrong': {
      'TR': 'Güçlü Sinyal',
      'EN': 'Strong Signal',
      'DE': 'Starkes Signal',
    },
    'scan.signalMedium': {
      'TR': 'Orta Sinyal',
      'EN': 'Medium Signal',
      'DE': 'Mittleres Signal',
    },
    'scan.signalWeak': {
      'TR': 'Zayıf Sinyal',
      'EN': 'Weak Signal',
      'DE': 'Schwaches Signal',
    },
    'scan.rescan': {
      'TR': 'Yeniden Ara',
      'EN': 'Scan Again',
      'DE': 'Erneut suchen',
    },
    'scan.scanning': {
      'TR': 'Cihazlar taranıyor...',
      'EN': 'Scanning for devices...',
      'DE': 'Geräte werden gesucht...',
    },
    'scan.scanningHint': {
      'TR': 'Bluetooth kapsama alanındaki aygıtlar aranıyor',
      'EN': 'Looking for devices within Bluetooth range',
      'DE': 'Suche nach Geräten in Bluetooth-Reichweite',
    },
    'scan.noneFound': {
      'TR': 'Cihaz bulunamadı',
      'EN': 'No devices found',
      'DE': 'Keine Geräte gefunden',
    },
    'scan.noneFoundHint': {
      'TR': 'Tekrar taramak için yukarıdaki simgeye dokunun',
      'EN': 'Tap the icon above to scan again',
      'DE': 'Tippen Sie auf das Symbol oben, um erneut zu suchen',
    },
    'scan.done': {
      'TR': 'Tarama tamamlandı',
      'EN': 'Scan complete',
      'DE': 'Suche abgeschlossen',
    },
    'scan.foundCount': {
      'TR': 'Bulunan cihaz: {count}',
      'EN': 'Devices found: {count}',
      'DE': 'Gefundene Geräte: {count}',
    },
    'scan.nearDevices': {
      'TR': 'Yakındaki Cihazlar',
      'EN': 'Nearby Devices',
      'DE': 'Geräte in der Nähe',
    },
    'scan.allDevices': {
      'TR': 'Tüm Cihazlar',
      'EN': 'All Devices',
      'DE': 'Alle Geräte',
    },
    'scan.clearFilter': {
      'TR': 'Filtreyi Kaldır',
      'EN': 'Clear Filter',
      'DE': 'Filter entfernen',
    },
    'scan.filter': {'TR': 'Filtrele', 'EN': 'Filter', 'DE': 'Filtern'},
    'scan.searching': {
      'TR': 'Aranıyor...',
      'EN': 'Searching...',
      'DE': 'Suche läuft...',
    },
    'scan.noneNear': {
      'TR': 'Yakında cihaz yok',
      'EN': 'No devices nearby',
      'DE': 'Keine Geräte in der Nähe',
    },
    'scan.sectionTachographs': {
      'TR': 'Takograflar',
      'EN': 'Tachographs',
      'DE': 'Tachographen',
    },
    'scan.sectionDongles': {
      'TR': 'Dongle\'lar ve diğer cihazlar',
      'EN': 'Dongles and other devices',
      'DE': 'Dongles und andere Geräte',
    },
    'scan.donglesHint': {
      'TR':
          'Adı görünen diğer Bluetooth cihazları. Dongle\'ınızı adından tanıyabilirsiniz.',
      'EN':
          'Other Bluetooth devices that show a name. You can recognise your dongle by its name.',
      'DE':
          'Andere Bluetooth-Geräte mit sichtbarem Namen. Ihren Dongle erkennen Sie an seinem Namen.',
    },
    'scan.tagTachograph': {
      'TR': 'TAKOGRAF',
      'EN': 'TACHOGRAPH',
      'DE': 'TACHOGRAPH',
    },
    'scan.tagDongle': {'TR': 'DONGLE', 'EN': 'DONGLE', 'DE': 'DONGLE'},
    'scan.tagPaired': {'TR': 'EŞLEŞTİ', 'EN': 'PAIRED', 'DE': 'GEKOPPELT'},
    'scan.removeBondTooltip': {
      'TR': 'Eşleşmeyi kaldır',
      'EN': 'Remove pairing',
      'DE': 'Kopplung entfernen',
    },
    'scan.connect': {'TR': 'Bağlan', 'EN': 'Connect', 'DE': 'Verbinden'},
    'scan.phaseConnecting': {
      'TR': 'Bağlanılıyor...',
      'EN': 'Connecting...',
      'DE': 'Verbindung wird hergestellt...',
    },
    'scan.phaseDiscovering': {
      'TR': 'Servisler aranıyor...',
      'EN': 'Looking for services...',
      'DE': 'Dienste werden gesucht...',
    },
    'scan.phaseBonding': {
      'TR':
          'Takograf ekranındaki 6 haneli kod telefondakiyle aynıysa iki tarafta da onaylayın (25 sn).',
      'EN':
          'If the 6-digit code on the tachograph display matches the one on the phone, confirm it on both (25 s).',
      'DE':
          'Wenn der 6-stellige Code auf dem Tachographen-Display mit dem auf dem Telefon übereinstimmt, bestätigen Sie ihn auf beiden Seiten (25 s).',
    },
    'scan.phaseSubscribing': {
      'TR': 'Veri kanalı açılıyor...',
      'EN': 'Opening the data channel...',
      'DE': 'Datenkanal wird geöffnet...',
    },
    'scan.phaseReading': {
      'TR': 'Takograf verileri okunuyor...',
      'EN': 'Reading tachograph data...',
      'DE': 'Tachographendaten werden gelesen...',
    },
    'scan.permissionDenied': {
      'TR':
          'Bluetooth taraması için gerekli izin verilmedi. Lütfen uygulama ayarlarından "Yakındaki cihazlar" iznini verin.',
      'EN':
          'The permission needed for Bluetooth scanning was not granted. Please allow "Nearby devices" in the app settings.',
      'DE':
          'Die für die Bluetooth-Suche nötige Berechtigung wurde nicht erteilt. Bitte erlauben Sie „Geräte in der Nähe“ in den App-Einstellungen.',
    },
    'scan.openSettings': {
      'TR': 'Ayarları Aç',
      'EN': 'Open Settings',
      'DE': 'Einstellungen öffnen',
    },
    'scan.helpFooter': {
      'TR':
          'Takografınızı listede göremiyor musunuz? Bluetooth yalnızca kontak açıkken yayın yapar; takograf "TACHOGRAPH-" ile başlayan adıyla görünür. Dongle\'lar kendi adlarıyla alttaki bölümde listelenir.',
      'EN':
          'Can\'t see your tachograph in the list? It only broadcasts over Bluetooth with the ignition on, and appears under a name starting with "TACHOGRAPH-". Dongles are listed under their own names in the section below.',
      'DE':
          'Sie sehen Ihren Tachographen nicht in der Liste? Er sendet nur bei eingeschalteter Zündung über Bluetooth und erscheint mit einem Namen, der mit „TACHOGRAPH-“ beginnt. Dongles stehen mit ihrem eigenen Namen im Abschnitt darunter.',
    },
    'bt.unknownDevice': {
      'TR': 'Bilinmeyen Cihaz ({id})',
      'EN': 'Unknown Device ({id})',
      'DE': 'Unbekanntes Gerät ({id})',
    },
    'bt.removeBondIos': {
      'TR':
          'Eşleşme yalnızca Android\'de uygulamadan kaldırılabilir; iOS\'ta Ayarlar > Bluetooth üzerinden kaldırın.',
      'EN':
          'Pairings can be removed from the app only on Android; on iOS remove it in Settings > Bluetooth.',
      'DE':
          'Kopplungen lassen sich nur unter Android in der App entfernen; unter iOS entfernen Sie sie unter Einstellungen > Bluetooth.',
    },
    'link.noAppService': {
      'TR':
          'Cihazda SmartTrack uygulama servisi bulunamadı. Takografın ya da dongle\'ın yazılımı bu servisi desteklemiyor olabilir.',
      'EN':
          'The SmartTrack app service was not found on the device. The tachograph\'s or dongle\'s software may not support it.',
      'DE':
          'Der SmartTrack-App-Dienst wurde auf dem Gerät nicht gefunden. Die Software des Tachographen oder Dongles unterstützt ihn möglicherweise nicht.',
    },
    'link.bondFailed': {
      'TR':
          'Eşleşme tamamlanmadı. Takograf ekranındaki 6 haneli kodu telefondakiyle karşılaştırıp 25 saniye içinde iki tarafta da onaylayın.',
      'EN':
          'Pairing was not completed. Compare the 6-digit code on the tachograph display with the one on the phone and confirm it on both within 25 seconds.',
      'DE':
          'Die Kopplung wurde nicht abgeschlossen. Vergleichen Sie den 6-stelligen Code auf dem Tachographen-Display mit dem auf dem Telefon und bestätigen Sie ihn innerhalb von 25 Sekunden auf beiden Seiten.',
    },
    'link.connectFailedDetail': {
      'TR':
          'Takografa bağlanılamadı: {detail}. Kontağın açık ve cihazın menzilde olduğundan emin olun.',
      'EN':
          'Could not connect to the tachograph: {detail}. Make sure the ignition is on and the device is in range.',
      'DE':
          'Verbindung zum Tachographen fehlgeschlagen: {detail}. Stellen Sie sicher, dass die Zündung eingeschaltet und das Gerät in Reichweite ist.',
    },
    'link.timeout': {
      'TR':
          'Takograf yanıt vermiyor (zaman aşımı). Kontağın açık olduğundan emin olun; kontak kapalıyken Bluetooth yayını yapılmaz.',
      'EN':
          'The tachograph is not responding (timed out). Make sure the ignition is on; it does not broadcast over Bluetooth with the ignition off.',
      'DE':
          'Der Tachograph antwortet nicht (Zeitüberschreitung). Stellen Sie sicher, dass die Zündung eingeschaltet ist; bei ausgeschalteter Zündung sendet er nicht über Bluetooth.',
    },
    'link.connectFailed': {
      'TR': 'Takografa bağlanılamadı ({error}).',
      'EN': 'Could not connect to the tachograph ({error}).',
      'DE': 'Verbindung zum Tachographen fehlgeschlagen ({error}).',
    },
    'link.noItsCharacteristic': {
      'TR': 'ITS karakteristiği yok: {uuid}',
      'EN': 'No ITS characteristic: {uuid}',
      'DE': 'Keine ITS-Charakteristik: {uuid}',
    },
    'link.notReady': {
      'TR': 'Bağlantı hazır değil.',
      'EN': 'The connection is not ready.',
      'DE': 'Die Verbindung ist nicht bereit.',
    },
    'link.writeFailed': {
      'TR': 'Yazma başarısız.',
      'EN': 'Write failed.',
      'DE': 'Schreiben fehlgeschlagen.',
    },
    'link.unreadable': {
      'TR': '{uuid} okunamaz.',
      'EN': '{uuid} cannot be read.',
      'DE': '{uuid} kann nicht gelesen werden.',
    },
    'link.unknownChannel': {
      'TR': 'Bilinmeyen kanal: {uuid} (yalnızca {channel})',
      'EN': 'Unknown channel: {uuid} (only {channel})',
      'DE': 'Unbekannter Kanal: {uuid} (nur {channel})',
    },
    'its.toolRhmiTitle': {
      'TR': 'Uzaktan kumanda',
      'EN': 'Remote control',
      'DE': 'Fernbedienung',
    },
    'its.toolRhmiSubtitle': {
      'TR':
          'Aktivite, yer, özel durum, uyarılar, çıktı, kart çıkarma ve manuel giriş',
      'EN':
          'Activity, place, specific condition, warnings, printout, card withdrawal and manual entry',
      'DE':
          'Aktivität, Ort, besondere Bedingung, Warnungen, Ausdruck, Kartenentnahme und manuelle Eingabe',
    },
    'its.toolDownloadTitle': {
      'TR': 'Veri indirme',
      'EN': 'Data download',
      'DE': 'Datendownload',
    },
    'its.toolDownloadSubtitle': {
      'TR': 'Sürücü kartı ve araç ünitesi verisini ITS üzerinden indir',
      'EN': 'Download driver card and vehicle unit data over ITS',
      'DE': 'Fahrerkarten- und Fahrzeugeinheitsdaten über ITS herunterladen',
    },
    'its.toolFilesTitle': {
      'TR': 'İndirilen dosyalar',
      'EN': 'Downloaded files',
      'DE': 'Heruntergeladene Dateien',
    },
    'its.toolFilesSubtitle': {
      'TR': 'Kaydedilen .ddd dosyaları: aç, paylaş, sil',
      'EN': 'Saved .ddd files: open, share, delete',
      'DE': 'Gespeicherte .ddd-Dateien: öffnen, teilen, löschen',
    },
    'its.toolAdvancedTitle': {
      'TR': 'Gelişmiş',
      'EN': 'Advanced',
      'DE': 'Erweitert',
    },
    'its.toolAdvancedSubtitle': {
      'TR': 'İndirme nesli ve kalibrasyon (servis)',
      'EN': 'Download generation and calibration (workshop)',
      'DE': 'Download-Generation und Kalibrierung (Werkstatt)',
    },
    'its.advGenerationTitle': {
      'TR': 'İndirme nesli',
      'EN': 'Download generation',
      'DE': 'Download-Generation',
    },
    'its.advGenerationBody': {
      'TR':
          'Takograf verisinin hangi biçimde indirileceği. Gen 2 v2 takografın tuttuğu her şeyi getirir; Gen 1 ve Gen 2 v1 yalnız eski biçimi okuyan programlar için gerekir. Kart indirmeyi etkilemez.',
      'EN':
          'The format the tachograph data is downloaded in. Gen 2 v2 brings everything the tachograph records; Gen 1 and Gen 2 v1 are only needed for programs that read the older formats. It does not affect a card download.',
      'DE':
          'Das Format, in dem die Tachographendaten heruntergeladen werden. Gen 2 v2 liefert alles, was der Tachograph aufzeichnet; Gen 1 und Gen 2 v1 sind nur für Programme nötig, die die älteren Formate lesen. Ein Kartendownload ist davon nicht betroffen.',
    },
    'its.advRecommended': {
      'TR': 'Önerilen ayar.',
      'EN': 'Recommended setting.',
      'DE': 'Empfohlene Einstellung.',
    },
    'its.advNotRecommended': {
      'TR': 'Önerilen Gen 2 v2. Bu ayar uygulama kapanınca Gen 2 v2\'ye döner.',
      'EN':
          'Gen 2 v2 is recommended. This setting returns to Gen 2 v2 when the app closes.',
      'DE':
          'Empfohlen ist Gen 2 v2. Diese Einstellung kehrt beim Schließen der App zu Gen 2 v2 zurück.',
    },
    'its.trtpNote': {
      'TR':
          'Genel bakış TRTP {overview}, aktiviteler {activities} olarak gider.',
      'EN':
          'The overview goes out as TRTP {overview}, activities as {activities}.',
      'DE':
          'Die Übersicht wird als TRTP {overview} angefordert, Aktivitäten als {activities}.',
    },
    'its.advCalibrationSubtitle': {
      'TR':
          'Servis içindir: diagnostik kanalında Ek-8 istekleri ve çözülmüş yanıtlar',
      'EN':
          'For workshops: Annex 8 requests on the diagnostics channel and their decoded answers',
      'DE':
          'Für Werkstätten: Anhang-8-Anfragen auf dem Diagnosekanal und ihre entschlüsselten Antworten',
    },
    'its.calibrationTitle': {
      'TR': 'Kalibrasyon',
      'EN': 'Calibration',
      'DE': 'Kalibrierung',
    },
    'its.openingSession': {
      'TR': 'Oturum açılıyor',
      'EN': 'Opening the session',
      'DE': 'Sitzung wird geöffnet',
    },
    'its.savedTo': {
      'TR': 'Dosyalar · {name}',
      'EN': 'Files · {name}',
      'DE': 'Dateien · {name}',
    },
    'its.noDataSession': {
      'TR': 'Oturum çalıştı ama takograf hiç veri göndermedi.',
      'EN': 'The session ran, but the tachograph sent no data at all.',
      'DE': 'Die Sitzung lief, aber der Tachograph hat keine Daten gesendet.',
    },
    'its.resultSummary': {
      'TR': '{bytes} bayt, {count} transfer',
      'EN': '{bytes} bytes, {count} transfers',
      'DE': '{bytes} Byte, {count} Übertragungen',
    },
    'its.downloadFailed': {
      'TR': 'İndirme başarısız: {problem}',
      'EN': 'Download failed: {problem}',
      'DE': 'Download fehlgeschlagen: {problem}',
    },
    'its.downloadedSaved': {
      'TR': '{bytes} bayt indirildi ve kaydedildi.',
      'EN': '{bytes} bytes downloaded and saved.',
      'DE': '{bytes} Byte heruntergeladen und gespeichert.',
    },
    'its.savedPartial': {
      'TR': '{bytes} bayt kaydedildi, eksik: {problem}',
      'EN': '{bytes} bytes saved, missing: {problem}',
      'DE': '{bytes} Byte gespeichert, fehlend: {problem}',
    },
    'its.pickFrom': {
      'TR': 'Başlangıç (UTC)',
      'EN': 'Start (UTC)',
      'DE': 'Beginn (UTC)',
    },
    'its.pickTo': {'TR': 'Bitiş (UTC)', 'EN': 'End (UTC)', 'DE': 'Ende (UTC)'},
    'its.transferOverview': {
      'TR': 'Genel bakış',
      'EN': 'Overview',
      'DE': 'Übersicht',
    },
    'its.transferActivities': {
      'TR': 'Aktiviteler',
      'EN': 'Activities',
      'DE': 'Aktivitäten',
    },
    'its.transferEvents': {
      'TR': 'Olaylar ve arızalar',
      'EN': 'Events and faults',
      'DE': 'Ereignisse und Störungen',
    },
    'its.transferSpeed': {
      'TR': 'Detaylı hız',
      'EN': 'Detailed speed',
      'DE': 'Detaillierte Geschwindigkeit',
    },
    'its.transferTechnical': {
      'TR': 'Teknik veri',
      'EN': 'Technical data',
      'DE': 'Technische Daten',
    },
    'its.transferCard': {
      'TR': 'Kart indirme',
      'EN': 'Card download',
      'DE': 'Kartendownload',
    },
    'its.channelCard': {'TR': 'Kanal', 'EN': 'Channel', 'DE': 'Kanal'},
    'its.channelHint': {
      'TR':
          'Kanalı açmak takografa 16 credit verir. 0xFF reddi ön konektörün bu arayüzü kullandığı ya da takılı kartların ITS\'e izin vermediği anlamına gelir.',
      'EN':
          'Opening the channel gives the tachograph 16 credits. A 0xFF refusal means the front connector is using this interface or the inserted cards do not allow ITS.',
      'DE':
          'Das Öffnen des Kanals gibt dem Tachographen 16 Credits. Eine 0xFF-Ablehnung bedeutet, dass der Frontstecker diese Schnittstelle nutzt oder die gesteckten Karten ITS nicht erlauben.',
    },
    'its.downloadOpen': {
      'TR': 'İndirme: açık ({credits} credit)',
      'EN': 'Download: open ({credits} credits)',
      'DE': 'Download: offen ({credits} Credits)',
    },
    'its.downloadOpening': {
      'TR': 'İndirme: açılıyor…',
      'EN': 'Download: opening…',
      'DE': 'Download: wird geöffnet…',
    },
    'its.downloadRefused': {
      'TR': 'İndirme: reddedildi (0xFF)',
      'EN': 'Download: refused (0xFF)',
      'DE': 'Download: abgelehnt (0xFF)',
    },
    'its.downloadClosed': {
      'TR': 'İndirme: kapalı',
      'EN': 'Download: closed',
      'DE': 'Download: geschlossen',
    },
    'its.close': {'TR': 'Kapat', 'EN': 'Close', 'DE': 'Schließen'},
    'its.open': {'TR': 'Aç', 'EN': 'Open', 'DE': 'Öffnen'},
    'its.sessionCard': {'TR': 'Oturum', 'EN': 'Session', 'DE': 'Sitzung'},
    'its.sessionHint': {
      'TR':
          'Bir basış bir indirme oturumudur: StartCommunication, transferler, TransferExit ve StopCommunication, hepsi tek dosyada. Genel bakış her zaman ilk gider ve çıkarılamaz: takograf sertifikalarını taşır.',
      'EN':
          'One press is one download session: StartCommunication, the transfers, TransferExit and StopCommunication, all in one file. The overview always goes first and cannot be left out: it carries the tachograph certificates.',
      'DE':
          'Ein Tippen ist eine Download-Sitzung: StartCommunication, die Übertragungen, TransferExit und StopCommunication, alles in einer Datei. Die Übersicht kommt immer zuerst und kann nicht weggelassen werden: Sie enthält die Zertifikate des Tachographen.',
    },
    'its.overviewNotWithCard': {
      'TR': 'kartla değil',
      'EN': 'not with a card',
      'DE': 'nicht mit Karte',
    },
    'its.overviewAlways': {'TR': 'her zaman', 'EN': 'always', 'DE': 'immer'},
    'its.cardOwnSession': {
      'TR':
          'Kart indirme kendi oturumu ve kendi dosyasıdır: kartın verisi, kartın sertifikalarıyla.',
      'EN':
          'A card download is a session and a file of its own: the card\'s data, with the card\'s certificates.',
      'DE':
          'Ein Kartendownload ist eine eigene Sitzung und eine eigene Datei: die Kartendaten mit den Zertifikaten der Karte.',
    },
    'its.activitiesCard': {
      'TR': 'Aktiviteler, gün gün',
      'EN': 'Activities, day by day',
      'DE': 'Aktivitäten, Tag für Tag',
    },
    'its.activitiesHint': {
      'TR':
          'Her istek tek bir takvim gününü adlandırır; bir dönem aynı oturumda gün gün istenir, en eskiden başlayarak. İki uç da dahil.',
      'EN':
          'Each request names one calendar day, so a period is asked for day by day in the same session, oldest first. Both ends are included.',
      'DE':
          'Jede Anfrage nennt einen Kalendertag; ein Zeitraum wird daher in derselben Sitzung Tag für Tag angefordert, beginnend mit dem ältesten. Beide Enden sind eingeschlossen.',
    },
    'its.unitHolds': {
      'TR': 'Takograf {from} – {to} arasını tutuyor.',
      'EN': 'The tachograph holds {from} – {to}.',
      'DE': 'Der Tachograph enthält {from} – {to}.',
    },
    'its.wholePeriod': {
      'TR': 'İndirilebilir dönemin tamamı',
      'EN': 'The whole downloadable period',
      'DE': 'Der gesamte herunterladbare Zeitraum',
    },
    'its.periodUnknown': {
      'TR':
          'Takografın indirilebilir dönemi ilk Gen 2 oturumundan sonra burada görünür.',
      'EN':
          'The tachograph\'s downloadable period appears here after the first Gen 2 session.',
      'DE':
          'Der herunterladbare Zeitraum des Tachographen erscheint hier nach der ersten Gen-2-Sitzung.',
    },
    'its.fromDate': {
      'TR': 'Başlangıç {date}',
      'EN': 'Start {date}',
      'DE': 'Beginn {date}',
    },
    'its.toDate': {
      'TR': 'Bitiş {date}',
      'EN': 'End {date}',
      'DE': 'Ende {date}',
    },
    'its.endBeforeStart': {
      'TR': 'Bitiş başlangıçtan önce olamaz.',
      'EN': 'The end cannot be before the start.',
      'DE': 'Das Ende darf nicht vor dem Beginn liegen.',
    },
    'its.daysUtc': {
      'TR': 'Günler UTC\'dir; bir oturum en fazla {days} gün ister.',
      'EN': 'Days are UTC; one session asks for at most {days} days.',
      'DE':
          'Die Tage sind in UTC; eine Sitzung fordert höchstens {days} Tage an.',
    },
    'its.runCard': {'TR': 'Çalıştır', 'EN': 'Run', 'DE': 'Ausführen'},
    'its.download': {'TR': 'İndir', 'EN': 'Download', 'DE': 'Herunterladen'},
    'its.channelClosedHint': {
      'TR': 'İndirme kanalı açık değil: yukarıdan açın.',
      'EN': 'The download channel is not open: open it above.',
      'DE': 'Der Download-Kanal ist nicht geöffnet: Öffnen Sie ihn oben.',
    },
    'its.idleStatus': {
      'TR': 'Durum: boşta · {bytes} bayt',
      'EN': 'Status: idle · {bytes} bytes',
      'DE': 'Status: bereit · {bytes} Byte',
    },
    'its.saved': {
      'TR': 'Kaydedildi: {name}',
      'EN': 'Saved: {name}',
      'DE': 'Gespeichert: {name}',
    },
    'its.transfersCard': {
      'TR': 'Transferler',
      'EN': 'Transfers',
      'DE': 'Übertragungen',
    },
    'its.filesCard': {'TR': 'Dosyalar', 'EN': 'Files', 'DE': 'Dateien'},
    'its.allFiles': {
      'TR': 'Tüm dosyalar',
      'EN': 'All files',
      'DE': 'Alle Dateien',
    },
    'its.noneYet': {'TR': 'Henüz yok.', 'EN': 'None yet.', 'DE': 'Noch keine.'},
    'its.progressOpening': {
      'TR': 'İndirme kanalı açılıyor…',
      'EN': 'Opening the download channel…',
      'DE': 'Download-Kanal wird geöffnet…',
    },
    'its.channelRefused': {
      'TR':
          'İndirme kanalı açılamadı: takograf reddetti ya da yanıt vermedi. Ön konektörden indirme sürüyor olabilir, ya da takılı kartlar ITS\'e izin vermiyor olabilir.',
      'EN':
          'The download channel could not be opened: the tachograph refused or did not answer. A download over the front connector may be running, or the inserted cards may not allow ITS.',
      'DE':
          'Der Download-Kanal konnte nicht geöffnet werden: Der Tachograph hat abgelehnt oder nicht geantwortet. Möglicherweise läuft ein Download über den Frontstecker, oder die gesteckten Karten erlauben ITS nicht.',
    },
    'its.progressCard': {
      'TR': 'Sürücü kartı indiriliyor…',
      'EN': 'Downloading the driver card…',
      'DE': 'Fahrerkarte wird heruntergeladen…',
    },
    'its.stepCard': {
      'TR': 'Kart: {result}',
      'EN': 'Card: {result}',
      'DE': 'Karte: {result}',
    },
    'its.progressNamed': {
      'TR': '{name} indiriliyor…',
      'EN': 'Downloading {name}…',
      'DE': '{name} wird heruntergeladen…',
    },
    'its.stepNamed': {
      'TR': '{name}: {result}',
      'EN': '{name}: {result}',
      'DE': '{name}: {result}',
    },
    'its.progressActivities': {
      'TR': 'Aktiviteler {day} ({n}/{total})…',
      'EN': 'Activities {day} ({n}/{total})…',
      'DE': 'Aktivitäten {day} ({n}/{total})…',
    },
    'its.stepNoAnswer': {
      'TR': '{service} yanıtsız kaldı.',
      'EN': '{service} got no answer.',
      'DE': '{service} blieb ohne Antwort.',
    },
    'its.unitSentNoData': {
      'TR': 'Takograf veri göndermedi.',
      'EN': 'The tachograph sent no data.',
      'DE': 'Der Tachograph hat keine Daten gesendet.',
    },
    'its.blockNoAnswer': {
      'TR': '{n}. blok yanıtsız',
      'EN': 'No answer to block {n}',
      'DE': 'Keine Antwort auf Block {n}',
    },
    'its.blockUnreadable': {
      'TR': '{n}. blok okunamadı',
      'EN': 'Block {n} could not be read',
      'DE': 'Block {n} konnte nicht gelesen werden',
    },
    'its.refused': {
      'TR': '{service} reddedildi: {nrc} ({code})',
      'EN': '{service} refused: {nrc} ({code})',
      'DE': '{service} abgelehnt: {nrc} ({code})',
    },
    'its.resultBytes': {
      'TR': '{bytes} bayt, {blocks} blok',
      'EN': '{bytes} bytes, {blocks} blocks',
      'DE': '{bytes} Byte, {blocks} Blöcke',
    },
    'its.serviceHex': {
      'TR': 'servis {hex}',
      'EN': 'service {hex}',
      'DE': 'Dienst {hex}',
    },
    'its.explainNotAccepted': {
      'TR':
          'Takograf operasyonel modda yalnız sürücü kartı indirmesine izin verir; kart sahibi ITS onayı vermediyse onu da reddeder. Araç verisi için atölye, şirket ya da kontrol kartı gerekir.',
      'EN':
          'In operational mode the tachograph only allows a driver card download, and refuses that too if the card holder has not given ITS consent. Vehicle data needs a workshop, company or control card.',
      'DE':
          'Im Betriebsmodus erlaubt der Tachograph nur den Download der Fahrerkarte und lehnt auch diesen ab, wenn der Karteninhaber der ITS-Nutzung nicht zugestimmt hat. Für Fahrzeugdaten ist eine Werkstatt-, Unternehmens- oder Kontrollkarte nötig.',
    },
    'its.explainNoData': {
      'TR':
          'Gönderilecek veri yok: kart indirmesinde yuvada kart yok, ya da istenen günde kayıt yok.',
      'EN':
          'Nothing to send: for a card download there is no card in the slot, or there are no records for the day asked for.',
      'DE':
          'Keine Daten zu senden: Beim Kartendownload steckt keine Karte im Schacht, oder für den angefragten Tag gibt es keine Einträge.',
    },
    'its.explainSequence': {
      'TR': 'Adımlar sırayla gitmeli; oturum baştan başlatılmalı.',
      'EN':
          'The steps have to run in order; start the session again from the top.',
      'DE':
          'Die Schritte müssen der Reihe nach laufen; starten Sie die Sitzung von vorn.',
    },
    'its.explainPersonal': {
      'TR': 'Kişisel veri: sürücü ITS onayı vermemiş olabilir.',
      'EN': 'Personal data: the driver may not have given ITS consent.',
      'DE':
          'Personenbezogene Daten: Der Fahrer hat der ITS-Nutzung möglicherweise nicht zugestimmt.',
    },
    'its.presetDefaultSession': {
      'TR': 'Varsayılan oturum',
      'EN': 'Default session',
      'DE': 'Standardsitzung',
    },
    'its.presetUndefined': {
      'TR': 'Tanımsız (F9FE)',
      'EN': 'Undefined (F9FE)',
      'DE': 'Undefiniert (F9FE)',
    },
    'its.presetRhmiSession': {
      'TR': 'RHMI oturum durumu (F211)',
      'EN': 'RHMI session status (F211)',
      'DE': 'RHMI-Sitzungsstatus (F211)',
    },
    'its.calibNothingToSend': {
      'TR': 'Gönderilecek bir şey yok: istek servis tanımlayıcısıyla başlar.',
      'EN': 'Nothing to send: a request starts with the service identifier.',
      'DE': 'Nichts zu senden: Eine Anfrage beginnt mit der Dienstkennung.',
    },
    'its.calibNotHex': {
      'TR': 'Bu bir hex dizisi değil.',
      'EN': 'This is not a hex string.',
      'DE': 'Das ist keine Hex-Folge.',
    },
    'its.calibTooLong': {
      'TR': 'Çok uzun: KWP2000 uzunluğu tek bayt.',
      'EN': 'Too long: the KWP2000 length is a single byte.',
      'DE': 'Zu lang: Die KWP2000-Länge ist ein einzelnes Byte.',
    },
    'its.calibChannelFailed': {
      'TR': 'Diagnostik kanalı açılamadı.',
      'EN': 'The diagnostics channel could not be opened.',
      'DE': 'Der Diagnosekanal konnte nicht geöffnet werden.',
    },
    'its.calibNotSent': {
      'TR': 'İstek gönderilmedi: diagnostik kanalı açılamadı.',
      'EN': 'Request not sent: the diagnostics channel could not be opened.',
      'DE':
          'Anfrage nicht gesendet: Der Diagnosekanal konnte nicht geöffnet werden.',
    },
    'its.calibNoAnswer': {
      'TR': 'Yanıt yok.',
      'EN': 'No answer.',
      'DE': 'Keine Antwort.',
    },
    'its.calibNoAnswerLong': {
      'TR': 'Yanıt yok: takograf isteği cevaplamadı.',
      'EN': 'No answer: the tachograph did not respond to the request.',
      'DE': 'Keine Antwort: Der Tachograph hat auf die Anfrage nicht reagiert.',
    },
    'its.calibPositive': {'TR': 'Olumlu', 'EN': 'Positive', 'DE': 'Positiv'},
    'its.calibRefused': {
      'TR': 'Reddedildi',
      'EN': 'Refused',
      'DE': 'Abgelehnt',
    },
    'its.calibNegative': {'TR': 'Olumsuz', 'EN': 'Negative', 'DE': 'Negativ'},
    'its.diagOpen': {
      'TR': 'Diagnostik: açık ({credits} credit)',
      'EN': 'Diagnostics: open ({credits} credits)',
      'DE': 'Diagnose: offen ({credits} Credits)',
    },
    'its.diagOpening': {
      'TR': 'Diagnostik: açılıyor…',
      'EN': 'Diagnostics: opening…',
      'DE': 'Diagnose: wird geöffnet…',
    },
    'its.diagRefused': {
      'TR': 'Diagnostik: reddedildi (0xFF)',
      'EN': 'Diagnostics: refused (0xFF)',
      'DE': 'Diagnose: abgelehnt (0xFF)',
    },
    'its.diagClosed': {
      'TR': 'Diagnostik: kapalı',
      'EN': 'Diagnostics: closed',
      'DE': 'Diagnose: geschlossen',
    },
    'its.calibRawTitle': {
      'TR': 'Diagnostik kanalında ham istek',
      'EN': 'Raw request on the diagnostics channel',
      'DE': 'Rohanfrage auf dem Diagnosekanal',
    },
    'its.calibRawHint': {
      'TR':
          'Baytlar servis tanımlayıcısıyla başlar; 80 EE F0, uzunluk ve checksum otomatik eklenir. İmzalı RHMI istekleri Uzaktan kumanda ekranındadır.',
      'EN':
          'The bytes start with the service identifier; 80 EE F0, the length and the checksum are added automatically. Signed RHMI requests are on the Remote control screen.',
      'DE':
          'Die Bytes beginnen mit der Dienstkennung; 80 EE F0, Länge und Prüfsumme werden automatisch ergänzt. Signierte RHMI-Anfragen finden Sie auf dem Bildschirm Fernbedienung.',
    },
    'its.calibSend': {'TR': 'Gönder', 'EN': 'Send', 'DE': 'Senden'},
    'its.calibPresets': {
      'TR': 'Hazır istekler',
      'EN': 'Ready-made requests',
      'DE': 'Vorlagen',
    },
    'scan.demoTitle': {
      'TR': 'Ekran görüntüsü için mi bağlanıyorsun?',
      'EN': 'Connecting for a screenshot?',
      'DE': 'Verbinden Sie sich für einen Screenshot?',
    },
    'scan.demoBody': {
      'TR':
          'Evet dersen sadece EU 2016/799 Annex 1C, Ek 8, Tablo 28\'de (ücretsiz, resmi kaynak — ISO 16844-7 değil) tanımlı alanlardan 4 tanesi okunur: VIN, tarih/saat, kilometre, izinli hız. Başka hiçbir alan sorulmaz.',
      'EN':
          'If you say yes, only 4 of the fields defined in EU 2016/799 Annex 1C, Appendix 8, Table 28 (free, official source, not ISO 16844-7) are read: VIN, date/time, odometer, authorised speed. No other field is asked for.',
      'DE':
          'Wenn Sie zustimmen, werden nur 4 der in EU 2016/799 Anhang 1C, Anlage 8, Tabelle 28 (kostenlose, amtliche Quelle, nicht ISO 16844-7) definierten Felder gelesen: VIN, Datum/Uhrzeit, Kilometerstand, zulässige Geschwindigkeit. Kein anderes Feld wird abgefragt.',
    },
    'scan.demoNo': {'TR': 'Hayır', 'EN': 'No', 'DE': 'Nein'},
    'scan.demoYes': {'TR': 'Evet', 'EN': 'Yes', 'DE': 'Ja'},
    'scan.demoDone': {
      'TR': 'Tamamlandı — Log ekranında görebilirsin.',
      'EN': 'Done. You can see it on the Log screen.',
      'DE': 'Fertig. Sie sehen es auf dem Log-Bildschirm.',
    },
    'nation.0': {
      'TR': 'Bilgi yok',
      'EN': 'No information',
      'DE': 'Keine Angabe',
    },
    'nation.1': {'TR': 'Avusturya', 'EN': 'Austria', 'DE': 'Österreich'},
    'nation.2': {'TR': 'Arnavutluk', 'EN': 'Albania', 'DE': 'Albanien'},
    'nation.3': {'TR': 'Andorra', 'EN': 'Andorra', 'DE': 'Andorra'},
    'nation.4': {'TR': 'Ermenistan', 'EN': 'Armenia', 'DE': 'Armenien'},
    'nation.5': {'TR': 'Azerbaycan', 'EN': 'Azerbaijan', 'DE': 'Aserbaidschan'},
    'nation.6': {'TR': 'Belçika', 'EN': 'Belgium', 'DE': 'Belgien'},
    'nation.7': {'TR': 'Bulgaristan', 'EN': 'Bulgaria', 'DE': 'Bulgarien'},
    'nation.8': {
      'TR': 'Bosna-Hersek',
      'EN': 'Bosnia and Herzegovina',
      'DE': 'Bosnien und Herzegowina',
    },
    'nation.9': {'TR': 'Belarus', 'EN': 'Belarus', 'DE': 'Belarus'},
    'nation.10': {'TR': 'İsviçre', 'EN': 'Switzerland', 'DE': 'Schweiz'},
    'nation.11': {'TR': 'Kıbrıs', 'EN': 'Cyprus', 'DE': 'Zypern'},
    'nation.12': {'TR': 'Çekya', 'EN': 'Czechia', 'DE': 'Tschechien'},
    'nation.13': {'TR': 'Almanya', 'EN': 'Germany', 'DE': 'Deutschland'},
    'nation.14': {'TR': 'Danimarka', 'EN': 'Denmark', 'DE': 'Dänemark'},
    'nation.15': {'TR': 'İspanya', 'EN': 'Spain', 'DE': 'Spanien'},
    'nation.16': {'TR': 'Estonya', 'EN': 'Estonia', 'DE': 'Estland'},
    'nation.17': {'TR': 'Fransa', 'EN': 'France', 'DE': 'Frankreich'},
    'nation.18': {'TR': 'Finlandiya', 'EN': 'Finland', 'DE': 'Finnland'},
    'nation.19': {
      'TR': 'Lihtenştayn',
      'EN': 'Liechtenstein',
      'DE': 'Liechtenstein',
    },
    'nation.20': {'TR': 'Faroe Adaları', 'EN': 'Faroe Islands', 'DE': 'Färöer'},
    'nation.21': {
      'TR': 'Birleşik Krallık',
      'EN': 'United Kingdom',
      'DE': 'Vereinigtes Königreich',
    },
    'nation.22': {'TR': 'Gürcistan', 'EN': 'Georgia', 'DE': 'Georgien'},
    'nation.23': {'TR': 'Yunanistan', 'EN': 'Greece', 'DE': 'Griechenland'},
    'nation.24': {'TR': 'Macaristan', 'EN': 'Hungary', 'DE': 'Ungarn'},
    'nation.25': {'TR': 'Hırvatistan', 'EN': 'Croatia', 'DE': 'Kroatien'},
    'nation.26': {'TR': 'İtalya', 'EN': 'Italy', 'DE': 'Italien'},
    'nation.27': {'TR': 'İrlanda', 'EN': 'Ireland', 'DE': 'Irland'},
    'nation.28': {'TR': 'İzlanda', 'EN': 'Iceland', 'DE': 'Island'},
    'nation.29': {'TR': 'Kazakistan', 'EN': 'Kazakhstan', 'DE': 'Kasachstan'},
    'nation.30': {'TR': 'Lüksemburg', 'EN': 'Luxembourg', 'DE': 'Luxemburg'},
    'nation.31': {'TR': 'Litvanya', 'EN': 'Lithuania', 'DE': 'Litauen'},
    'nation.32': {'TR': 'Letonya', 'EN': 'Latvia', 'DE': 'Lettland'},
    'nation.33': {'TR': 'Malta', 'EN': 'Malta', 'DE': 'Malta'},
    'nation.34': {'TR': 'Monako', 'EN': 'Monaco', 'DE': 'Monaco'},
    'nation.35': {'TR': 'Moldova', 'EN': 'Moldova', 'DE': 'Moldau'},
    'nation.36': {
      'TR': 'Kuzey Makedonya',
      'EN': 'North Macedonia',
      'DE': 'Nordmazedonien',
    },
    'nation.37': {'TR': 'Norveç', 'EN': 'Norway', 'DE': 'Norwegen'},
    'nation.38': {'TR': 'Hollanda', 'EN': 'Netherlands', 'DE': 'Niederlande'},
    'nation.39': {'TR': 'Portekiz', 'EN': 'Portugal', 'DE': 'Portugal'},
    'nation.40': {'TR': 'Polonya', 'EN': 'Poland', 'DE': 'Polen'},
    'nation.41': {'TR': 'Romanya', 'EN': 'Romania', 'DE': 'Rumänien'},
    'nation.42': {'TR': 'San Marino', 'EN': 'San Marino', 'DE': 'San Marino'},
    'nation.43': {'TR': 'Rusya', 'EN': 'Russia', 'DE': 'Russland'},
    'nation.44': {'TR': 'İsveç', 'EN': 'Sweden', 'DE': 'Schweden'},
    'nation.45': {'TR': 'Slovakya', 'EN': 'Slovakia', 'DE': 'Slowakei'},
    'nation.46': {'TR': 'Slovenya', 'EN': 'Slovenia', 'DE': 'Slowenien'},
    'nation.47': {
      'TR': 'Türkmenistan',
      'EN': 'Turkmenistan',
      'DE': 'Turkmenistan',
    },
    'nation.48': {'TR': 'Türkiye', 'EN': 'Türkiye', 'DE': 'Türkei'},
    'nation.49': {'TR': 'Ukrayna', 'EN': 'Ukraine', 'DE': 'Ukraine'},
    'nation.50': {'TR': 'Vatikan', 'EN': 'Vatican City', 'DE': 'Vatikanstadt'},
    'nation.51': {'TR': 'Yugoslavya', 'EN': 'Yugoslavia', 'DE': 'Jugoslawien'},
    'nation.52': {'TR': 'Karadağ', 'EN': 'Montenegro', 'DE': 'Montenegro'},
    'nation.53': {'TR': 'Sırbistan', 'EN': 'Serbia', 'DE': 'Serbien'},
    'nation.54': {'TR': 'Özbekistan', 'EN': 'Uzbekistan', 'DE': 'Usbekistan'},
    'nation.55': {
      'TR': 'Tacikistan',
      'EN': 'Tajikistan',
      'DE': 'Tadschikistan',
    },
    'nation.56': {'TR': 'Kırgızistan', 'EN': 'Kyrgyzstan', 'DE': 'Kirgisistan'},
    'nation.57': {'TR': 'İsrail', 'EN': 'Israel', 'DE': 'Israel'},
    'nation.253': {
      'TR': 'Avrupa Topluluğu',
      'EN': 'European Community',
      'DE': 'Europäische Gemeinschaft',
    },
    'nation.254': {
      'TR': 'Avrupa\'nın geri kalanı',
      'EN': 'Rest of Europe',
      'DE': 'Übriges Europa',
    },
    'nation.255': {
      'TR': 'Dünyanın geri kalanı',
      'EN': 'Rest of the world',
      'DE': 'Übrige Welt',
    },
    'nation.unknown': {
      'TR': 'Bilinmeyen ülke (kod {code})',
      'EN': 'Unknown country (code {code})',
      'DE': 'Unbekanntes Land (Code {code})',
    },
    'rhmi.notConnected': {
      'TR': 'Bir ATC 8256\'ya bağlı değil.',
      'EN': 'Not connected to an ATC 8256.',
      'DE': 'Nicht mit einem ATC 8256 verbunden.',
    },
    'rhmi.channelFailed': {
      'TR':
          'Diagnostik kanalı açılamadı: takograf reddetti ya da yanıt vermedi. Ön konektör kullanımda olabilir.',
      'EN':
          'The diagnostics channel could not be opened: the tachograph refused or did not answer. The front connector may be in use.',
      'DE':
          'Der Diagnosekanal konnte nicht geöffnet werden: Der Fahrtenschreiber hat abgelehnt oder nicht geantwortet. Der Frontstecker ist möglicherweise belegt.',
    },
    'rhmi.failed': {
      'TR': 'Başarısız: {error}',
      'EN': 'Failed: {error}',
      'DE': 'Fehlgeschlagen: {error}',
    },
    'rhmi.notPaired': {
      'TR': '{client} eşleştirilmemiş.',
      'EN': '{client} is not paired.',
      'DE': '{client} ist nicht gekoppelt.',
    },
    'rhmi.sessionPending': {
      'TR': 'Oturum bekliyor: takograf ekranındaki soruyu yanıtlayın.',
      'EN':
          'The session is waiting: answer the question on the tachograph display.',
      'DE':
          'Die Sitzung wartet: Beantworten Sie die Frage auf dem Display des Fahrtenschreibers.',
    },
    'rhmi.sessionRejected': {
      'TR': 'Bir kullanıcı oturumu reddetti. Oturumu kapatıp yeniden açın.',
      'EN': 'A user rejected the session. Close it and open it again.',
      'DE':
          'Ein Benutzer hat die Sitzung abgelehnt. Schließen und erneut öffnen.',
    },
    'rhmi.sessionUnknown': {
      'TR': 'Oturum durumu bilinmiyor: önce oturumu açın.',
      'EN': 'Session state unknown: open the session first.',
      'DE': 'Sitzungsstatus unbekannt: Öffnen Sie zuerst die Sitzung.',
    },
    'rhmi.sessionNotOpen': {
      'TR': 'Oturum açık değil ({status}). Önce oturumu açın.',
      'EN': 'The session is not open ({status}). Open the session first.',
      'DE':
          'Die Sitzung ist nicht offen ({status}). Öffnen Sie zuerst die Sitzung.',
    },
    'rhmi.refused': {
      'TR': 'Reddedildi: {nrc} ({code})',
      'EN': 'Refused: {nrc} ({code})',
      'DE': 'Abgelehnt: {nrc} ({code})',
    },
    'rhmi.nrc35': {
      'TR':
          'Takograf bu telefonun kimliğini tanımıyor: eşleştirme kaybolmuş ya da yuvadaki kart değişmiş. Yeniden eşleştirin.',
      'EN':
          'The tachograph does not recognise this phone\'s identifier: the pairing was lost or the card in the slot changed. Pair again.',
      'DE':
          'Der Fahrtenschreiber erkennt die Kennung dieses Telefons nicht: Die Kopplung ging verloren oder die Karte im Steckplatz wurde gewechselt. Erneut koppeln.',
    },
    'rhmi.nrc37': {
      'TR':
          'Yanlış imzalı bir istek nedeniyle takograf 10 sn boyunca RHMI isteklerini reddediyor. Bekleyip tekrar deneyin.',
      'EN':
          'Because of a wrongly signed request the tachograph refuses RHMI requests for 10 s. Wait and try again.',
      'DE':
          'Wegen einer falsch signierten Anfrage lehnt der Fahrtenschreiber 10 s lang RHMI-Anfragen ab. Warten und erneut versuchen.',
    },
    'rhmi.nrc31': {
      'TR':
          'Genellikle saat farkı: takograf ve telefon saati {seconds} sn\'den fazla farklı olabilir.',
      'EN':
          'Usually a clock difference: the tachograph and phone clocks may differ by more than {seconds} s.',
      'DE':
          'Meist ein Uhrzeitunterschied: Fahrtenschreiber- und Telefonuhr weichen möglicherweise um mehr als {seconds} s ab.',
    },
    'rhmi.nrc21': {
      'TR': 'Takografta başka bir RHMI işlemi sürüyor, tekrar deneyin.',
      'EN': 'Another RHMI operation is running on the tachograph; try again.',
      'DE':
          'Am Fahrtenschreiber läuft ein anderer RHMI-Vorgang; erneut versuchen.',
    },
    'rhmi.busyClock': {
      'TR': 'Takograf saati okunuyor',
      'EN': 'Reading the tachograph clock',
      'DE': 'Uhr des Fahrtenschreibers wird gelesen',
    },
    'rhmi.clockUnreadable': {
      'TR': 'Takograf saati okunamadı.',
      'EN': 'The tachograph clock could not be read.',
      'DE': 'Die Uhr des Fahrtenschreibers konnte nicht gelesen werden.',
    },
    'rhmi.clockAheadOk': {
      'TR': 'Takograf saati telefondan {seconds} sn ileride; tolerans içinde.',
      'EN':
          'The tachograph clock is {seconds} s ahead of the phone; within tolerance.',
      'DE':
          'Die Uhr des Fahrtenschreibers geht {seconds} s vor; innerhalb der Toleranz.',
    },
    'rhmi.clockBehindOk': {
      'TR': 'Takograf saati telefondan {seconds} sn geride; tolerans içinde.',
      'EN':
          'The tachograph clock is {seconds} s behind the phone; within tolerance.',
      'DE':
          'Die Uhr des Fahrtenschreibers geht {seconds} s nach; innerhalb der Toleranz.',
    },
    'rhmi.clockAheadOut': {
      'TR':
          'Takograf saati telefondan {seconds} sn ileride; tolerans dışında. İstekler takograf saatiyle imzalanacak.',
      'EN':
          'The tachograph clock is {seconds} s ahead of the phone; outside tolerance. Requests will be signed with the tachograph\'s time.',
      'DE':
          'Die Uhr des Fahrtenschreibers geht {seconds} s vor; außerhalb der Toleranz. Anfragen werden mit der Zeit des Fahrtenschreibers signiert.',
    },
    'rhmi.clockBehindOut': {
      'TR':
          'Takograf saati telefondan {seconds} sn geride; tolerans dışında. İstekler takograf saatiyle imzalanacak.',
      'EN':
          'The tachograph clock is {seconds} s behind the phone; outside tolerance. Requests will be signed with the tachograph\'s time.',
      'DE':
          'Die Uhr des Fahrtenschreibers geht {seconds} s nach; außerhalb der Toleranz. Anfragen werden mit der Zeit des Fahrtenschreibers signiert.',
    },
    'rhmi.busyPairing': {
      'TR': 'Eşleştiriliyor',
      'EN': 'Pairing',
      'DE': 'Kopplung läuft',
    },
    'rhmi.noAnswer': {
      'TR': 'Yanıt yok.',
      'EN': 'No answer.',
      'DE': 'Keine Antwort.',
    },
    'rhmi.pairingUnreadable': {
      'TR': 'Eşleştirme yanıtı okunamadı.',
      'EN': 'The pairing answer could not be read.',
      'DE': 'Die Kopplungsantwort konnte nicht gelesen werden.',
    },
    'rhmi.pairedPlain': {
      'TR': 'Eşleştirildi (açık aktarım, kod gerekmedi).',
      'EN': 'Paired (plain transfer, no code needed).',
      'DE': 'Gekoppelt (unverschlüsselte Übertragung, kein Code nötig).',
    },
    'rhmi.enterToken': {
      'TR': 'Takograf ekranındaki 8 haneli kodu girin.',
      'EN': 'Enter the 8-digit code shown on the tachograph display.',
      'DE':
          'Geben Sie den 8-stelligen Code vom Display des Fahrtenschreibers ein.',
    },
    'rhmi.tokenDigits': {
      'TR': 'Kod 8 rakamdan oluşur.',
      'EN': 'The code has 8 digits.',
      'DE': 'Der Code hat 8 Ziffern.',
    },
    'rhmi.tokenWrong': {
      'TR': 'Kod yanlış (doğrulama tutmadı). Tekrar girin.',
      'EN': 'Wrong code (the check did not match). Enter it again.',
      'DE': 'Falscher Code (Prüfung stimmt nicht). Erneut eingeben.',
    },
    'rhmi.paired': {
      'TR': '{client} eşleştirildi.',
      'EN': '{client} paired.',
      'DE': '{client} gekoppelt.',
    },
    'rhmi.pairingCancelled': {
      'TR': 'Eşleştirme iptal edildi.',
      'EN': 'Pairing cancelled.',
      'DE': 'Kopplung abgebrochen.',
    },
    'rhmi.pairingForgotten': {
      'TR':
          'Kimlik bu telefondan silindi. Takograf kendi kopyasını sonraki eşleştirmeye kadar tutar.',
      'EN':
          'The identifier was deleted from this phone. The tachograph keeps its own copy until the next pairing.',
      'DE':
          'Die Kennung wurde von diesem Telefon gelöscht. Der Fahrtenschreiber behält seine Kopie bis zur nächsten Kopplung.',
    },
    'rhmi.busyVerify': {
      'TR': 'Kimlik doğrulanıyor',
      'EN': 'Verifying the identifier',
      'DE': 'Kennung wird geprüft',
    },
    'rhmi.menuInUseRetry': {
      'TR': 'Takograf menüsü kullanımda; menüden çıkıp tekrar deneyin.',
      'EN': 'The tachograph menu is in use; leave the menu and try again.',
      'DE':
          'Das Menü des Fahrtenschreibers ist in Benutzung; Menü verlassen und erneut versuchen.',
    },
    'rhmi.verified': {
      'TR': 'Kimlik doğrulandı: takograf aynı kimliği tutuyor.',
      'EN': 'Identifier verified: the tachograph holds the same identifier.',
      'DE': 'Kennung bestätigt: Der Fahrtenschreiber hat dieselbe Kennung.',
    },
    'rhmi.busyOpen': {
      'TR': 'Oturum açılıyor — takograf ekranında onaylayın',
      'EN': 'Opening the session — confirm on the tachograph display',
      'DE':
          'Sitzung wird geöffnet — am Display des Fahrtenschreibers bestätigen',
    },
    'rhmi.statusUnreadable': {
      'TR': 'Durum okunamadı.',
      'EN': 'The state could not be read.',
      'DE': 'Der Status konnte nicht gelesen werden.',
    },
    'rhmi.waitTimeout': {
      'TR':
          'Bir buçuk dakikadır onay bekleniyor; takograf ekranında soru var mı?',
      'EN':
          'Waiting for confirmation for a minute and a half; is there a question on the tachograph display?',
      'DE':
          'Seit anderthalb Minuten wird auf Bestätigung gewartet; steht auf dem Display des Fahrtenschreibers eine Frage?',
    },
    'rhmi.status.open': {
      'TR': 'Oturum açık.',
      'EN': 'The session is open.',
      'DE': 'Die Sitzung ist offen.',
    },
    'rhmi.status.closedOpenPossible': {
      'TR': 'Oturum kapalı; açılabilir.',
      'EN': 'The session is closed; it can be opened.',
      'DE': 'Die Sitzung ist geschlossen; sie kann geöffnet werden.',
    },
    'rhmi.status.closedUserDecisionPending': {
      'TR': 'Takograf ekranındaki soruyu yanıtlayın.',
      'EN': 'Answer the question on the tachograph display.',
      'DE': 'Beantworten Sie die Frage auf dem Display des Fahrtenschreibers.',
    },
    'rhmi.status.closedUserRejected': {
      'TR':
          'Reddedildi (ya da soru 25 sn içinde yanıtlanmadı). Kapatıp yeniden açın ve takografta Evet deyin.',
      'EN':
          'Rejected (or the question was not answered within 25 s). Close, open again and answer Yes on the tachograph.',
      'DE':
          'Abgelehnt (oder die Frage wurde nicht innerhalb von 25 s beantwortet). Schließen, erneut öffnen und am Fahrtenschreiber mit Ja antworten.',
    },
    'rhmi.status.closedLocalHmiIsUsed': {
      'TR': 'Takograf menüsü kullanımda; menüden çıkıp yeniden açın.',
      'EN': 'The tachograph menu is in use; leave the menu and open again.',
      'DE':
          'Das Menü des Fahrtenschreibers ist in Benutzung; Menü verlassen und erneut öffnen.',
    },
    'rhmi.status.closedGeneralConditionsNotMet': {
      'TR':
          'Geçerli bir sürücü ya da atölye kartı hazır değil; kart doğrulanınca yeniden açın.',
      'EN':
          'No valid driver or workshop card is ready; open again once the card is verified.',
      'DE':
          'Keine gültige Fahrer- oder Werkstattkarte bereit; nach Prüfung der Karte erneut öffnen.',
    },
    'rhmi.session.open': {'TR': 'Açık', 'EN': 'Open', 'DE': 'Offen'},
    'rhmi.session.closedOpenPossible': {
      'TR': 'Kapalı, açılabilir',
      'EN': 'Closed, can be opened',
      'DE': 'Geschlossen, kann geöffnet werden',
    },
    'rhmi.session.closedUserDecisionPending': {
      'TR': 'Takograf ekranında onay bekleniyor',
      'EN': 'Waiting for confirmation on the tachograph display',
      'DE': 'Wartet auf Bestätigung am Display des Fahrtenschreibers',
    },
    'rhmi.session.closedUserRejected': {
      'TR': 'Kapalı, bir kullanıcı reddetti',
      'EN': 'Closed, a user rejected it',
      'DE': 'Geschlossen, von einem Benutzer abgelehnt',
    },
    'rhmi.session.closedLocalHmiIsUsed': {
      'TR': 'Kapalı, takograf menüsü kullanımda',
      'EN': 'Closed, the tachograph menu is in use',
      'DE': 'Geschlossen, Menü des Fahrtenschreibers in Benutzung',
    },
    'rhmi.session.closedGeneralConditionsNotMet': {
      'TR': 'Kapalı, koşullar sağlanmıyor',
      'EN': 'Closed, conditions not met',
      'DE': 'Geschlossen, Bedingungen nicht erfüllt',
    },
    'rhmi.busyStatus': {
      'TR': 'Oturum durumu okunuyor',
      'EN': 'Reading the session state',
      'DE': 'Sitzungsstatus wird gelesen',
    },
    'rhmi.busyClose': {
      'TR': 'Oturum kapatılıyor',
      'EN': 'Closing the session',
      'DE': 'Sitzung wird geschlossen',
    },
    'rhmi.sessionClosed': {
      'TR': 'Oturum kapatıldı.',
      'EN': 'Session closed.',
      'DE': 'Sitzung geschlossen.',
    },
    'rhmi.busyCardType': {
      'TR': 'Kart tipi okunuyor',
      'EN': 'Reading the card type',
      'DE': 'Kartentyp wird gelesen',
    },
    'rhmi.shortAnswer': {
      'TR': 'Yanıt kısa.',
      'EN': 'The answer is too short.',
      'DE': 'Die Antwort ist zu kurz.',
    },
    'rhmi.cardDriver': {
      'TR': 'Sürücü kartı',
      'EN': 'Driver card',
      'DE': 'Fahrerkarte',
    },
    'rhmi.cardWorkshop': {
      'TR': 'Atölye kartı',
      'EN': 'Workshop card',
      'DE': 'Werkstattkarte',
    },
    'rhmi.cardOther': {
      'TR': 'Kart tipi {code}',
      'EN': 'Card type {code}',
      'DE': 'Kartentyp {code}',
    },
    'rhmi.busyPeriod': {
      'TR': 'Manuel giriş dönemi okunuyor',
      'EN': 'Reading the manual entry period',
      'DE': 'Zeitraum der manuellen Eingabe wird gelesen',
    },
    'rhmi.periodTooShort': {
      'TR': 'Dönem bir dakikadan kısa; girilecek bir şey yok.',
      'EN': 'The period is shorter than a minute; there is nothing to enter.',
      'DE': 'Der Zeitraum ist kürzer als eine Minute; nichts einzugeben.',
    },
    'rhmi.periodMinutes': {
      'TR': 'Dönem {minutes} dakika.',
      'EN': 'The period is {minutes} minutes.',
      'DE': 'Der Zeitraum beträgt {minutes} Minuten.',
    },
    'rhmi.periodNotExpected': {
      'TR':
          'Takograf manuel giriş beklemiyor: yuva {slot} için kart takma işlemi sürmüyor. Kartı takıp takograf boşluğu sorarken tekrar deneyin.',
      'EN':
          'The tachograph is not expecting a manual entry: no card insertion is running for slot {slot}. Insert the card and try again while the tachograph asks about the gap.',
      'DE':
          'Der Fahrtenschreiber erwartet keine manuelle Eingabe: Für Steckplatz {slot} läuft kein Kartensteckvorgang. Karte stecken und erneut versuchen, während der Fahrtenschreiber nach der Lücke fragt.',
    },
    'rhmi.periodUnreadable': {
      'TR': 'Dönem yanıtı okunamadı.',
      'EN': 'The period answer could not be read.',
      'DE': 'Die Zeitraumantwort konnte nicht gelesen werden.',
    },
    'rhmi.busySendEntry': {
      'TR': 'Manuel giriş gönderiliyor',
      'EN': 'Sending the manual entry',
      'DE': 'Manuelle Eingabe wird gesendet',
    },
    'rhmi.entryNeedsActivity': {
      'TR': 'En az bir aktivite ekleyin.',
      'EN': 'Add at least one activity.',
      'DE': 'Mindestens eine Tätigkeit hinzufügen.',
    },
    'rhmi.entryReadPeriodFirst': {
      'TR': 'Önce dönemi okuyun.',
      'EN': 'Read the period first.',
      'DE': 'Lesen Sie zuerst den Zeitraum.',
    },
    'rhmi.entryDoesNotFit': {
      'TR':
          'Yeni dönem {minutes} dakika ve hazırlanan giriş sığmıyor: {reason}.',
      'EN':
          'The new period is {minutes} minutes and the prepared entry does not fit: {reason}.',
      'DE':
          'Der neue Zeitraum beträgt {minutes} Minuten und die vorbereitete Eingabe passt nicht: {reason}.',
    },
    'rhmi.entryAccepted': {
      'TR': 'Kabul edildi: {activities} aktivite, {places} yer.',
      'EN': 'Accepted: {activities} activities, {places} places.',
      'DE': 'Angenommen: {activities} Tätigkeiten, {places} Orte.',
    },
    'rhmi.entryClosed': {
      'TR':
          'Takograf artık giriş almıyor: kart takıldıktan sonraki bir dakika geçti, ya da takograf ekranından yanıt verilmeye başlandı. Kartı çıkarıp tekrar takın ve ilk dakikada gönderin.',
      'EN':
          'The tachograph no longer takes entries: the minute after card insertion has passed, or someone started answering on the tachograph display. Remove and reinsert the card and send within the first minute.',
      'DE':
          'Der Fahrtenschreiber nimmt keine Eingaben mehr an: Die Minute nach dem Stecken der Karte ist vorbei, oder am Display wurde bereits geantwortet. Karte entnehmen, erneut stecken und in der ersten Minute senden.',
    },
    'rhmi.entryOutOfRange': {
      'TR':
          'Giriş takografın kabul etmediği bir şey içeriyor: ülkesiz yer, dönemin son dakikasında bitiş yeri, sırasız yerler ya da dönem dışında aktivite.',
      'EN':
          'The entry contains something the tachograph does not accept: a place without a country, an end place in the last minute of the period, places out of order or an activity outside the period.',
      'DE':
          'Die Eingabe enthält etwas, das der Fahrtenschreiber nicht annimmt: einen Ort ohne Land, einen Endort in der letzten Minute des Zeitraums, Orte in falscher Reihenfolge oder eine Tätigkeit außerhalb des Zeitraums.',
    },
    'rhmi.busyStopEntry': {
      'TR': 'Manuel giriş bitiriliyor',
      'EN': 'Ending the manual entry',
      'DE': 'Manuelle Eingabe wird beendet',
    },
    'rhmi.entryStopped': {
      'TR': 'Manuel giriş bitirildi.',
      'EN': 'Manual entry ended.',
      'DE': 'Manuelle Eingabe beendet.',
    },
    'rhmi.whatPlaceBegin': {
      'TR': 'Başlangıç yeri',
      'EN': 'Start place',
      'DE': 'Beginnort',
    },
    'rhmi.whatPlaceEnd': {
      'TR': 'Bitiş yeri',
      'EN': 'End place',
      'DE': 'Endort',
    },
    'rhmi.placeSaved': {
      'TR': 'Yer VU\'da ve yuva {slot} kartında kaydedildi.',
      'EN': 'Place recorded in the VU and on the card in slot {slot}.',
      'DE': 'Ort in der VU und auf der Karte in Steckplatz {slot} gespeichert.',
    },
    'rhmi.whatCondition': {
      'TR': 'Özel durum',
      'EN': 'Specific condition',
      'DE': 'Besondere Bedingung',
    },
    'rhmi.conditionSaved': {
      'TR': 'Özel durum VU\'da ve takılı kartlarda kaydedildi.',
      'EN': 'Specific condition recorded in the VU and on the inserted cards.',
      'DE':
          'Besondere Bedingung in der VU und auf den gesteckten Karten gespeichert.',
    },
    'rhmi.whatActivity': {
      'TR': 'Aktivite',
      'EN': 'Activity',
      'DE': 'Tätigkeit',
    },
    'rhmi.activitySaved': {
      'TR': 'Aktivite değiştirildi; VU\'da ve kartta kaydedildi.',
      'EN': 'Activity changed; recorded in the VU and on the card.',
      'DE': 'Tätigkeit geändert; in der VU und auf der Karte gespeichert.',
    },
    'rhmi.whatLoad': {
      'TR': 'Yükleme/boşaltma',
      'EN': 'Load/unload',
      'DE': 'Beladen/Entladen',
    },
    'rhmi.loadSaved': {
      'TR': 'Yükleme/boşaltma VU\'da kaydedildi.',
      'EN': 'Load/unload recorded in the VU.',
      'DE': 'Beladen/Entladen in der VU gespeichert.',
    },
    'rhmi.busySending': {
      'TR': '{what} gönderiliyor',
      'EN': 'Sending: {what}',
      'DE': 'Wird gesendet: {what}',
    },
    'rhmi.entryNotPossible': {
      'TR':
          'Şu an mümkün değil: yuvada kart yok, kart takılıyor/çıkarılıyor, araç hareket halinde, ya da aynı türden bir giriş bu dakika zaten yapıldı.',
      'EN':
          'Not possible right now: no card in the slot, a card is being inserted/removed, the vehicle is moving, or an entry of the same kind was already made this minute.',
      'DE':
          'Derzeit nicht möglich: keine Karte im Steckplatz, eine Karte wird gesteckt/entnommen, das Fahrzeug fährt oder eine gleichartige Eingabe wurde in dieser Minute bereits gemacht.',
    },
    'rhmi.busyWithdraw': {
      'TR': 'Kart çıkarılıyor',
      'EN': 'Withdrawing the card',
      'DE': 'Karte wird entnommen',
    },
    'rhmi.withdraw21': {
      'TR':
          'Şu an mümkün değil: diğer kart takılıyor/çıkarılıyor, gece yarısı işlemleri ya da yazıcı kullanımda.',
      'EN':
          'Not possible right now: the other card is being inserted/removed, midnight processing is running, or the printer is in use.',
      'DE':
          'Derzeit nicht möglich: Die andere Karte wird gesteckt/entnommen, die Mitternachtsverarbeitung läuft oder der Drucker ist in Benutzung.',
    },
    'rhmi.withdraw22': {
      'TR':
          'Mümkün değil: yuvada kart yok ya da kart işleniyor, araç hareket halinde, ya da çıktı istendiyse kağıt yok.',
      'EN':
          'Not possible: no card in the slot or the card is being processed, the vehicle is moving, or a printout was requested and there is no paper.',
      'DE':
          'Nicht möglich: keine Karte im Steckplatz oder die Karte wird verarbeitet, das Fahrzeug fährt oder es wurde ein Ausdruck angefordert und kein Papier ist da.',
    },
    'rhmi.withdraw31': {
      'TR':
          'Aralık dışı: ülke yok, bölge ülkeye uymuyor ya da saat farkı fazla.',
      'EN':
          'Out of range: no country, the region does not match the country, or the clock difference is too large.',
      'DE':
          'Außerhalb des Bereichs: kein Land, Region passt nicht zum Land oder Uhrzeitunterschied zu groß.',
    },
    'rhmi.withdrawn': {
      'TR':
          'Kart çıkarıldı; oturum kapandı. Yuva {slot} kimliği kartla gitti: sonraki takmada yeniden eşleştirin.',
      'EN':
          'Card withdrawn; the session closed. The slot {slot} identifier left with the card: pair again on the next insertion.',
      'DE':
          'Karte entnommen; Sitzung geschlossen. Die Kennung von Steckplatz {slot} ist mit der Karte weg: beim nächsten Stecken erneut koppeln.',
    },
    'rhmi.withdrawPending': {
      'TR':
          'Çıkarma kabul edildi, ama oturum üç dakikadır açık: kart henüz çıkmamış olabilir (çıktı, kağıt bitti).',
      'EN':
          'Withdrawal accepted, but the session has been open for three minutes: the card may not be out yet (printout, paper end).',
      'DE':
          'Entnahme angenommen, aber die Sitzung ist seit drei Minuten offen: Die Karte ist eventuell noch nicht draußen (Ausdruck, Papierende).',
    },
    'rhmi.busyWarnings': {
      'TR': 'Uyarılar okunuyor',
      'EN': 'Reading warnings',
      'DE': 'Warnungen werden gelesen',
    },
    'rhmi.warningsUnreadable': {
      'TR': 'Uyarılar okunamadı.',
      'EN': 'The warnings could not be read.',
      'DE': 'Die Warnungen konnten nicht gelesen werden.',
    },
    'rhmi.busyAck': {
      'TR': 'Uyarı onaylanıyor',
      'EN': 'Acknowledging the warning',
      'DE': 'Warnung wird quittiert',
    },
    'rhmi.ack21': {
      'TR': 'Önceki onay sürüyor, tekrar deneyin.',
      'EN': 'The previous acknowledgement is still running; try again.',
      'DE': 'Die vorherige Quittierung läuft noch; erneut versuchen.',
    },
    'rhmi.ack31': {
      'TR': 'Uyarı artık takografta yok.',
      'EN': 'The warning is no longer on the tachograph.',
      'DE': 'Die Warnung ist nicht mehr im Fahrtenschreiber.',
    },
    'rhmi.acknowledged': {
      'TR': 'Uyarı onaylandı.',
      'EN': 'Warning acknowledged.',
      'DE': 'Warnung quittiert.',
    },
    'rhmi.noWarnings': {
      'TR': 'Takografta bekleyen uyarı yok.',
      'EN': 'No warnings pending on the tachograph.',
      'DE': 'Keine offenen Warnungen im Fahrtenschreiber.',
    },
    'rhmi.warningsPending': {
      'TR': '{count} uyarı bekliyor.',
      'EN': '{count} warnings pending.',
      'DE': '{count} Warnungen offen.',
    },
    'rhmi.busyPrintDays': {
      'TR': 'Çıktı günleri okunuyor',
      'EN': 'Reading the printout days',
      'DE': 'Ausdrucktage werden gelesen',
    },
    'rhmi.printNoDate': {
      'TR': 'Bu çıktı tarih istemez.',
      'EN': 'This printout needs no date.',
      'DE': 'Dieser Ausdruck braucht kein Datum.',
    },
    'rhmi.printNoDays': {
      'TR': 'Yazdırılacak gün yok.',
      'EN': 'No days to print.',
      'DE': 'Keine Tage zum Drucken.',
    },
    'rhmi.printDays': {
      'TR': 'Günler: {from} – {to}',
      'EN': 'Days: {from} – {to}',
      'DE': 'Tage: {from} – {to}',
    },
    'rhmi.busyPrinting': {
      'TR': 'Yazdırılıyor',
      'EN': 'Printing',
      'DE': 'Wird gedruckt',
    },
    'rhmi.printPickDay': {
      'TR': 'Önce bir gün seçin.',
      'EN': 'Pick a day first.',
      'DE': 'Wählen Sie zuerst einen Tag.',
    },
    'rhmi.printStartedUnknown': {
      'TR': 'Başladı, ama durum okunamadı.',
      'EN': 'Started, but the state could not be read.',
      'DE': 'Gestartet, aber der Status konnte nicht gelesen werden.',
    },
    'rhmi.printLong': {
      'TR': 'Başladı; beş dakikadır yazdırıyor.',
      'EN': 'Started; it has been printing for five minutes.',
      'DE': 'Gestartet; druckt seit fünf Minuten.',
    },
    'rhmi.busyPrintStatus': {
      'TR': 'Çıktı durumu okunuyor',
      'EN': 'Reading the printout state',
      'DE': 'Ausdruckstatus wird gelesen',
    },
    'rhmi.printFromUnit': {
      'TR': 'Takografta başlatılan çıktı',
      'EN': 'The printout started on the tachograph',
      'DE': 'Der am Fahrtenschreiber gestartete Ausdruck',
    },
    'rhmi.printDone': {
      'TR': '{what} tamamlandı.',
      'EN': '{what}: done.',
      'DE': '{what}: abgeschlossen.',
    },
    'rhmi.printAbnormal': {
      'TR':
          '{what} tamamlanmadı: yazıcı sıcak, düşük voltaj, kağıt bitti, iptal ya da yazıcı arızası.',
      'EN':
          '{what}: not completed: printer hot, low voltage, paper end, cancelled or printer fault.',
      'DE':
          '{what}: nicht abgeschlossen: Drucker heiß, Unterspannung, Papierende, abgebrochen oder Druckerstörung.',
    },
    'rhmi.printOngoing': {
      'TR': '{what} yazdırılıyor.',
      'EN': '{what}: printing.',
      'DE': '{what}: wird gedruckt.',
    },
    'rhmi.printNone': {
      'TR': 'Takograf açıldığından beri çıktı yok.',
      'EN': 'No printout since the tachograph was switched on.',
      'DE': 'Kein Ausdruck seit dem Einschalten des Fahrtenschreibers.',
    },
    'rhmi.printUnknownStatus': {
      'TR': 'Bilinmeyen çıktı durumu {code} ({end}).',
      'EN': 'Unknown printout state {code} ({end}).',
      'DE': 'Unbekannter Ausdruckstatus {code} ({end}).',
    },
    'rhmi.print21': {
      'TR': 'Takografta bir çıktı zaten sürüyor.',
      'EN': 'A printout is already running on the tachograph.',
      'DE': 'Am Fahrtenschreiber läuft bereits ein Ausdruck.',
    },
    'rhmi.print22': {
      'TR':
          'Şu an mümkün değil: oturum kapalı, ilgili yuvada geçerli kart yok, kart takma işlemi bitmemiş, araç hareket halinde ya da kağıt yok.',
      'EN':
          'Not possible right now: the session is closed, no valid card in the slot concerned, card insertion has not finished, the vehicle is moving, or there is no paper.',
      'DE':
          'Derzeit nicht möglich: Sitzung geschlossen, keine gültige Karte im betreffenden Steckplatz, Kartensteckvorgang nicht abgeschlossen, Fahrzeug fährt oder kein Papier.',
    },
    'rhmi.print31': {
      'TR':
          'O gün için kayıt yok, bu tip yazdırılmıyor ya da saat farkı fazla.',
      'EN':
          'No records for that day, this type cannot be printed, or the clock difference is too large.',
      'DE':
          'Keine Daten für diesen Tag, dieser Typ ist nicht druckbar oder der Uhrzeitunterschied ist zu groß.',
    },
    'rhmi.client.vehicle': {
      'TR': 'Araç içi',
      'EN': 'In-vehicle',
      'DE': 'Im Fahrzeug',
    },
    'rhmi.client.slot1': {
      'TR': 'Yuva 1 (sürücü)',
      'EN': 'Slot 1 (driver)',
      'DE': 'Steckplatz 1 (Fahrer)',
    },
    'rhmi.client.slot2': {
      'TR': 'Yuva 2 (yardımcı sürücü)',
      'EN': 'Slot 2 (co-driver)',
      'DE': 'Steckplatz 2 (Beifahrer)',
    },
    'rhmi.client.other': {
      'TR': 'İstemci {n}',
      'EN': 'Client {n}',
      'DE': 'Client {n}',
    },
    'rhmi.printout.1': {
      'TR': 'Sürücü aktiviteleri (kart), günlük',
      'EN': 'Driver activities (card), daily',
      'DE': 'Fahrertätigkeiten (Karte), täglich',
    },
    'rhmi.printout.2': {
      'TR': 'Yardımcı sürücü aktiviteleri (kart), günlük',
      'EN': 'Co-driver activities (card), daily',
      'DE': 'Beifahrertätigkeiten (Karte), täglich',
    },
    'rhmi.printout.3': {
      'TR': 'Sürücü olay ve arızaları (kart)',
      'EN': 'Driver events and faults (card)',
      'DE': 'Ereignisse und Störungen Fahrer (Karte)',
    },
    'rhmi.printout.4': {
      'TR': 'Yardımcı sürücü olay ve arızaları (kart)',
      'EN': 'Co-driver events and faults (card)',
      'DE': 'Ereignisse und Störungen Beifahrer (Karte)',
    },
    'rhmi.printout.5': {
      'TR': 'Sürücü aktiviteleri (VU), günlük',
      'EN': 'Driver activities (VU), daily',
      'DE': 'Fahrertätigkeiten (VU), täglich',
    },
    'rhmi.printout.6': {
      'TR': 'VU olay ve arızaları',
      'EN': 'VU events and faults',
      'DE': 'Ereignisse und Störungen VU',
    },
    'rhmi.printout.7': {
      'TR': 'Teknik veri',
      'EN': 'Technical data',
      'DE': 'Technische Daten',
    },
    'rhmi.printout.8': {
      'TR': 'Hız aşımı',
      'EN': 'Overspeeding',
      'DE': 'Geschwindigkeitsüberschreitung',
    },
    'rhmi.printout.other': {
      'TR': 'tip {code}',
      'EN': 'type {code}',
      'DE': 'Typ {code}',
    },
    'rhmi.ef.security': {
      'TR': 'güvenlik ihlali girişimi',
      'EN': 'security breach attempt',
      'DE': 'Versuch einer Sicherheitsverletzung',
    },
    'rhmi.ef.drivingTime': {
      'TR': 'sürüş / dinlenme süresi uyarısı',
      'EN': 'driving / rest time warning',
      'DE': 'Warnung Lenk-/Ruhezeit',
    },
    'rhmi.ef.other': {
      'TR': 'kod {code}',
      'EN': 'code {code}',
      'DE': 'Code {code}',
    },
    'rhmi.ef.00': {
      'TR': 'ayrıntı yok',
      'EN': 'no further details',
      'DE': 'keine nähere Angabe',
    },
    'rhmi.ef.01': {
      'TR': 'geçersiz kart takıldı',
      'EN': 'invalid card inserted',
      'DE': 'ungültige Karte gesteckt',
    },
    'rhmi.ef.02': {
      'TR': 'kart çakışması',
      'EN': 'card conflict',
      'DE': 'Kartenkonflikt',
    },
    'rhmi.ef.03': {
      'TR': 'zaman çakışması',
      'EN': 'time overlap',
      'DE': 'Zeitüberschneidung',
    },
    'rhmi.ef.04': {
      'TR': 'uygun kart olmadan sürüş',
      'EN': 'driving without an appropriate card',
      'DE': 'Fahren ohne gültige Karte',
    },
    'rhmi.ef.05': {
      'TR': 'sürüş sırasında kart takıldı',
      'EN': 'card inserted while driving',
      'DE': 'Karte während der Fahrt gesteckt',
    },
    'rhmi.ef.06': {
      'TR': 'son kart oturumu düzgün kapanmadı',
      'EN': 'last card session not closed correctly',
      'DE': 'letzter Kartenvorgang nicht korrekt abgeschlossen',
    },
    'rhmi.ef.07': {
      'TR': 'hız aşımı',
      'EN': 'overspeeding',
      'DE': 'Geschwindigkeitsüberschreitung',
    },
    'rhmi.ef.08': {
      'TR': 'güç kesintisi',
      'EN': 'power supply interruption',
      'DE': 'Unterbrechung der Stromversorgung',
    },
    'rhmi.ef.09': {
      'TR': 'hareket verisi hatası',
      'EN': 'motion data error',
      'DE': 'Bewegungsdatenfehler',
    },
    'rhmi.ef.0A': {
      'TR': 'araç hareketi çakışması',
      'EN': 'vehicle motion conflict',
      'DE': 'Konflikt Fahrzeugbewegung',
    },
    'rhmi.ef.0B': {
      'TR': 'zaman çakışması (GNSS / VU saati)',
      'EN': 'time conflict (GNSS / VU clock)',
      'DE': 'Zeitkonflikt (GNSS / VU-Uhr)',
    },
    'rhmi.ef.0C': {
      'TR': 'uzak iletişim birimi hatası',
      'EN': 'remote communication unit error',
      'DE': 'Fehler der Fernkommunikationseinrichtung',
    },
    'rhmi.ef.0D': {
      'TR': 'GNSS konum bilgisi yok',
      'EN': 'no GNSS position',
      'DE': 'keine GNSS-Positionsdaten',
    },
    'rhmi.ef.0E': {
      'TR': 'harici GNSS birimi hatası',
      'EN': 'external GNSS unit error',
      'DE': 'Fehler der externen GNSS-Einrichtung',
    },
    'rhmi.ef.30': {
      'TR': 'kayıt cihazı arızası',
      'EN': 'recording equipment fault',
      'DE': 'Störung des Kontrollgeräts',
    },
    'rhmi.ef.31': {
      'TR': 'VU iç arızası',
      'EN': 'VU internal fault',
      'DE': 'interne VU-Störung',
    },
    'rhmi.ef.32': {
      'TR': 'yazıcı arızası',
      'EN': 'printer fault',
      'DE': 'Druckerstörung',
    },
    'rhmi.ef.33': {
      'TR': 'ekran arızası',
      'EN': 'display fault',
      'DE': 'Anzeigestörung',
    },
    'rhmi.ef.34': {
      'TR': 'indirme arızası',
      'EN': 'download fault',
      'DE': 'Störung beim Herunterladen',
    },
    'rhmi.ef.35': {
      'TR': 'sensör arızası',
      'EN': 'sensor fault',
      'DE': 'Sensorstörung',
    },
    'rhmi.ef.36': {
      'TR': 'dahili GNSS alıcısı',
      'EN': 'internal GNSS receiver',
      'DE': 'interner GNSS-Empfänger',
    },
    'rhmi.ef.37': {
      'TR': 'harici GNSS birimi',
      'EN': 'external GNSS unit',
      'DE': 'externe GNSS-Einrichtung',
    },
    'rhmi.ef.38': {
      'TR': 'uzak iletişim birimi',
      'EN': 'remote communication unit',
      'DE': 'Fernkommunikationseinrichtung',
    },
    'rhmi.ef.39': {
      'TR': 'ITS arayüzü',
      'EN': 'ITS interface',
      'DE': 'ITS-Schnittstelle',
    },
    'rhmi.ef.40': {
      'TR': 'kart arızası',
      'EN': 'card fault',
      'DE': 'Kartenstörung',
    },
    'rhmi.ef.81': {
      'TR': 'hız aşımı ön uyarısı',
      'EN': 'overspeed pre-warning',
      'DE': 'Vorwarnung Geschwindigkeitsüberschreitung',
    },
    'rhmi.ef.82': {
      'TR': 'kart süresi doluyor',
      'EN': 'card expiring',
      'DE': 'Karte läuft ab',
    },
    'rhmi.ef.83': {
      'TR': 'kalibrasyon / servis zamanı',
      'EN': 'calibration / service due',
      'DE': 'Kalibrierung / Service fällig',
    },
    'rhmi.ef.86': {
      'TR': 'yanlış kart tipi',
      'EN': 'wrong card type',
      'DE': 'falscher Kartentyp',
    },
    'rhmi.ef.87': {
      'TR': 'PIN bloke',
      'EN': 'PIN blocked',
      'DE': 'PIN gesperrt',
    },
    'rhmi.ef.88': {
      'TR': 'kayıt tutarsız',
      'EN': 'inconsistent record',
      'DE': 'Datensatz inkonsistent',
    },
    'rhmi.ef.92': {
      'TR': 'kart indirme zamanı',
      'EN': 'card download due',
      'DE': 'Kartendownload fällig',
    },
    'rhmi.ef.93': {
      'TR': 'VU indirme zamanı',
      'EN': 'VU download due',
      'DE': 'VU-Download fällig',
    },
    'rhmi.ef.AE': {
      'TR': 'kontakta kart yok',
      'EN': 'no card with ignition on',
      'DE': 'keine Karte bei eingeschalteter Zündung',
    },
    'rhmi.me.needActivity': {
      'TR': 'en az bir aktivite gerekli',
      'EN': 'at least one activity is needed',
      'DE': 'mindestens eine Tätigkeit nötig',
    },
    'rhmi.me.maxActivities': {
      'TR': 'en fazla {max} aktivite',
      'EN': 'at most {max} activities',
      'DE': 'höchstens {max} Tätigkeiten',
    },
    'rhmi.me.maxPlaces': {
      'TR': 'en fazla {max} yer',
      'EN': 'at most {max} places',
      'DE': 'höchstens {max} Orte',
    },
    'rhmi.me.actBeforePeriod': {
      'TR': '{n}. aktivite dönemden önce başlıyor',
      'EN': 'activity {n} starts before the period',
      'DE': 'Tätigkeit {n} beginnt vor dem Zeitraum',
    },
    'rhmi.me.actAtEnd': {
      'TR': '{n}. aktivite dönem bitiminde ya da sonrasında',
      'EN': 'activity {n} is at or after the end of the period',
      'DE': 'Tätigkeit {n} liegt am oder nach dem Ende des Zeitraums',
    },
    'rhmi.me.actOrder': {
      'TR': '{n}. aktivite öncekinden sonra başlamıyor',
      'EN': 'activity {n} does not start after the previous one',
      'DE': 'Tätigkeit {n} beginnt nicht nach der vorherigen',
    },
    'rhmi.me.placeBefore': {
      'TR': '{n}. yer dönemden önce',
      'EN': 'place {n} is before the period',
      'DE': 'Ort {n} liegt vor dem Zeitraum',
    },
    'rhmi.me.placeNoCountry': {
      'TR': '{n}. yerin ülkesi yok',
      'EN': 'place {n} has no country',
      'DE': 'Ort {n} hat kein Land',
    },
    'rhmi.me.placeAfter': {
      'TR': '{n}. yer dönemden sonra',
      'EN': 'place {n} is after the period',
      'DE': 'Ort {n} liegt nach dem Zeitraum',
    },
    'rhmi.me.placeOrder': {
      'TR': '{n}. yer öncekinden önce',
      'EN': 'place {n} is before the previous one',
      'DE': 'Ort {n} liegt vor dem vorherigen',
    },
    'rhmi.me.placeSameMinute': {
      'TR': '{n}. yer öncekiyle aynı dakikada',
      'EN': 'place {n} is in the same minute as the previous one',
      'DE': 'Ort {n} liegt in derselben Minute wie der vorherige',
    },
    'rhmi.activity.rest': {
      'TR': 'Dinlenme / mola',
      'EN': 'Rest / break',
      'DE': 'Ruhezeit / Pause',
    },
    'rhmi.activity.available': {
      'TR': 'Hazır bulunma',
      'EN': 'Availability',
      'DE': 'Bereitschaft',
    },
    'rhmi.activity.work': {
      'TR': 'Diğer iş',
      'EN': 'Other work',
      'DE': 'Andere Arbeit',
    },
    'rhmi.activity.unknown': {
      'TR': 'Bilinmiyor',
      'EN': 'Unknown',
      'DE': 'Unbekannt',
    },
    'rhmi.ui.tokenTitle': {
      'TR': 'Eşleştirme kodu',
      'EN': 'Pairing code',
      'DE': 'Kopplungscode',
    },
    'rhmi.ui.tokenHint': {
      'TR': 'Takograf ekranındaki 8 hane',
      'EN': 'The 8 digits on the tachograph display',
      'DE': 'Die 8 Ziffern auf dem Display des Fahrtenschreibers',
    },
    'rhmi.ui.cancel': {'TR': 'İptal', 'EN': 'Cancel', 'DE': 'Abbrechen'},
    'rhmi.ui.confirm': {'TR': 'Onayla', 'EN': 'Confirm', 'DE': 'Bestätigen'},
    'rhmi.ui.secPairing': {
      'TR': 'Eşleştirme',
      'EN': 'Pairing',
      'DE': 'Kopplung',
    },
    'rhmi.ui.secLive': {
      'TR': 'Canlı girişler',
      'EN': 'Live entries',
      'DE': 'Live-Eingaben',
    },
    'rhmi.ui.secWarnings': {
      'TR': 'Uyarılar',
      'EN': 'Warnings',
      'DE': 'Warnungen',
    },
    'rhmi.ui.secPrintout': {'TR': 'Çıktı', 'EN': 'Printout', 'DE': 'Ausdruck'},
    'rhmi.ui.secWithdraw': {
      'TR': 'Kart çıkarma',
      'EN': 'Card withdrawal',
      'DE': 'Kartenentnahme',
    },
    'rhmi.ui.secManual': {
      'TR': 'Manuel giriş',
      'EN': 'Manual entry',
      'DE': 'Manuelle Eingabe',
    },
    'rhmi.ui.slot': {
      'TR': 'Yuva {n}',
      'EN': 'Slot {n}',
      'DE': 'Steckplatz {n}',
    },
    'rhmi.ui.pairedVerified': {
      'TR': 'Eşleşmiş ve doğrulanmış.',
      'EN': 'Paired and verified.',
      'DE': 'Gekoppelt und bestätigt.',
    },
    'rhmi.ui.pairedHere': {
      'TR': 'Bu telefonda eşleşmiş.',
      'EN': 'Paired on this phone.',
      'DE': 'Auf diesem Telefon gekoppelt.',
    },
    'rhmi.ui.notPairedHint': {
      'TR':
          'Eşleşmemiş. Yuva istemcisi için o yuvada kart olmalı; araç içi istemci yalnız kalibrasyon modunda eşleşir.',
      'EN':
          'Not paired. A slot client needs a card in that slot; the in-vehicle client pairs only in calibration mode.',
      'DE':
          'Nicht gekoppelt. Ein Steckplatz-Client braucht eine Karte in diesem Steckplatz; der Fahrzeug-Client koppelt nur im Kalibriermodus.',
    },
    'rhmi.ui.pair': {'TR': 'Eşleştir', 'EN': 'Pair', 'DE': 'Koppeln'},
    'rhmi.ui.enterCode': {
      'TR': 'Kodu gir',
      'EN': 'Enter code',
      'DE': 'Code eingeben',
    },
    'rhmi.ui.verify': {'TR': 'Doğrula', 'EN': 'Verify', 'DE': 'Prüfen'},
    'rhmi.ui.forget': {'TR': 'Unut', 'EN': 'Forget', 'DE': 'Vergessen'},
    'rhmi.ui.rest': {'TR': 'Dinlenme', 'EN': 'Rest', 'DE': 'Ruhezeit'},
    'rhmi.ui.placeLabel': {
      'TR': 'Yer (günlük çalışma dönemi)',
      'EN': 'Place (daily work period)',
      'DE': 'Ort (tägliche Arbeitszeit)',
    },
    'rhmi.ui.ferryBegin': {
      'TR': 'Feribot/tren başla',
      'EN': 'Ferry/train start',
      'DE': 'Fähre/Zug Beginn',
    },
    'rhmi.ui.ferryEnd': {
      'TR': 'Feribot/tren bitir',
      'EN': 'Ferry/train end',
      'DE': 'Fähre/Zug Ende',
    },
    'rhmi.ui.oosBegin': {
      'TR': 'Kapsam dışı başla',
      'EN': 'Out of scope start',
      'DE': 'Außerhalb des Geltungsbereichs Beginn',
    },
    'rhmi.ui.oosEnd': {
      'TR': 'Kapsam dışı bitir',
      'EN': 'Out of scope end',
      'DE': 'Außerhalb des Geltungsbereichs Ende',
    },
    'rhmi.ui.loadLabel': {
      'TR': 'Yükleme / boşaltma',
      'EN': 'Load / unload',
      'DE': 'Beladen / Entladen',
    },
    'rhmi.ui.load': {'TR': 'Yükleme', 'EN': 'Load', 'DE': 'Beladen'},
    'rhmi.ui.unload': {'TR': 'Boşaltma', 'EN': 'Unload', 'DE': 'Entladen'},
    'rhmi.ui.loadBoth': {'TR': 'İkisi', 'EN': 'Both', 'DE': 'Beides'},
    'rhmi.ui.readWarnings': {
      'TR': 'Uyarıları oku',
      'EN': 'Read warnings',
      'DE': 'Warnungen lesen',
    },
    'rhmi.ui.noWarnings': {
      'TR': 'Bekleyen uyarı yok.',
      'EN': 'No pending warnings.',
      'DE': 'Keine offenen Warnungen.',
    },
    'rhmi.ui.session': {
      'TR': 'Oturum: {status}',
      'EN': 'Session: {status}',
      'DE': 'Sitzung: {status}',
    },
    'rhmi.ui.sessionUnknown': {
      'TR': 'bilinmiyor',
      'EN': 'unknown',
      'DE': 'unbekannt',
    },
    'rhmi.ui.clockOffset': {
      'TR':
          'Takograf saati {offset} sn; istekler takograf saatiyle imzalanıyor.',
      'EN':
          'Tachograph clock {offset} s; requests are signed with the tachograph\'s time.',
      'DE':
          'Fahrtenschreiberuhr {offset} s; Anfragen werden mit der Zeit des Fahrtenschreibers signiert.',
    },
    'rhmi.ui.openSession': {
      'TR': 'Oturumu aç',
      'EN': 'Open session',
      'DE': 'Sitzung öffnen',
    },
    'rhmi.ui.closeSession': {
      'TR': 'Oturumu kapat',
      'EN': 'Close session',
      'DE': 'Sitzung schließen',
    },
    'rhmi.ui.refresh': {
      'TR': 'Durumu yenile',
      'EN': 'Refresh state',
      'DE': 'Status aktualisieren',
    },
    'rhmi.ui.checkClock': {
      'TR': 'Saati kontrol et',
      'EN': 'Check clock',
      'DE': 'Uhr prüfen',
    },
    'rhmi.ui.pairFirst': {
      'TR': 'Oturum açmak için önce eşleştirin.',
      'EN': 'Pair first to open a session.',
      'DE': 'Zum Öffnen einer Sitzung zuerst koppeln.',
    },
    'rhmi.ui.country': {'TR': 'Ülke', 'EN': 'Country', 'DE': 'Land'},
    'rhmi.ui.region': {'TR': 'Bölge', 'EN': 'Region', 'DE': 'Region'},
    'rhmi.ui.begin': {'TR': 'Başlangıç', 'EN': 'Start', 'DE': 'Beginn'},
    'rhmi.ui.end': {'TR': 'Bitiş', 'EN': 'End', 'DE': 'Ende'},
    'rhmi.ui.pickDay': {
      'TR': 'Gün seç',
      'EN': 'Pick a day',
      'DE': 'Tag wählen',
    },
    'rhmi.ui.printType': {
      'TR': 'Çıktı türü',
      'EN': 'Printout type',
      'DE': 'Ausdrucktyp',
    },
    'rhmi.ui.print': {'TR': 'Yazdır', 'EN': 'Print', 'DE': 'Drucken'},
    'rhmi.ui.status': {'TR': 'Durum', 'EN': 'Status', 'DE': 'Status'},
    'rhmi.ui.withdrawTitle': {
      'TR': 'Kart çıkarılsın mı?',
      'EN': 'Withdraw the card?',
      'DE': 'Karte entnehmen?',
    },
    'rhmi.ui.withdrawBody': {
      'TR':
          '{slot}. yuvadaki kart, bitiş yeri kaydedilip çıkarılacak. Oturum kartla birlikte kapanır.',
      'EN':
          'The card in slot {slot} will be withdrawn after the end place is recorded. The session closes with the card.',
      'DE':
          'Die Karte in Steckplatz {slot} wird nach dem Speichern des Endorts entnommen. Die Sitzung schließt mit der Karte.',
    },
    'rhmi.ui.withdrawCancel': {
      'TR': 'Vazgeç',
      'EN': 'Cancel',
      'DE': 'Abbrechen',
    },
    'rhmi.ui.withdrawDo': {'TR': 'Çıkar', 'EN': 'Withdraw', 'DE': 'Entnehmen'},
    'rhmi.ui.shiftPrintout': {
      'TR': 'Günün kart çıktısı',
      'EN': 'Card printout of the day',
      'DE': 'Tagesausdruck der Karte',
    },
    'rhmi.ui.none': {'TR': 'Yok', 'EN': 'None', 'DE': 'Keiner'},
    'rhmi.ui.localTime': {
      'TR': 'Yerel saat',
      'EN': 'Local time',
      'DE': 'Ortszeit',
    },
    'rhmi.ui.technical': {
      'TR': 'Teknik veri çıktısı',
      'EN': 'Technical data printout',
      'DE': 'Ausdruck technischer Daten',
    },
    'rhmi.ui.withdrawButton': {
      'TR': 'Kartı çıkar',
      'EN': 'Withdraw card',
      'DE': 'Karte entnehmen',
    },
    'rhmi.ui.manualHint': {
      'TR':
          'Kartın takılı olmadığı süreyi doldurur. Kart takıldıktan sonra yaklaşık bir dakika içinde gönderilmelidir.',
      'EN':
          'Fills in the time the card was not inserted. Must be sent within about a minute of inserting the card.',
      'DE':
          'Füllt die Zeit, in der die Karte nicht gesteckt war. Muss etwa innerhalb einer Minute nach dem Stecken der Karte gesendet werden.',
    },
    'rhmi.ui.cardType': {
      'TR': 'Kart tipi',
      'EN': 'Card type',
      'DE': 'Kartentyp',
    },
    'rhmi.ui.readPeriod': {
      'TR': 'Dönemi oku',
      'EN': 'Read period',
      'DE': 'Zeitraum lesen',
    },
    'rhmi.ui.periodFilled': {
      'TR': 'Dönem: {usable} dakika, doldurulan: {filled} dakika',
      'EN': 'Period: {usable} minutes, filled: {filled} minutes',
      'DE': 'Zeitraum: {usable} Minuten, gefüllt: {filled} Minuten',
    },
    'rhmi.ui.activitiesLabel': {
      'TR': 'Aktiviteler (sırayla, süreleriyle)',
      'EN': 'Activities (in order, with durations)',
      'DE': 'Tätigkeiten (der Reihe nach, mit Dauer)',
    },
    'rhmi.ui.minutes': {'TR': 'Dakika', 'EN': 'Minutes', 'DE': 'Minuten'},
    'rhmi.ui.segment': {
      'TR': '{activity} · {minutes} dk',
      'EN': '{activity} · {minutes} min',
      'DE': '{activity} · {minutes} Min.',
    },
    'rhmi.ui.placesLabel': {
      'TR': 'Yerler (isteğe bağlı)',
      'EN': 'Places (optional)',
      'DE': 'Orte (optional)',
    },
    'rhmi.ui.addPlace': {
      'TR': 'Yer ekle',
      'EN': 'Add place',
      'DE': 'Ort hinzufügen',
    },
    'rhmi.ui.placeRow': {
      'TR': '{minute}. dk · {type} · {country}',
      'EN': 'min {minute} · {type} · {country}',
      'DE': 'Min. {minute} · {type} · {country}',
    },
    'rhmi.ui.send': {'TR': 'Gönder', 'EN': 'Send', 'DE': 'Senden'},
    'rhmi.ui.stopEntry': {
      'TR': 'Girişi bitir',
      'EN': 'End entry',
      'DE': 'Eingabe beenden',
    },
    'diag.serviceRefused': {
      'TR': 'Servis {sid} reddedildi',
      'EN': 'Service {sid} refused',
      'DE': 'Dienst {sid} abgelehnt',
    },
    'diag.commStarted': {
      'TR': 'İletişim başladı',
      'EN': 'Communication started',
      'DE': 'Kommunikation gestartet',
    },
    'diag.keyBytes': {
      'TR': 'anahtar baytlar {bytes}',
      'EN': 'key bytes {bytes}',
      'DE': 'Schlüsselbytes {bytes}',
    },
    'diag.sessionStarted': {
      'TR': 'Diagnostik oturum başladı',
      'EN': 'Diagnostic session started',
      'DE': 'Diagnosesitzung gestartet',
    },
    'diag.noSessionByte': {
      'TR': 'oturum baytı yok',
      'EN': 'no session byte',
      'DE': 'kein Sitzungsbyte',
    },
    'diag.session': {
      'TR': 'oturum {code}',
      'EN': 'session {code}',
      'DE': 'Sitzung {code}',
    },
    'diag.serviceAnswered': {
      'TR': 'Servis {sid} yanıtladı',
      'EN': 'Service {sid} answered',
      'DE': 'Dienst {sid} hat geantwortet',
    },
    'diag.routineAnswered': {
      'TR': 'Rutin yanıtladı',
      'EN': 'Routine answered',
      'DE': 'Routine hat geantwortet',
    },
    'diag.routineIdAnswered': {
      'TR': 'Rutin {id} yanıtladı',
      'EN': 'Routine {id} answered',
      'DE': 'Routine {id} hat geantwortet',
    },
    'diag.rhmiStatus': {
      'TR': 'RHMI oturum durumu (F211)',
      'EN': 'RHMI session state (F211)',
      'DE': 'RHMI-Sitzungsstatus (F211)',
    },
    'diag.state': {
      'TR': 'durum {code}',
      'EN': 'state {code}',
      'DE': 'Status {code}',
    },
    'diag.readData': {
      'TR': 'Okunan veri',
      'EN': 'Data read',
      'DE': 'Gelesene Daten',
    },
    'diag.identifier': {
      'TR': 'Tanımlayıcı {id}',
      'EN': 'Identifier {id}',
      'DE': 'Kennung {id}',
    },
    'diag.noDecoder': {
      'TR': '({id} için çözücü yok)',
      'EN': '(no decoder for {id})',
      'DE': '(kein Decoder für {id})',
    },
    'diag.driving': {'TR': 'sürüş', 'EN': 'driving', 'DE': 'Fahrt'},
    'diag.notDriving': {
      'TR': 'sürüş yok',
      'EN': 'no driving',
      'DE': 'keine Fahrt',
    },
    'diag.cardPresent': {
      'TR': 'geçerli sürücü kartı takılı',
      'EN': 'valid driver card inserted',
      'DE': 'gültige Fahrerkarte gesteckt',
    },
    'diag.cardAbsent': {
      'TR': 'geçerli sürücü kartı yok',
      'EN': 'no valid driver card',
      'DE': 'keine gültige Fahrerkarte',
    },
    'diag.overspeed': {
      'TR': 'hız aşımı',
      'EN': 'overspeeding',
      'DE': 'Geschwindigkeitsüberschreitung',
    },
    'diag.noOverspeed': {
      'TR': 'hız aşımı yok',
      'EN': 'no overspeeding',
      'DE': 'keine Geschwindigkeitsüberschreitung',
    },
    'diag.notSet': {
      'TR': 'ayarlanmamış',
      'EN': 'not set',
      'DE': 'nicht eingestellt',
    },
    'diag.oosActive': {
      'TR': 'kapsam dışı aktif',
      'EN': 'out of scope active',
      'DE': 'außerhalb des Geltungsbereichs aktiv',
    },
    'diag.oosInactive': {
      'TR': 'kapsam dışı değil',
      'EN': 'not out of scope',
      'DE': 'nicht außerhalb des Geltungsbereichs',
    },
    'diag.utcLocal': {
      'TR': '{time} UTC (yerel fark {offset})',
      'EN': '{time} UTC (local offset {offset})',
      'DE': '{time} UTC (Ortszeitdifferenz {offset})',
    },
    'diag.countryCode': {
      'TR': 'ülke {code}',
      'EN': 'country {code}',
      'DE': 'Land {code}',
    },
    'diag.positionUnknown': {
      'TR': 'konum bilinmiyor',
      'EN': 'position unknown',
      'DE': 'Position unbekannt',
    },
    'diag.noTime': {'TR': 'zaman yok', 'EN': 'no time', 'DE': 'keine Zeit'},
    'diag.verified': {
      'TR': 'doğrulanmış',
      'EN': 'authenticated',
      'DE': 'authentifiziert',
    },
    'diag.unverified': {
      'TR': 'doğrulanmamış',
      'EN': 'not authenticated',
      'DE': 'nicht authentifiziert',
    },
    'diag.hm': {
      'TR': '{h} sa {m} dk',
      'EN': '{h} h {m} min',
      'DE': '{h} Std. {m} Min.',
    },
    'diag.noData': {'TR': 'veri yok', 'EN': 'no data', 'DE': 'keine Daten'},
    'diag.act.0': {
      'TR': 'dinlenme / mola',
      'EN': 'rest / break',
      'DE': 'Ruhezeit / Pause',
    },
    'diag.act.1': {
      'TR': 'hazır bulunma',
      'EN': 'availability',
      'DE': 'Bereitschaft',
    },
    'diag.act.2': {'TR': 'diğer iş', 'EN': 'other work', 'DE': 'andere Arbeit'},
    'diag.act.3': {'TR': 'sürüş', 'EN': 'driving', 'DE': 'Lenken'},
    'diag.act.other': {
      'TR': 'aktivite {code}',
      'EN': 'activity {code}',
      'DE': 'Tätigkeit {code}',
    },
    'diag.slot.0': {'TR': 'kart yok', 'EN': 'no card', 'DE': 'keine Karte'},
    'diag.slot.1': {
      'TR': 'sürücü kartı',
      'EN': 'driver card',
      'DE': 'Fahrerkarte',
    },
    'diag.slot.2': {
      'TR': 'atölye kartı',
      'EN': 'workshop card',
      'DE': 'Werkstattkarte',
    },
    'diag.slot.3': {
      'TR': 'kontrol kartı',
      'EN': 'control card',
      'DE': 'Kontrollkarte',
    },
    'diag.slot.4': {
      'TR': 'şirket kartı',
      'EN': 'company card',
      'DE': 'Unternehmenskarte',
    },
    'diag.mode.0': {'TR': 'operasyonel', 'EN': 'operational', 'DE': 'Betrieb'},
    'diag.mode.1': {'TR': 'kontrol', 'EN': 'control', 'DE': 'Kontrolle'},
    'diag.mode.2': {
      'TR': 'kalibrasyon',
      'EN': 'calibration',
      'DE': 'Kalibrierung',
    },
    'diag.mode.3': {'TR': 'şirket', 'EN': 'company', 'DE': 'Unternehmen'},
    'diag.mode.other': {
      'TR': 'mod {code}',
      'EN': 'mode {code}',
      'DE': 'Modus {code}',
    },
    'diag.load.0': {
      'TR': 'tanımsız',
      'EN': 'undefined',
      'DE': 'nicht definiert',
    },
    'diag.load.1': {'TR': 'yük', 'EN': 'goods', 'DE': 'Güter'},
    'diag.load.2': {'TR': 'yolcu', 'EN': 'passengers', 'DE': 'Personen'},
    'diag.load.other': {
      'TR': 'yük tipi {code}',
      'EN': 'load type {code}',
      'DE': 'Ladungsart {code}',
    },
    'diag.tw.0': {
      'TR': 'süre uyarısı yok',
      'EN': 'no time warning',
      'DE': 'keine Zeitwarnung',
    },
    'diag.tw.1': {
      'TR': '4s15 kesintisiz sürüş',
      'EN': '4h15 continuous driving',
      'DE': '4h15 ununterbrochene Lenkzeit',
    },
    'diag.tw.2': {
      'TR': '4s30 kesintisiz sürüşe ulaşıldı',
      'EN': '4h30 continuous driving reached',
      'DE': '4h30 ununterbrochene Lenkzeit erreicht',
    },
    'diag.tw.3': {
      'TR': 'günlük sürüş ön uyarısı',
      'EN': 'daily driving pre-warning',
      'DE': 'Vorwarnung Tageslenkzeit',
    },
    'diag.tw.4': {
      'TR': 'günlük sürüş sınırına ulaşıldı',
      'EN': 'daily driving limit reached',
      'DE': 'Tageslenkzeit erreicht',
    },
    'diag.tw.5': {
      'TR': 'günlük / haftalık dinlenme ön uyarısı',
      'EN': 'daily / weekly rest pre-warning',
      'DE': 'Vorwarnung Tages-/Wochenruhezeit',
    },
    'diag.tw.6': {
      'TR': 'günlük / haftalık dinlenme sınırı',
      'EN': 'daily / weekly rest limit',
      'DE': 'Grenze Tages-/Wochenruhezeit',
    },
    'diag.tw.7': {
      'TR': 'haftalık sürüş ön uyarısı',
      'EN': 'weekly driving pre-warning',
      'DE': 'Vorwarnung Wochenlenkzeit',
    },
    'diag.tw.8': {
      'TR': 'haftalık sürüş sınırına ulaşıldı',
      'EN': 'weekly driving limit reached',
      'DE': 'Wochenlenkzeit erreicht',
    },
    'diag.tw.9': {
      'TR': 'iki haftalık sürüş ön uyarısı',
      'EN': 'fortnightly driving pre-warning',
      'DE': 'Vorwarnung Doppelwochenlenkzeit',
    },
    'diag.tw.10': {
      'TR': 'iki haftalık sürüş sınırına ulaşıldı',
      'EN': 'fortnightly driving limit reached',
      'DE': 'Doppelwochenlenkzeit erreicht',
    },
    'diag.tw.11': {
      'TR': 'sürücü kartı süresi doluyor',
      'EN': 'driver card expiring',
      'DE': 'Fahrerkarte läuft ab',
    },
    'diag.tw.12': {
      'TR': 'sürücü kartı indirme zamanı',
      'EN': 'driver card download due',
      'DE': 'Download der Fahrerkarte fällig',
    },
    'diag.id.F190': {'TR': 'VIN', 'EN': 'VIN', 'DE': 'FIN'},
    'diag.id.F902': {
      'TR': 'Araç hızı',
      'EN': 'Vehicle speed',
      'DE': 'Fahrzeuggeschwindigkeit',
    },
    'diag.id.F903': {
      'TR': 'Sürücü 1 çalışma durumu',
      'EN': 'Driver 1 working state',
      'DE': 'Arbeitsstatus Fahrer 1',
    },
    'diag.id.F904': {
      'TR': 'Sürücü 2 çalışma durumu',
      'EN': 'Driver 2 working state',
      'DE': 'Arbeitsstatus Fahrer 2',
    },
    'diag.id.F905': {
      'TR': 'Sürüş algılama',
      'EN': 'Driving detection',
      'DE': 'Fahrterkennung',
    },
    'diag.id.F906': {
      'TR': 'Sürücü 1 süre durumları',
      'EN': 'Driver 1 time states',
      'DE': 'Zeitstatus Fahrer 1',
    },
    'diag.id.F907': {
      'TR': 'Sürücü 1 kartı',
      'EN': 'Driver 1 card',
      'DE': 'Karte Fahrer 1',
    },
    'diag.id.F908': {
      'TR': 'Hız aşımı',
      'EN': 'Overspeeding',
      'DE': 'Geschwindigkeitsüberschreitung',
    },
    'diag.id.F909': {
      'TR': 'Sürücü 2 süre durumları',
      'EN': 'Driver 2 time states',
      'DE': 'Zeitstatus Fahrer 2',
    },
    'diag.id.F90A': {
      'TR': 'Sürücü 2 kartı',
      'EN': 'Driver 2 card',
      'DE': 'Karte Fahrer 2',
    },
    'diag.id.F90B': {
      'TR': 'Tarih ve saat',
      'EN': 'Date and time',
      'DE': 'Datum und Uhrzeit',
    },
    'diag.id.F912': {
      'TR': 'Toplam araç mesafesi',
      'EN': 'Total vehicle distance',
      'DE': 'Gesamtwegstrecke',
    },
    'diag.id.F913': {
      'TR': 'Yolculuk mesafesi',
      'EN': 'Trip distance',
      'DE': 'Tageswegstrecke',
    },
    'diag.id.F916': {
      'TR': 'Sürücü 1 kimliği',
      'EN': 'Driver 1 identification',
      'DE': 'Kennung Fahrer 1',
    },
    'diag.id.F917': {
      'TR': 'Sürücü 2 kimliği',
      'EN': 'Driver 2 identification',
      'DE': 'Kennung Fahrer 2',
    },
    'diag.id.F918': {
      'TR': 'K faktörü',
      'EN': 'K constant',
      'DE': 'Konstante k',
    },
    'diag.id.F91B': {
      'TR': 'Çıkış mili hızı',
      'EN': 'Output shaft speed',
      'DE': 'Abtriebswellendrehzahl',
    },
    'diag.id.F91C': {
      'TR': 'L faktörü (lastik çevresi)',
      'EN': 'L factor (tyre circumference)',
      'DE': 'Faktor l (Reifenumfang)',
    },
    'diag.id.F91D': {'TR': 'W faktörü', 'EN': 'W factor', 'DE': 'Faktor w'},
    'diag.id.F921': {
      'TR': 'Lastik ölçüsü',
      'EN': 'Tyre size',
      'DE': 'Reifengröße',
    },
    'diag.id.F922': {
      'TR': 'Sonraki kalibrasyon tarihi',
      'EN': 'Next calibration date',
      'DE': 'Nächstes Kalibrierdatum',
    },
    'diag.id.F923': {
      'TR': 'Sürücü 1 kesintisiz sürüş',
      'EN': 'Driver 1 continuous driving',
      'DE': 'Ununterbrochene Lenkzeit Fahrer 1',
    },
    'diag.id.F924': {
      'TR': 'Sürücü 2 kesintisiz sürüş',
      'EN': 'Driver 2 continuous driving',
      'DE': 'Ununterbrochene Lenkzeit Fahrer 2',
    },
    'diag.id.F92C': {
      'TR': 'İzin verilen hız',
      'EN': 'Authorised speed',
      'DE': 'Zulässige Geschwindigkeit',
    },
    'diag.id.F930': {
      'TR': 'Kart yuvası 1',
      'EN': 'Card slot 1',
      'DE': 'Kartensteckplatz 1',
    },
    'diag.id.F931': {
      'TR': 'Sürücü 1 adı',
      'EN': 'Driver 1 name',
      'DE': 'Name Fahrer 1',
    },
    'diag.id.F932': {
      'TR': 'Sürücü 2 adı',
      'EN': 'Driver 2 name',
      'DE': 'Name Fahrer 2',
    },
    'diag.id.F933': {
      'TR': 'Kart yuvası 2',
      'EN': 'Card slot 2',
      'DE': 'Kartensteckplatz 2',
    },
    'diag.id.F936': {
      'TR': 'Kapsam dışı durumu',
      'EN': 'Out of scope state',
      'DE': 'Status außerhalb des Geltungsbereichs',
    },
    'diag.id.F937': {
      'TR': 'Çalışma modu',
      'EN': 'Operating mode',
      'DE': 'Betriebsart',
    },
    'diag.id.F97D': {
      'TR': 'Tescil ülkesi',
      'EN': 'Registering member state',
      'DE': 'Zulassungsmitgliedstaat',
    },
    'diag.id.F97E': {
      'TR': 'Araç plakası',
      'EN': 'Vehicle registration number',
      'DE': 'Amtliches Kennzeichen',
    },
    'diag.id.F97F': {
      'TR': 'Araç tescil tarihi',
      'EN': 'Vehicle registration date',
      'DE': 'Zulassungsdatum',
    },
    'diag.id.F98B': {
      'TR': 'Sürücü 2 kart son kullanma',
      'EN': 'Driver 2 card expiry',
      'DE': 'Ablauf Karte Fahrer 2',
    },
    'diag.id.F99A': {
      'TR': 'Sürücü 1 günlük sürüş',
      'EN': 'Driver 1 daily driving',
      'DE': 'Tageslenkzeit Fahrer 1',
    },
    'diag.id.F99D': {
      'TR': 'Sürücü 1 kart son kullanma',
      'EN': 'Driver 1 card expiry',
      'DE': 'Ablauf Karte Fahrer 1',
    },
    'diag.id.F9D5': {
      'TR': 'Varsayılan yük tipi',
      'EN': 'Default load type',
      'DE': 'Standard-Ladungsart',
    },
    'diag.id.F9D7': {
      'TR': 'Araç konumu',
      'EN': 'Vehicle position',
      'DE': 'Fahrzeugposition',
    },
    'about.title': {'TR': 'Hakkımızda', 'EN': 'About us', 'DE': 'Über uns'},
    'about.badge': {
      'TR': 'ASELSAN\'IN TEK KÜRESEL DİSTRİBÜTÖRÜ',
      'EN': 'ASELSAN\'S SOLE GLOBAL DISTRIBUTOR',
      'DE': 'ALLEINIGER WELTWEITER VERTRIEBSPARTNER VON ASELSAN',
    },
    'about.headline': {
      'TR': 'Filo yönetimi teknolojisinde yenilikler geliştiriyoruz',
      'EN': 'We develop innovations in fleet management technology',
      'DE': 'Wir entwickeln Innovationen in der Flottenmanagement-Technologie',
    },
    'about.intro': {
      'TR':
          'SmartTrack; yol güvenliğini artırmak, filo operasyonlarını optimize etmek ve mevzuata uygunluğu sağlamak için tasarlanmış dijital takograf çözümleri sunar.',
      'EN':
          'SmartTrack offers digital tachograph solutions designed to improve road safety, optimise fleet operations and ensure regulatory compliance.',
      'DE':
          'SmartTrack bietet digitale Fahrtenschreiberlösungen, die die Verkehrssicherheit erhöhen, den Flottenbetrieb optimieren und die Einhaltung der Vorschriften sicherstellen.',
    },
    'about.statCustomers': {'TR': 'Müşteri', 'EN': 'Customers', 'DE': 'Kunden'},
    'about.statTachographs': {
      'TR': 'Takograf',
      'EN': 'Tachographs',
      'DE': 'Fahrtenschreiber',
    },
    'about.statYears': {
      'TR': 'Yıllık deneyim',
      'EN': 'Years of experience',
      'DE': 'Jahre Erfahrung',
    },
    'about.expertise': {
      'TR': 'Uzmanlığımız',
      'EN': 'Our expertise',
      'DE': 'Unsere Kompetenzen',
    },
    'about.s1Title': {
      'TR': 'Filo yönetimi',
      'EN': 'Fleet management',
      'DE': 'Flottenmanagement',
    },
    'about.s1Body': {
      'TR': 'Sektöre özel ihtiyaçlara göre uyarlanmış akıllı takip çözümleri.',
      'EN': 'Smart tracking solutions tailored to the needs of each sector.',
      'DE':
          'Intelligente Ortungslösungen, zugeschnitten auf die Anforderungen jeder Branche.',
    },
    'about.s2Title': {
      'TR': 'Mevzuata uygunluk',
      'EN': 'Regulatory compliance',
      'DE': 'Einhaltung der Vorschriften',
    },
    'about.s2Body': {
      'TR': 'Güncel uluslararası standartlara ve yasal mevzuata tam uyum.',
      'EN':
          'Full compliance with current international standards and regulations.',
      'DE':
          'Volle Übereinstimmung mit aktuellen internationalen Normen und Vorschriften.',
    },
    'about.s3Title': {
      'TR': 'Yol güvenliği',
      'EN': 'Road safety',
      'DE': 'Verkehrssicherheit',
    },
    'about.s3Body': {
      'TR': 'Sürücü ve yük güvenliğini artıran yenilikçi teknolojiler.',
      'EN': 'Innovative technologies that make drivers and cargo safer.',
      'DE':
          'Innovative Technologien für mehr Sicherheit von Fahrern und Ladung.',
    },
    'about.s4Title': {
      'TR': 'Sürdürülebilirlik',
      'EN': 'Sustainability',
      'DE': 'Nachhaltigkeit',
    },
    'about.s4Body': {
      'TR': 'Verimliliği artıran ve çevresel etkiyi azaltan uygulamalar.',
      'EN': 'Practices that raise efficiency and reduce environmental impact.',
      'DE':
          'Verfahren, die die Effizienz steigern und die Umweltbelastung senken.',
    },
    'about.process': {
      'TR': 'Çalışma sürecimiz',
      'EN': 'How we work',
      'DE': 'So arbeiten wir',
    },
    'about.processSub': {
      'TR': 'Daha akıllı filo çözümlerini nasıl sunuyoruz',
      'EN': 'How we deliver smarter fleet solutions',
      'DE': 'Wie wir intelligentere Flottenlösungen liefern',
    },
    'about.p1Title': {
      'TR': 'Değerlendirme',
      'EN': 'Assessment',
      'DE': 'Analyse',
    },
    'about.p1Body': {
      'TR':
          'Filo yönetimi ihtiyaçlarınızı analiz eder, iyileştirme alanlarını belirleriz.',
      'EN':
          'We analyse your fleet management needs and identify areas for improvement.',
      'DE':
          'Wir analysieren Ihren Bedarf im Flottenmanagement und zeigen Verbesserungspotenzial auf.',
    },
    'about.p2Title': {
      'TR': 'Stratejik planlama',
      'EN': 'Strategic planning',
      'DE': 'Strategische Planung',
    },
    'about.p2Body': {
      'TR':
          'Operasyonel verimliliği ve uyumluluğu artıracak size özel stratejiler geliştiririz.',
      'EN':
          'We build tailored strategies to raise operational efficiency and compliance.',
      'DE':
          'Wir entwickeln maßgeschneiderte Strategien für mehr Effizienz und Regelkonformität.',
    },
    'about.p3Title': {
      'TR': 'Uygulama',
      'EN': 'Implementation',
      'DE': 'Umsetzung',
    },
    'about.p3Body': {
      'TR': 'Gelişmiş takograf sistemlerini operasyonlarınıza entegre ederiz.',
      'EN': 'We integrate advanced tachograph systems into your operations.',
      'DE': 'Wir integrieren moderne Fahrtenschreibersysteme in Ihren Betrieb.',
    },
    'about.p4Title': {
      'TR': 'Sürekli destek',
      'EN': 'Ongoing support',
      'DE': 'Laufende Unterstützung',
    },
    'about.p4Body': {
      'TR':
          'Sorunsuz çalışma için bakım, güncelleme ve uzman desteği sağlarız.',
      'EN':
          'We provide maintenance, updates and expert support for trouble-free operation.',
      'DE':
          'Wir bieten Wartung, Updates und Expertenunterstützung für einen reibungslosen Betrieb.',
    },
    'about.products': {
      'TR': 'Ürünlerimiz',
      'EN': 'Our products',
      'DE': 'Unsere Produkte',
    },
    'about.prodTacho': {
      'TR': 'Dijital takograf',
      'EN': 'Digital tachograph',
      'DE': 'Digitaler Fahrtenschreiber',
    },
    'about.prodCalibration': {
      'TR': 'Dijital takograf kalibrasyon cihazı',
      'EN': 'Digital tachograph calibration device',
      'DE': 'Kalibriergerät für digitale Fahrtenschreiber',
    },
    'about.contact': {'TR': 'İletişim', 'EN': 'Contact', 'DE': 'Kontakt'},
    'about.closing': {
      'TR':
          'SmartTrack, güvenilir ve sürdürülebilir filo yönetimi çözümleri sunmak için yenilikçi teknolojiyi uzmanlıkla birleştirir.',
      'EN':
          'SmartTrack combines innovative technology with expertise to deliver reliable and sustainable fleet management solutions.',
      'DE':
          'SmartTrack verbindet innovative Technologie mit Fachwissen für zuverlässige und nachhaltige Flottenmanagement-Lösungen.',
    },
    'about.rights': {
      'TR': '© {year} SmartTrack. Tüm hakları saklıdır.',
      'EN': '© {year} SmartTrack. All rights reserved.',
      'DE': '© {year} SmartTrack. Alle Rechte vorbehalten.',
    },
    'about.heroTitle': {
      'TR': 'Daha güvenli bir yarın için gelişmiş filo yönetimi çözümleri',
      'EN': 'Advanced fleet management solutions for a safer tomorrow',
      'DE': 'Moderne Flottenmanagement-Lösungen für ein sichereres Morgen',
    },
    'about.servicesTitle': {
      'TR': 'Filo yönetimi için yenilikçi çözümler',
      'EN': 'Innovative solutions for fleet management',
      'DE': 'Innovative Lösungen für das Flottenmanagement',
    },
    'about.sv1Title': {
      'TR': 'Gelişmiş takograf sistemleri',
      'EN': 'Advanced tachograph systems',
      'DE': 'Moderne Fahrtenschreibersysteme',
    },
    'about.sv1Body': {
      'TR':
          'Küresel standartlara uygun, güvenli ve doğru sürücü aktivitesi takibi.',
      'EN':
          'Safe, accurate tracking of driver activity that meets global standards.',
      'DE':
          'Sichere, genaue Erfassung der Fahrertätigkeiten nach internationalen Standards.',
    },
    'about.sv2Title': {
      'TR': 'Mevzuata uygunluk desteği',
      'EN': 'Regulatory compliance assistance',
      'DE': 'Unterstützung bei der Regelkonformität',
    },
    'about.sv2Body': {
      'TR': 'AB mevzuatına uygun cihazlar ve size özel çözümler.',
      'EN': 'EU-compliant devices and solutions tailored to you.',
      'DE': 'EU-konforme Geräte und maßgeschneiderte Lösungen.',
    },
    'about.sv3Title': {
      'TR': 'Filo yönetimi optimizasyonu',
      'EN': 'Fleet management optimisation',
      'DE': 'Optimierung des Flottenmanagements',
    },
    'about.sv3Body': {
      'TR':
          'Taşımacılık şirketlerinin operasyonel verimliliğini artıran özel çözümler.',
      'EN':
          'Tailored solutions that raise the operational efficiency of transport companies.',
      'DE':
          'Maßgeschneiderte Lösungen für mehr Effizienz in Transportunternehmen.',
    },
    'about.sv4Title': {
      'TR': 'Sürdürülebilirlik odaklı tasarım',
      'EN': 'Sustainability-focused design',
      'DE': 'Nachhaltiges Design',
    },
    'about.sv4Body': {
      'TR': 'Çevre dostu ve enerji verimli ürünler.',
      'EN': 'Environmentally friendly, energy-efficient products.',
      'DE': 'Umweltfreundliche, energieeffiziente Produkte.',
    },
    'about.sv5Title': {
      'TR': 'Yol güvenliği iyileştirmeleri',
      'EN': 'Road safety improvements',
      'DE': 'Mehr Verkehrssicherheit',
    },
    'about.sv5Body': {
      'TR': 'Sürüş ve dinlenme sürelerini izleyen teknolojiler.',
      'EN': 'Technology that monitors driving and rest times.',
      'DE': 'Technik zur Überwachung von Lenk- und Ruhezeiten.',
    },
    'about.sv6Title': {
      'TR': 'Küresel dağıtım ağı',
      'EN': 'Global distribution network',
      'DE': 'Weltweites Vertriebsnetz',
    },
    'about.sv6Body': {
      'TR':
          'Destek altyapısıyla birlikte, çözümlerimize dünyanın her yerinden erişim.',
      'EN': 'Access to our solutions worldwide, backed by a support network.',
      'DE': 'Weltweiter Zugang zu unseren Lösungen mit Support-Netzwerk.',
    },
    'about.videoTitle': {
      'TR': 'Tanıtım videosu',
      'EN': 'Promotional video',
      'DE': 'Imagevideo',
    },
    'about.videoBody': {
      'TR': 'SmartTrack\'i YouTube\'da izleyin.',
      'EN': 'Watch SmartTrack on YouTube.',
      'DE': 'SmartTrack auf YouTube ansehen.',
    },
    'about.ctaTitle': {
      'TR': 'Bize ulaşın',
      'EN': 'Contact us',
      'DE': 'Kontaktieren Sie uns',
    },
    'about.ctaBody': {
      'TR':
          'Takograf sistemleri ya da filo yönetimi konusunda uzman ekibimiz yardıma hazır; en kısa sürede dönüş yapıyoruz.',
      'EN':
          'Our expert team is ready to help with tachograph systems or fleet management, and we reply as soon as we can.',
      'DE':
          'Unser Expertenteam hilft gern bei Fahrtenschreibern oder Flottenmanagement – wir melden uns schnellstmöglich.',
    },
    'about.call': {'TR': 'Ara', 'EN': 'Call', 'DE': 'Anrufen'},
    'about.sendMail': {'TR': 'E-posta', 'EN': 'Email', 'DE': 'E-Mail'},
    'about.openMap': {
      'TR': 'Haritada aç',
      'EN': 'Open in maps',
      'DE': 'In Karten öffnen',
    },
    'about.linkFailed': {
      'TR': 'Bağlantı açılamadı.',
      'EN': 'The link could not be opened.',
      'DE': 'Der Link konnte nicht geöffnet werden.',
    },
    'stcdl.title': {
      'TR': '.ddd verisi indir',
      'EN': 'Download .ddd data',
      'DE': '.ddd-Daten herunterladen',
    },
    'stcdl.subtitle': {
      'TR': 'Hangi verileri almak istediğini seç',
      'EN': 'Choose which data to download',
      'DE': 'Wählen Sie, welche Daten geladen werden',
    },
    'stcdl.vehicleUnit': {
      'TR': 'Araç ünitesi (takograf)',
      'EN': 'Vehicle unit (tachograph)',
      'DE': 'Fahrzeugeinheit (Fahrtenschreiber)',
    },
    'stcdl.card': {
      'TR': 'Sürücü kartı',
      'EN': 'Driver card',
      'DE': 'Fahrerkarte',
    },
    'stcdl.activities': {
      'TR': 'Aktivite verisi',
      'EN': 'Activity data',
      'DE': 'Tätigkeitsdaten',
    },
    'stcdl.eventsFaults': {
      'TR': 'Olaylar ve arızalar',
      'EN': 'Events and faults',
      'DE': 'Ereignisse und Störungen',
    },
    'stcdl.detailedSpeed': {
      'TR': 'Detaylı hız',
      'EN': 'Detailed speed',
      'DE': 'Detaillierte Geschwindigkeit',
    },
    'stcdl.technical': {
      'TR': 'Teknik veri',
      'EN': 'Technical data',
      'DE': 'Technische Daten',
    },
    'stcdl.download': {
      'TR': 'İndir',
      'EN': 'Download',
      'DE': 'Herunterladen',
    },
    'stcdl.rangeNone': {
      'TR': 'Alınmayacak',
      'EN': 'Not downloaded',
      'DE': 'Wird nicht geladen',
    },
    'stcdl.rangeDays': {
      'TR': 'Son {days} gün',
      'EN': 'Last {days} days',
      'DE': 'Letzte {days} Tage',
    },
    'stcdl.rangeTitle': {
      'TR': 'Aktivite verisi — hangi tarih aralığı?',
      'EN': 'Activity data — which date range?',
      'DE': 'Tätigkeitsdaten – welcher Zeitraum?',
    },
    'stcdl.rangeCustom': {
      'TR': 'Özel tarih aralığı seç…',
      'EN': 'Choose a custom range…',
      'DE': 'Eigenen Zeitraum wählen…',
    },
    'stcdl.rangeSkip': {
      'TR': 'Aktivite verisi alma',
      'EN': 'Don\'t download activity data',
      'DE': 'Keine Tätigkeitsdaten laden',
    },
    'stcdl.rangeHelp': {
      'TR': 'Aktivite verisi tarih aralığı',
      'EN': 'Activity data date range',
      'DE': 'Zeitraum der Tätigkeitsdaten',
    },
    'stcdl.rangeEverything': {
      'TR': 'Takografın tuttuğu tüm dönem',
      'EN': 'Everything the tachograph holds',
      'DE': 'Alles, was der Fahrtenschreiber gespeichert hat',
    },
    'stcdl.rangeEverythingShort': {
      'TR': 'Tüm dönem',
      'EN': 'Full period',
      'DE': 'Gesamter Zeitraum',
    },
  };

  static String getText(String lang, String key) {
    final more = _moreLanguages[lang]?[key];
    if (more != null) return more;
    final entry = _translations[key];
    if (entry == null) return key;
    // A text not yet translated is shown in English, which a driver who has
    // chosen another language is likelier to read than Turkish.
    return entry[lang] ?? entry['EN'] ?? entry['TR'] ?? key;
  }

  static const Map<String, List<String>> _weekdaysShort = {
    'TR': ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'],
    'EN': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    'DE': ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'],
    'RU': ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
    'PL': ['Pon', 'Wt', 'Śr', 'Czw', 'Pt', 'Sob', 'Nd'],
    'RO': ['Lun', 'Mar', 'Mie', 'Joi', 'Vin', 'Sâm', 'Dum'],
    'ES': ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'],
    'UK': ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'],
  };

  static const Map<String, List<String>> _weekdaysLong = {
    'TR': [
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar',
    ],
    'EN': [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ],
    'DE': [
      'Montag',
      'Dienstag',
      'Mittwoch',
      'Donnerstag',
      'Freitag',
      'Samstag',
      'Sonntag',
    ],
    'RU': [
      'понедельник',
      'вторник',
      'среда',
      'четверг',
      'пятница',
      'суббота',
      'воскресенье',
    ],
    'PL': [
      'poniedziałek',
      'wtorek',
      'środa',
      'czwartek',
      'piątek',
      'sobota',
      'niedziela',
    ],
    'RO': ['luni', 'marți', 'miercuri', 'joi', 'vineri', 'sâmbătă', 'duminică'],
    'ES': [
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
      'domingo',
    ],
    'UK': [
      'понеділок',
      'вівторок',
      'середа',
      'четвер',
      "п'ятниця",
      'субота',
      'неділя',
    ],
  };

  /// "Mon" for [weekday] 1 (Monday) to 7 (Sunday).
  static String weekdayShort(String lang, int weekday) =>
      (_weekdaysShort[lang] ?? _weekdaysShort['EN']!)[weekday - 1];

  /// "Monday" for [weekday] 1 (Monday) to 7 (Sunday).
  static String weekdayLong(String lang, int weekday) =>
      (_weekdaysLong[lang] ?? _weekdaysLong['EN']!)[weekday - 1];

  /// Month names as they read inside a date: Russian, Polish and Ukrainian
  /// put the month in the genitive ("19 октября"), the others as they are.
  static const Map<String, List<String>> _monthsInDate = {
    'TR': [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ],
    'EN': [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ],
    'DE': [
      'Januar',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember',
    ],
    'RU': [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ],
    'PL': [
      'stycznia',
      'lutego',
      'marca',
      'kwietnia',
      'maja',
      'czerwca',
      'lipca',
      'sierpnia',
      'września',
      'października',
      'listopada',
      'grudnia',
    ],
    'RO': [
      'ianuarie',
      'februarie',
      'martie',
      'aprilie',
      'mai',
      'iunie',
      'iulie',
      'august',
      'septembrie',
      'octombrie',
      'noiembrie',
      'decembrie',
    ],
    'ES': [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ],
    'UK': [
      'січня',
      'лютого',
      'березня',
      'квітня',
      'травня',
      'червня',
      'липня',
      'серпня',
      'вересня',
      'жовтня',
      'листопада',
      'грудня',
    ],
  };

  /// "19 October 2026, Monday", in the order and forms [lang] writes it.
  static String formatDate(String lang, DateTime date) {
    final months = _monthsInDate[lang] ?? _monthsInDate['EN']!;
    final month = months[date.month - 1];
    final weekday = weekdayLong(lang, date.weekday);
    if (lang == 'ES') {
      return '${date.day} de $month de ${date.year}, $weekday';
    }
    return '${date.day} $month ${date.year}, $weekday';
  }

  static String getGreeting(String lang, String driverName) {
    final hello = switch (lang) {
      'EN' => 'Hello',
      'DE' => 'Hallo',
      'RU' => 'Здравствуйте',
      'PL' => 'Dzień dobry',
      'RO' => 'Bună ziua',
      'ES' => 'Hola',
      'UK' => 'Вітаємо',
      _ => 'Merhaba',
    };
    return '$hello, $driverName';
  }
}
