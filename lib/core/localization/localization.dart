class AppLocalizations {
  AppLocalizations._();

  static const Map<String, Map<String, String>> _translations = {
    'nav.dashboard': {'TR': 'Panel', 'EN': 'Dashboard', 'DE': 'Dashboard'},
    'nav.logs': {'TR': 'Kayıtlar', 'EN': 'Logs', 'DE': 'Protokolle'},
    'nav.alerts': {'TR': 'Uyarılar', 'EN': 'Alerts', 'DE': 'Warnungen'},
    'nav.timeline': {'TR': 'Çizelge', 'EN': 'Timeline', 'DE': 'Zeitleiste'},
    'nav.dddFiles': {'TR': 'Dosyalar', 'EN': 'Files', 'DE': 'Dateien'},
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
      'TR': 'Aselsan STC-8255 Bağlantısı Yok',
      'EN': 'Aselsan STC-8255 Disconnected',
      'DE': 'Aselsan STC-8255 Getrennt',
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
    'settings.autoFetchDdd': {
      'TR': 'Otomatik .ddd İndirme',
      'EN': 'Automatic .ddd Download',
      'DE': 'Automatischer .ddd-Download',
    },
    'settings.autoFetchDddDesc': {
      'TR':
          'Bağlantı kesilip yeniden bağlanınca boşluğu doldurmak için takograftan otomatik veri istenir — kapalıyken doğrudan size sorulur.',
      'EN':
          'On reconnect, automatically requests data from the tachograph to fill the gap — when off, you\'re asked directly instead.',
      'DE':
          'Beim erneuten Verbinden werden automatisch Daten vom Fahrtenschreiber angefordert, um die Lücke zu schließen — bei Deaktivierung werden Sie stattdessen direkt gefragt.',
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
    'timeline.liveOnlyDataNote': {
      'TR':
          'Bu sayfa yalnızca takograftan canlı okunan gerçek verilerle beslenir — .ddd dosyasından (gerçek veya simüle) bağımsızdır.',
      'EN':
          'This page is fed only by real, live-read tachograph data — independent of the .ddd file (real or simulated).',
      'DE':
          'Diese Seite wird ausschließlich mit echten, live vom Fahrtenschreiber gelesenen Daten gespeist — unabhängig von der .ddd-Datei (echt oder simuliert).',
    },
    'timeline.showingFileNote': {
      'TR': '{file} dosyasının verisi gösteriliyor — canlı veri değil.',
      'EN': 'Showing data from {file} — not live data.',
      'DE': 'Daten aus {file} werden angezeigt — keine Live-Daten.',
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
    'ddd.cardBadge': {'TR': 'KART', 'EN': 'CARD', 'DE': 'KARTE'},
    'ddd.vehicleUnitBadge': {
      'TR': 'TAKOGRAF',
      'EN': 'TACHOGRAPH',
      'DE': 'FAHRTENSCHREIBER',
    },
    'ddd.bothBadge': {
      'TR': 'KART+TAKOGRAF',
      'EN': 'CARD+TACHOGRAPH',
      'DE': 'KARTE+FAHRTENSCHREIBER',
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
  };

  static String getText(String lang, String key) {
    final entry = _translations[key];
    if (entry == null) return key;
    return entry[lang] ?? entry['TR'] ?? key;
  }

  static String formatDate(String lang, DateTime date) {
    final daysMap = {
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
    };
    final monthsMap = {
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
    };

    final days = daysMap[lang] ?? daysMap['TR']!;
    final months = monthsMap[lang] ?? monthsMap['TR']!;

    return '${date.day} ${months[date.month - 1]} ${date.year}, ${days[date.weekday - 1]}';
  }

  static String getGreeting(String lang, String driverName) {
    if (lang == 'EN') return 'Hello, $driverName';
    if (lang == 'DE') return 'Hallo, $driverName';
    return 'Merhaba, $driverName';
  }
}
