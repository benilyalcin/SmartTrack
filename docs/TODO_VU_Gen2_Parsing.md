# Gen2 (v1/v2) VU dosyalarını ayrıştırma

**Durum (2026-10-06):** Yapıldı. `lib/core/services/vu/vu_gen2_decoder.dart`
Gen2 v1 (TREP `0x21..0x25`) ve v2 (`0x31..0x35`, detaylı hız `0x24`)
indirmelerini okuyor. `VuFileDecoder.decode` dosyanın ilk TREP'ine bakıp
Gen2'yi oraya yönlendiriyor; Gen1 eski çözücüde kaldı.

## Nasıl okunuyor

Her blok bir RecordArray dizisi: `recordType (1) | recordSize (2) |
noOfRecords (2)` ve ardından kayıtlar. Dosya bu başlıklarla yürünüyor,
arama yok. Bir kayıt v1 ile v2'nin ortak olan baş alanlarından okunuyor;
v2'nin sona eklediği alanlar okunmuyor, bu yüzden iki sürüm aynı kodla
çözülüyor. Her blok imza RecordArray'i ile biter; kesik bir dosyada imzasına
kadar gelmemiş blok atılıyor (yarım bir gün gösterilmesin diye).

| Blok | Okunanlar | Model |
|---|---|---|
| Overview | VIN, plaka, saat, indirilebilir dönem, son indiren firma | `vin`, `vehicleRegistrationNumber`, `VuOverviewData` |
| Activities | gün, gece yarısı km, kart takma/çıkarma, aktivite değişimleri, yerler, özel durumlar | `VuDailyActivity` |
| Events/Faults | olaylar, arızalar, hız aşımı olayları | `VuEventOrFault`, `VuOverspeedingEvent` |
| Detailed speed | 64 baytlık dakika blokları (Gen1 ile aynı) | `VuSpeedSession` |
| Technical | VuIdentification, eşleşmiş sensör, kalibrasyonlar | `VuTechnicalData`, `VuCalibrationRecord` |

Ad alanlarında kod sayfası 9 (ISO 8859-9) Türkçe çözülüyor.

## Okunmayanlar (gerekirse sonraki iş)

Modelde karşılığı olmadığı için okunmayan kayıtlar:

- v2 sınır geçişleri (`0x22`) ve yükleme/boşaltma (`0x23`)
- GNSS birikimli sürüş konumları (`0x16`)
- ITS onayları, zaman ayarlamaları, güç kesintileri
- şirket kilitleri, kontrol faaliyetleri, kart kayıtları

İmza ve sertifika doğrulaması yapılmıyor.

## Test

`test/vu/vu_gen2_decoder_test.dart`, bench ATC 8256'dan alınan
`test/fixtures/vu/gen2_v2_bench.ddd` (23 880 bayt, Gen2 v2) ile.
