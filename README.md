# SmartTrack — Sürücü Uygulaması

SmartTrack, dijital takografa Bluetooth Low Energy (BLE) ile bağlanan bir Flutter uygulamasıdır. Sürücü için şunları yapar:

- Canlı sürüş verilerini gösterir.
- AB 561/2006 sürüş ve dinlenme sürelerine uyumu takip eder.
- Olası ihlalleri ve 2026 Türkiye ceza tutarlarını hesaplar.
- Kart ve araç ünitesi (VU) verilerini `.ddd` dosyası olarak indirir ve gösterir.

Uygulama iki takograf ailesiyle çalışır. Hangisinin kullanılacağı her açılışta seçilir:

| Takograf | Bağlantı | Kullanılabilen özellikler |
|---|---|---|
| **Aselsan STC 8255** | BLE–K-line dongle (uygulama servisi, `0x0C` önekli KWP2000 çerçeveleri) | Canlı veri, sürüş süreleri, ihlal ve ceza analizi |
| **ATC 8256 (AVU3)** | Ünitenin kendi BLE uygulama servisi ile AB Ek 1C Appendix 13 ITS servisleri | Yukarıdakilerin hepsi, ITS veri indirme, Remote HMI ve Annex 8 tanı konsolu |

Arayüz Türkçe, İngilizce ve Almanca'dır; varsayılan dil Türkçe'dir. ITS, RHMI ve hata ayıklama ekranları yalnızca Türkçe'dir.

---

## İçindekiler

- [Özellikler](#özellikler)
- [Kurulum ve çalıştırma](#kurulum-ve-çalıştırma)
- [iPhone'a yükleme (Mac olmadan)](#iphonea-yükleme-mac-olmadan)
- [Mimari](#mimari)
- [Bluetooth ve protokol katmanı](#bluetooth-ve-protokol-katmanı)
- [Veri saklama](#veri-saklama)
- [Platform yapılandırması](#platform-yapılandırması)
- [Testler](#testler)
- [Klasör yapısı](#klasör-yapısı)
- [Bilinen eksikler](#bilinen-eksikler)
- [Repolar](#repolar)
- [Ek belgeler](#ek-belgeler)

---

## Özellikler

### Açılış ve bağlantı

**Takograf seçimi** (`/select-device`): STC 8255 ya da ATC 8256 seçilir. Seçim kaydedilmez; her açılışta yeniden sorulur.

**Cihaz tarama ve bağlantı** (`/connect`, `/bluetooth-scan`):
- Tarama yalnızca BLE'dir ve 15 saniye sürer. Adı `TACHOGRAPH-` ile başlayan ya da MAC adresi `00:03:73` ile başlayan cihazlar listelenir.
- Android'de telefonla eşleşmiş takograflar yayın yapmasalar da listede görünür ve eşleşmeleri buradan kaldırılabilir.
- Bağlantının her aşaması ekranda gösterilir: bağlanıyor, servisler aranıyor, eşleşme, abone olunuyor, hazır. Eşleşme, Numeric Comparison ile yapılır: takograf ekranındaki 6 haneli kodla telefondaki kod karşılaştırılıp iki tarafta da onaylanır.
- Seçilen tip ile cihazın gerçek tipi uyuşmazsa (ITS servisleri var ya da yok) uygulama sorar: tipi değiştir, yine de bağlan ya da vazgeç.

### Ana sekmeler

| Sekme | Rota | İçerik |
|---|---|---|
| **Panel** | `/dashboard` | Sürücü 1/2 seçimi, güncel aktivite, hız ve kilometre, molaya kalan süre. Ayrıca sürekli, günlük ve haftalık sürüş kullanımı, sonraki mola, günlük ve azaltılmış dinlenme, telafi borçları, ihlal özeti. **Sürücü bilgileri** penceresi iki yuvadaki kartın sahibini gösterir: ad, ülke, kart no, dil, son geçerlilik ve zorunlu indirme tarihi. |
| **Uyarılar** | `/logs` | İhlaller kategoriye göre: sürüş/dinlenme, kart kullanımı, hız aşımı, güvenlik, donanım (VU olay ve arızaları), bakım. Altında olay günlüğü. |
| **Zaman çizelgesi** | `/timeline` | Günlük aktivite çubuk grafiği, sürücü 1/2 seçimi, aktivite ve ihlal listesi. Yalnızca canlı okunan verilerden beslenir, `.ddd` dosyalarından değil. |
| **Analiz** | `/analysis` | 28 günlük risk skoru, haftalık ceza trendi ve "Cezalar ve Ciddiyetleri" referansı. Ayrıca bildirimler, öneriler ve yatay **sürüş modu** (`/driver-mode`) ekranı. |
| **ITS** | `/vu` | Takograf araçları (aşağıda). |
| **Ayarlar** | `/settings` | Cihaz bilgileri: VIN/VRN, üye ülke, üretici, ECU tarihleri, HW/SW sürümleri, tip onayı. Dil, tema, serbest ekran modu ve canlı veri yenileme aralığı (kapalı, 30 sn, 60 sn, 5 dk). |

Üst çubukta selamlama (karttaki sürücü adıyla), elle yenileme, bağlantı ve ihlal bildirim zili vardır. Profil menüsünden **Hakkında** sayfasına ve çıkışa ulaşılır.

### Kurallar, ihlaller ve cezalar

- **İhlal analizi** (`ViolationAnalyzer`), AB 561/2006 kurallarını uygular:
  - Sürekli sürüş (Md. 7, 15+30 mola bölmesi dahil).
  - Günlük sürüş (Md. 6/1, haftada en fazla iki kez 10 saate uzatma).
  - Haftalık 56 saat ve iki haftalık 90 saat.
  - Günlük dinlenme 11/9 saat ve 3+9 bölme.
  - Haftalık dinlenme 45/24 saat, altı 24 saatlik dönem içinde.
  - Eksik kayıt (Md. 15).

  Her ihlale AB 2016/403'e göre bir ciddiyet seviyesi verilir: MI, SI, VSI ya da MSI.
- **Ceza hesabı** (`PenaltyCalculator`), KTK 2918 md. 49/3 kapsamında 2026 tutarlarını TL olarak hesaplar. Peşin ödemede %25 indirim uygulanır; işletme için tutar iki katıdır. Her ihlal için 20 ceza puanı ve sürücü belgesine el koyma bilgisi de verilir.
- **Risk skoru** (`RiskScoreCalculator`), 28 günlük pencerede 0–100 arası hesaplanır: 80 ve üstü düşük, 50 ve üstü orta, altı yüksek risk.
- **Bildirimler:** ihlal özeti, uyum bildirimleri ve haftalık telafi borcu sistem bildirimi olarak gösterilir.

### ITS araçları (yalnız ATC 8256)

| Araç | Rota | Ne yapar |
|---|---|---|
| **Uzaktan kumanda (RHMI)** | `/vu/rhmi` | AB Remote HMI. Yuva 1, Yuva 2 ve araç içi istemciler için şunları yapar: <ul><li>Eşleştirme: takograf ekranındaki 8 haneli kodla; doğrula ve unut da buradadır.</li><li>Oturum açma ve kapama, saat farkı kontrolü.</li><li>Aktivite seçme, yer girişi (ülke ve bölge), özel durum, yükleme ve boşaltma.</li><li>Uyarıları okuma ve onaylama.</li><li>Çıktı alma, kart çıkarma, manuel giriş.</li></ul> |
| **Veri indirme** | `/vu/download` | Annex 7 indirmesi ITS indirme servisinden yapılır. <ul><li>Kart, VU ya da ikisi birden indirilebilir.</li><li>VU aktiviteleri, olay ve arızalar, detaylı hız ve teknik veri ayrı ayrı seçilir.</li><li>Nesil: Gen1, Gen2 v1 ya da Gen2 v2 (varsayılan).</li><li>Tarih aralığı varsayılan 28 gün, en fazla 62 gün.</li></ul> |
| **Kalibrasyon (tanı konsolu)** | `/vu/calibration` | Annex 8 ham istek konsolu. Baytlar SID'den itibaren yazılır; başlık, uzunluk ve checksum uygulama tarafından eklenir. Yanıtlar çözülerek gösterilir ve sık kullanılan RDBI istekleri hazır düğme olarak bulunur. |

STC 8255 seçiliyken bu sekmede yalnızca **İndirilen dosyalar** bulunur.

### İndirilen dosyalar (`/ddd-files`)

- **Liste:** kaydedilen `.ddd` dosyaları kart, takograf ya da ikisi birden etiketleriyle listelenir. Dosyalar sıralanabilir, çoklu seçilebilir ve paylaşılabilir. Silinen dosyalar çöp kutusuna (`/ddd-files/trash`) gider; oradan geri alınabilir ya da kalıcı olarak silinebilir.
- **Kart dosyası ayrıntısı** (`/ddd-files/:id`): kimlik, ehliyet ve kullanım, kullanılan araçlar, son kontrol, yerler, özel durumlar, olay ve arızalar, ihlaller. Gen1 ve Gen2 kartları desteklenir; Gen2 kartta iki uygulama da okunur ve en yeni gün alınır.
- **VU dosyası ayrıntısı:** VIN/VRN, indirilebilir dönem, teknik veri, kalibrasyonlar, hız ve olaylar. Gen1, Gen2 v1 ve Gen2 v2 desteklenir; imza ve sertifikalar doğrulanmaz.
- **PDF raporu:** yazdırma ya da paylaşım için PDF olarak dışa aktarılabilir.

---

## Kurulum ve çalıştırma

### Gereksinimler

- **Flutter:** 3.47.x stable. iOS iş akışı 3.47.6 kullanır.
- **Dart SDK:** `^3.12.2`.
- **Android:** Android Studio ya da Android SDK, BLE destekli bir telefon.
- **iOS:** yerel derleme için macOS ve Xcode gerekir. Mac yoksa [aşağıdaki bulut derlemesi](#iphonea-yükleme-mac-olmadan) kullanılır.

### Komutlar

```bash
flutter pub get
```

```bash
flutter run
```

```bash
flutter run --release
```

```bash
flutter analyze
```

```bash
flutter test
```

```bash
flutter build apk --release
```

`flutter run` debug modda çalışır. Debug derlemesinde animasyonlar, özellikle klavye açılırken, belirgin biçimde yavaştır. Performansı değerlendirmek için `--release` kullanın.

### Geliştirici derlemesi

`lib/core/config/dev_flags.dart` içindeki `kDeveloperBuild`, release dışı derlemelerde açıktır. İstenirse `--dart-define=SMARTTRACK_DEV=true|false` ile ayarlanır. Açıkken üst çubukta bir terminal simgesi görünür ve **uygulama günlüğüne** (`/kline-log`) gider. Günlük PDF ya da metin olarak paylaşılabilir; BLE, ITS ve RHMI trafiğinin tamamını içerir.

---

## iPhone'a yükleme (Mac olmadan)

iOS uygulaması yalnızca macOS'ta derlenebilir. Bunun yerine `.github/workflows/ios-build.yml` GitHub'ın macOS makinesinde imzasız bir `.ipa` üretir.

1. GitHub'da **Actions → iOS build (unsigned .ipa) → Run workflow**. Derleme yaklaşık 10–15 dakika sürer.
2. Bitince sayfanın altındaki `SmartTrack-ios-N` dosyasını indirin; zip'in içinde `SmartTrack.ipa` bulunur.
3. Windows'ta **Sideloadly** (ya da AltStore) ile iPhone'a USB üzerinden yükleyin. Bu araçlar Apple'ın sitesinden indirilen iTunes'u ister. Bu iş için ayrı bir Apple ID kullanılması önerilir.
4. iPhone'da:
   - **Ayarlar → Gizlilik ve Güvenlik → Geliştirici Modu**'nu açın.
   - **Ayarlar → Genel → VPN ve Cihaz Yönetimi**'nden geliştirici profiline **Güven** deyin.

**Ücretsiz Apple ID ile yüklenen uygulama 7 gün çalışır.** Aynı anda en fazla 3 uygulama yüklenebilir.

> **Maliyet kuralı:** Bu iş akışı hiçbir zaman ücretli dakika harcamamalıdır.
> - Yalnızca elle tetiklenir.
> - Yalnızca standart `macos-15` makinesinde çalışır; bu makine public repolarda ücretsizdir.
> - Repo private yapılırsa iş başlamadan atlanır.
> - Süre en fazla 30 dakika, çıktı 7 gün saklanır.
>
> İş akışında yapılacak her değişiklikte bu korumalar korunmalıdır.

iOS'ta eşleşme ayrı bir adım değildir: telefon kodu ilk korumalı abonelikte kendisi sorar. Eşleşme uygulamadan kaldırılamaz; bunun için **Ayarlar → Bluetooth** kullanılır.

---

## Mimari

- **Durum yönetimi:** harici bir paket yoktur. Uygulamanın durumu tek bir `ChangeNotifier`'da (`lib/core/providers/app_state.dart`) tutulur ve `AppStateProvider` (bir `InheritedWidget`) ile dağıtılır. Widget'lar `AppStateProvider.of(context)` ile okur.
- **Yönlendirme:** `go_router` (`lib/core/router/app_router.dart`). Açılış `/splash → /select-device → /connect` sırasıyla ilerler. Ana sekmeler `MainLayout` ile saran bir `ShellRoute` içindedir: dar ekranda alt gezinme çubuğu, geniş ekranda `NavigationRail`.
- **Yerelleştirme:** `lib/core/localization/localization.dart` içinde `section.key → {TR, EN, DE}` haritası bulunur; yaklaşık 645 anahtar vardır. `.arb` dosyası yoktur. Eksik çeviride önce TR'ye, sonra anahtarın kendisine düşülür. Seçilen dil kaydedilmez.
- **Sayfalar:** her özellik `lib/features/<ad>/` altında, çoğunlukla tek ve büyük bir sayfa dosyasıdır.
- **Hata yakalama:** `main.dart` her `debugPrint` çıktısını `AppLogService`'e yönlendirir (en fazla 25 000 satır). `FlutterError` ve zone hataları uygulamayı kapatmadan günlüğe yazılır.

---

## Bluetooth ve protokol katmanı

Canlı bağlantının tamamı `VuAppConnectionService` (`lib/core/bluetooth/services/`) üzerinden kurulur. Takografa göre davranışı `VuLinkProfile` belirler:

| | `stcDongle` (STC 8255) | `atc` (ATC 8256) |
|---|---|---|
| Önce eşleş (bond) | hayır | evet (Android) |
| ITS servislerine abone ol | hayır | evet |
| Çerçeve öneki | `0x0C` (indirmede `0x0D`) | yok |
| Çerçeveyi uzunluk baytlı biçime çevir (FMT `0x80`) | hayır | evet |
| Her okuma döngüsünde StartDiagnosticSession | evet | hayır |
| Mesajlar arası bekleme | 400 ms | yok |

**Bağlantı sırası:**
1. Bağlan.
2. Servisleri ara. Eşleşme bu sırada başlarsa arama yeniden yapılır.
3. Profil kontrolü: ITS servislerinin varlığı seçilen tiple uyuşmalı.
4. MTU 247 iste (Android).
5. Eşleş: takograf bağlanır bağlanmaz Security Request gönderir. Uygulama önce onun başlattığı eşleşmeyi bekler, `createBond`'u ancak 3 saniye içinde eşleşme başlamazsa çağırır. Böylece takograf ekranında iki kez kod çıkmaz.
6. App TX bildirimine, ATC 8256'da ayrıca iki ITS servisinin FIFO ve credits karakteristiklerine abone ol (indication).

**Uygulama servisi** (`lib/core/bluetooth/vu/vu_app_link.dart`, UUID `a1f3c62e-8d47-4b91-9e05-3c7a2f84d6b0`):
- Her pakette 2 baytlık `[toplam][sıra]` başlığı vardır. Paket yükü MTU − 5 bayttır; bir mesaj en fazla 261 bayt olabilir. Credit akış kontrolü yoktur.
- Aynı anda tek istek gönderilir; yanıt SID'den eşleştirilir.

**ITS servisleri** (Appendix 13; `its_channel.dart` ve `its_link.dart`):
- İndirme (`ITS-DDW`) ve tanı (`ITS-DIAG`) kanalları vardır; her birinde bir FIFO ve bir credits karakteristiği bulunur.
- Kanal 16 credit verilerek açılır; takografın `0xFF` yanıtı reddettiği ya da kanalı kapattığı anlamına gelir. Credit'ler azaldıkça otomatik olarak yenilenir.
- Takograf `0x78` (yanıt bekleniyor) dedikçe beklenir; açılış zaman aşımı 5 saniyedir.

**Protokol dosyaları** (`lib/core/services/`):
- `kline_protocol.dart`: KWP2000 / ISO 14230 çerçeveleri, RDBI kayıt kimlikleri (`TachoRecordId`), yanıt ayrıştırıcıları ve `TachographLiveData`. Checksum, önceki baytların toplamının `& 0xFF`'idir.
- `its/appendix7.dart` ve `its/its_download_service.dart`: Annex 7 indirmesi.
- `its/diag_decoder.dart`: Annex 8 yanıtlarının çözümü.
- `rhmi/`: Remote HMI.
  - `Rhmi`: RoutineControl `0x31` RID'leri `F200`–`F214`, CRC32, imzalı istek kuyruğu ve token ile gizleme çözümü.
  - `RhmiController`: alışverişlerin akışını yönetir.
  - `RhmiPairingStore`: oturum kimliklerini saklar.
- `real_card_*`, `tachograph_parser.dart` ve `vu/`: kart ve VU `.ddd` çözücüleri.

**Canlı veri:**
- Bağlanınca yaklaşık 60 RDBI okuması yapılır.
- Sonra veriler seçilen aralıkta (varsayılan 60 sn) ya da yalnızca elle yenilenir.
- Art arda 3 döngü yanıt alınamazsa bağlantı kopmuş sayılır.
- Android'de bağlantı sürerken bir ön plan servisi (`TachographConnectionService`) uygulamayı ayakta tutar.

---

## Veri saklama

**`shared_preferences`:**
- Takograf modu, aktif sürücü ve rol.
- Tema, serbest ekran modu ve yenileme aralığı.
- Canlı aktivite günlükleri (sürücü 1 ve 2), uyum ve canlı veri anlık görüntüleri.
- `.ddd` dosya dizini (`ddd_files_index`).
- RHMI oturum kimlikleri (`rhmi/<cihaz>/<istemci>/sid`).
- Bildirim durumu.

**Dosyalar:**
- **Uygulama klasörü:** `.ddd` dosyaları `<uygulama belgeleri>/smarttrack/ddd/<id>.ddd` altında tutulur; VU kısmı `<id>_vu.ddd` dosyasındadır.
- **Kullanıcının göreceği kopyalar:** her kayıttan sonra bir kopya kullanıcının erişebileceği yere yazılır.
  - **Android:** `Documents/SmartTrack/Kart` ve `Documents/SmartTrack/Takograf` (MediaStore).
  - **iOS:** uygulama belgeleri altında `SmartTrack/Kart` ve `SmartTrack/Takograf`. Dosyalar uygulamasından görülebilir.

---

## Platform yapılandırması

**Android** (`com.example.smarttrack_mine`):
- **İzinler:** `BLUETOOTH_SCAN` (`neverForLocation`), `BLUETOOTH_CONNECT`, konum (Android 11 ve öncesi için; reddedilirse bağlantı yine de kurulur), `FOREGROUND_SERVICE_CONNECTED_DEVICE`, `POST_NOTIFICATIONS` ve `INTERNET`.
- **Ön plan servisi:** `TachographConnectionService` (`connectedDevice` tipinde).
- **MethodChannel'lar:**
  - `com.smarttrack/background_service`: ön plan servisini başlatır ve durdurur.
  - `com.smarttrack/public_storage`: dosyayı MediaStore'daki Documents klasörüne yazar.

**iOS:**
- **İzin metinleri:** `NSBluetoothAlwaysUsageDescription` ve `NSLocationWhenInUseUsageDescription`.
- **Arka plan:** `UIBackgroundModes = bluetooth-central`.
- **Dosya paylaşımı:** `UIFileSharingEnabled` açık.
- **Google ile oturum açma:** `GIDClientID`.
- **İzin isteme farkı:** iOS'ta Android'e özgü izinler istenmez; Bluetooth iznini CoreBluetooth ilk kullanımda kendisi sorar.

---

## Testler

```bash
flutter test
```

| Dosya | Kapsam |
|---|---|
| `driving_time_calculator_test.dart` | Md. 7 mola bölmesi, 4,5 / 9 / 56 / 90 saat sınırları, telafi süreleri |
| `violation_analyzer_test.dart` | Günlük ve haftalık dinlenme, 10 saat uzatmalar, AB 2016/403 eşikleri |
| `penalty_calculator_test.dart` | KTK 49/3 kademeleri, 2026 tutarları, indirim, işletme ×2 |
| `risk_score_calculator_test.dart` | Skor ölçekleme, tavanlar, alt sınır |
| `kline_protocol_test.dart` | Çerçeve ve checksum, RDBI ayrıştırma |
| `real_card_*_test.dart` | Kart blokları, aktivite ve kimlik; Gen2 kart (`test/fixtures/card/gen2_driver_bench.ddd`) |
| `vu/*_test.dart` | VU Gen1 yapı taşları, Gen2 v2 indirme (`test/fixtures/vu/gen2_v2_bench.ddd`) |
| `its_channel_test.dart` | ITS credit akışı, Annex 7 TRTP ve blok ayrıştırma |
| `vu_app_link_test.dart` | Paket bölme ve birleştirme, KWP çerçeve dönüşümü, SID eşleştirme |
| `rhmi_test.dart` | CRC32, token ile gizleme çözümü, manuel giriş gövdesi |
| `analysis_page_sheet_test.dart` | Ceza referansı alt sayfası, sayfa yeniden kurulduğunda |

`test/widget_test.dart` Flutter şablonundan kalan sayaç testidir ve **başarısız olur** (bkz. [Bilinen eksikler](#bilinen-eksikler)).

---

## Klasör yapısı

```
lib/
├── main.dart                     Uygulama girişi, günlük ve hata yakalama
├── core/
│   ├── bluetooth/
│   │   ├── services/             VuAppConnectionService (canlı yol), BLE tarayıcı
│   │   └── vu/                   Uygulama servisi paket biçimi, profiller, ITS kanalı
│   ├── config/dev_flags.dart     kDeveloperBuild
│   ├── localization/             TR/EN/DE metinleri
│   ├── models/                   Takograf tipi, roller, .ddd modelleri
│   ├── providers/app_state.dart  Uygulama durumu
│   ├── router/app_router.dart    Rotalar
│   ├── services/                 Bağlantı, protokol, kurallar, ceza, dosya, PDF, bildirim
│   │   ├── its/                  Annex 7 indirme, Annex 8 çözücü
│   │   ├── rhmi/                 Remote HMI
│   │   └── vu/                   VU .ddd çözücüleri (Gen1, Gen2)
│   └── widgets/                  MainLayout, uyarı bantları, bildirim köprüsü
└── features/                     Sayfalar (dashboard, alerts, analysis, timeline,
                                  vu_tools, rhmi, its_download, its_calibration,
                                  ddd_files, settings, onboarding, splash, about, debug)
android/app/src/main/kotlin/      MainActivity (MethodChannel'lar), ön plan servisi
.github/workflows/ios-build.yml   Elle tetiklenen iOS derlemesi
docs/                             Ek teknik notlar
test/                             Birim ve widget testleri, .ddd fixture'ları
```

---

## Bilinen eksikler

Kodda bulunan ama uygulamada **çalışmayan ya da ulaşılamayan** kısımlar:

| Konu | Durum |
|---|---|
| GPS rota haritası | `RouteMapCard` ve `GpsTrackingService` var ama hiçbir sayfaya bağlı değil. Uygulamada harita yoktur. |
| Google Drive yedeği | Analiz sayfasında oturum açma ve açma/kapama düğmesi var, ancak `uploadDddFile` hiçbir yerden çağrılmıyor; hiçbir dosya yüklenmiyor. |
| Hata ayıklama sayfaları | `/debug-values`, `/dongle-values`, `/dongle-log` ve `/dongle-download-results` rotaları var ama uygulama içinden ulaşılamıyor. Yalnızca `/kline-log`'a ulaşılabiliyor. |
| K-line dongle üzerinden `.ddd` indirme | `DddDownloadService` ve `downloadRealDddFromDongle` hiçbir yerden çağrılmıyor. Canlı indirme yolu ITS'tir (yalnız ATC 8256). |
| Eski bağlantı katmanları | Classic SPP (`flutter_classic_bluetooth` hâlâ bağımlılıklarda), simüle bağlantı ve genel BLE bağlantı servisleri canlı bağlantıda kullanılmıyor. |
| Roller | Sürücü, işletme ve polis rolleri tanımlı, ancak rolü değiştirecek bir arayüz yok; uygulama hep sürücü rolündedir. |
| Örnek ve simüle `.ddd` | `assets/ddd_samples` paketlenmiş ve `DddSimulator` duruyor, ancak ikisi de hiçbir yerden çağrılmıyor. |
| Dil seçimi | Seçilen dil kaydedilmez; uygulama her açılışta Türkçe başlar. |
| `test/widget_test.dart` | Flutter şablonundan kalma sayaç testi; `flutter test` bu test yüzünden bir hata verir. |
| Uygulama kimliği | Android ve iOS hâlâ şablondan kalan `com.example.smarttrack_mine` / `com.example.smarttrackMine` kimliklerini kullanıyor. |

---

## Repolar

| Konum | Adres | Dal |
|---|---|---|
| Azure DevOps (şirket) | `https://azuredevops/ATC8256_Project/ATC_Utils/_git/SmartTrack_Driver_MobileApp` | `master` |
| GitHub | `https://github.com/benilyalcin/SmartTrack` | `master` |

İki kopya birbirinden bağımsızdır; aralarında otomatik eşitleme yoktur. Yerel klonda Azure DevOps'un remote adı `azure`, GitHub'ınki `origin`'dir:

```bash
git push azure master
```

```bash
git push origin master
```

iOS derlemesi yalnızca GitHub kopyasında çalışır, çünkü GitHub Actions kullanır.

---

## Ek belgeler

- [`docs/DriverAppRecordIds.md`](docs/DriverAppRecordIds.md): uygulamanın STC 8255'ten okuduğu K-line RDBI kayıt kimlikleri ve henüz kullanılmayanlar. Bazı bölümleri eskidir; sürücü 2 verileri artık okunuyor.
- [`docs/TODO_VU_Gen2_Parsing.md`](docs/TODO_VU_Gen2_Parsing.md): Gen2 VU indirmelerinin nasıl çözüldüğü ve neyin henüz çözülmediği. Örneğin sınır geçişleri, yükleme ve boşaltma, GNSS ve imzalar.
- [`CLAUDE.md`](CLAUDE.md): kod tabanına dair geliştirici notları.
