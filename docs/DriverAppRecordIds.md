# Sürücü Uygulaması — K-LINE RDBI Kayıt ID'leri (Hex)

Bu doküman, SmartTrack'in **sürücü uygulaması** tarafının (Dashboard / Timeline / Logs — kalibrasyon değil) STC-8255'ten `0x22` RDBI (ReadDataByIdentifier) ile okuduğu / okuması gereken kayıt ID'lerini listeler. Kaynak: `lib/core/services/kline_protocol.dart` (`TachoRecordId`), STC-8255 Preparation Manual §7, CalibrationMessages.md ve **BS ISO 16844-7:2015 (Road vehicles — Tachograph systems — Part 7: Parameters), Table 1** (otoriter DID kaynağı).

Kalibrasyon/workshop tarafına özel olanlar (SecurityAccess `0x27`, WriteDataByIdentifier `0x2E`, IOControl `0x2F`, RoutineControl `0x31`, `0xFD00-0xFD53` opsiyonel ayarlar bloğu, `0x8250`/`0x8255` option record, CAN config DID'leri) bilinçli olarak bu listenin dışında tutulmuştur — sürücü uygulaması bunlara dokunmamalı.

## 1. Mevcut — zaten okunuyor

### Kimlik / araç bilgisi
| DID | Alan |
|---|---|
| `0xF190` | VIN |
| `0xF97E` | VRN (Plaka) |
| `0xF97D` | Registering Member State |
| `0xF97F` | Vehicle Registration Date |
| `0xF18A` / `0xF18B` / `0xF18C` | Supplier ID / ECU Mfg Date / ECU Serial Number |
| `0xF192` / `0xF193` | System Supplier ECU HW Number / HW Version |
| `0xF194` / `0xF195` | System Supplier ECU SW Number / SW Version |
| `0xF196` | Type approval numarası |
| `0xF19B` | Calibration Date |
| `0xF19D` | ECU Installation Date |

### Canlı veri
| DID | Alan |
|---|---|
| `0xF902` | Anlık hız (km/h) |
| `0xF912` | Odometre (yüksek çözünürlük) |
| `0xF913` | Trip distance |
| `0xF90B` | Güncel tarih/saat |

### Kalibrasyon sabitleri (salt-okunur gösterim amaçlı — yazma yok)
| DID | Alan |
|---|---|
| `0xF918` | K-Constant |
| `0xF91D` | W-Constant |
| `0xF91C` | Tyre circumference |
| `0xF921` | Tyre size |
| `0xF92C` | Speed limit |
| `0xF922` | Next calibration date |

### Kart / sürücü durumu
| DID | Alan |
|---|---|
| `0xF930` / `0xF933` | Kart slot 1 / slot 2 doluluk durumu |
| `0xF916` / `0xF917` | Driver1 / Driver2 Identification (issuing state + kart no) |
| `0xF931` / `0xF932` | Driver1 / Driver2 Name |
| `0xF981` / `0xF982` | Driver1 / Driver2 preferred language |
| `0xF99D` / `0xF98B` | Driver1 / Driver2 card expiry date |
| `0xF99E` / `0xF98C` | Driver1 / Driver2 next mandatory download date |
| `0xF903` | Driver1 working state (rest / available / work / driving) |
| `0xF906` / `0xF909` | Driver1 / Driver2 time-related states (pre-warning/warning bitleri) |

### EU 561/2006 sürüş süresi sayaçları — Driver1 ve Driver2 (BS ISO 16844-7:2015 Table 1 ile doğrulandı)
| DID (Driver1) | DID (Driver2) | Alan | Cvt |
|---|---|---|---|
| `0xF903` | `0xF904` | Working state (rest/available/work/driving) | M |
| `0xF923` | `0xF924` | Continuous driving time | M |
| `0xF925` | `0xF926` | Cumulative break time | M |
| `0xF927` | `0xF928` | Current duration of selected activity | M |
| `0xF99A` | `0xF988` | Current daily driving time | U |
| `0xF99B` | `0xF989` | Current weekly driving time | U |
| `0xF9B3` | `0xF9B4` | Remaining 2-week driving time | U |

Tüm bu Driver2 DID'leri artık `kline_protocol.dart` → `TachoRecordId`'de tanımlı (`driver2WorkingState`, `driver2ContinuousDrivingTime`, `driver2CumulativeBreakTime`, `driver2CurrentDurationOfActivity`, `driver2CurrentDailyDrivingTime`, `driver2CurrentWeeklyDrivingTime`, `driver2Remaining2WeeksDrivingTime`). **Not henüz yapılan:** bu sabitler `bluetooth_service.dart`'taki handshake/refresh akışına ve `TachographLiveData` modeline bağlanmadı — bunlar şu an sadece sabit olarak mevcut, okunmuyor. Co-driver DAGS ekranı (dashboard'da "Driver 2" sekmesi) istenirse ayrı bir işte bağlanmalı.

## 2. Daha önce eksik olan Driver2 sayaçları — artık çözüldü

Manual'daki "Driver 2 DAGS Times (#4)" ekranı (§2.3.1.4) cihazın co-driver için de sürüş/mola/haftalık süre saydığını gösteriyordu, ama CalibrationMessages.md ve STC-8255 Preparation Manual §7 bu DID'leri listelemiyordu. **BS ISO 16844-7:2015 Table 1** ile bu DID'ler artık kesin olarak doğrulandı (yukarıdaki tablo) ve `kline_protocol.dart`'a eklendi — tahmine gerek kalmadı.

Ayrıca ilginç bir not: `driver2CardNextMandatoryDownloadDate = 0xF98C` için kod tabanındaki mevcut yorum ("standardın kendi içinde Table 1 ile §5.4.93 arasında çelişki var") **gerçek spec metniyle doğrulandı** — BS ISO 16844-7:2015'in Table 1'i `0xF98C`'yi Driver2CardNextMandatoryDownloadDate olarak listelerken, §5.4.93'ün kendi Table 109'u `0xF99F` diyor (ve simetrik olarak §5.4.94 TachographNextMandatoryDownloadDate için Table 110 da `0xF98C` diyor). Bu standardın kendi içindeki gerçek bir tutarsızlık; kod Table 1'i esas aldığı için değişiklik gerekmedi.

## 3. Yüksek değerli ek DID'ler — spec'te var, kodda henüz yok

BS ISO 16844-7:2015'in tam metni, `driving_time_calculator.dart`'ın şu an yerel olarak (fake `_simulateDrivingHistory` verisiyle) hesapladığı EU 561/2006 kalan-süre bilgilerinin **cihaz tarafından zaten hesaplanıp RDBI ile okunabildiğini** gösteriyor. Bunlar implement edilirse yerel hesaplama motoru yerine gerçek cihaz verisi kullanılabilir:

| DID (Driver1) | DID (Driver2) | Alan |
|---|---|---|
| `0xF9AD` | `0xF9AE` | Remaining current driving time (sonraki mola/dinlenmeye kadar kalan azami sürüş) |
| `0xF9AF` | `0xF9B0` | Remaining driving time on current shift |
| `0xF9B1` | `0xF9B2` | Remaining driving time of current week |
| `0xF99C` | `0xF98A` | Time left until new daily rest period |
| `0xF9A1` | `0xF98D` | Time left until new weekly rest period |
| `0xF9A3` | `0xF9A7` | Minimum daily rest (gerekli asgari dinlenme) |
| `0xF9A4` | `0xF9A8` | Minimum weekly rest |
| `0xF9AB` | `0xF9AC` | Number of used reduced daily rest periods |
| `0xF9CD` | `0xF9CE` | Additional information (bit-encoded: kalan 10h sürüş hakkı sayısı, kalan azaltılmış günlük dinlenme sayısı, "unknown period" bayrağı, kart veri yeterliliği, haftalık dinlenme hesap durumu, multi-manning/crew tespiti, zaman çakışması tespiti — bkz. BS ISO 16844-7 Table 152) |

Bu tablo manual'ın "Driver 1 Weekly DAGS Times" (#5), "Driver 1 Daily DAGS Times" (#6) ve "DAGS Extended Information" (#7) ekranlarının doğrudan karşılığı. **Henüz `kline_protocol.dart`'a eklenmedi** — CLAUDE.md'de not edildiği gibi bu, ayrı bir "gerçek cihaz verisiyle DAGS hesaplama" işi olarak planlanmalı, bu doküman kapsamının dışında bırakıldı.

## 4. Kasıtlı olarak kapsam dışı (workshop/calibration)

- `0x27` SecurityAccess (RequestSeed/SendKey — PIN girişi)
- `0x2E` WriteDataByIdentifier (VIN/VRN/k/w/tyre/next-cal yazma)
- `0x2F` IOControl (hız sinyali, RTC test çıkışı vb.)
- `0x31` RoutineControl (Test Menu: display/printer/keypad/battery/buzzer testleri)
- `0xFD00`–`0xFD53` opsiyonel ayarlar bloğu (backlight, CAN config, download period, prewarning eşikleri vb.)
- `0x8250` / `0x8255` option record (blok konfigürasyon yazımı)
- CAN-A / CAN-C konfigürasyon DID'leri (baud rate, sync jump, TCO1 period/priority vb.)

Bunların hepsi `0x10 0x85` (ECUProgrammingSession) veya `0x10 0x87` (ECUAdjustmentSession) gerektirir ve workshop kartı + PIN olmadan zaten erişilemez; sürücü uygulaması bu akışlara girmemeli.
