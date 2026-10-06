# TODO: Gen2 (v1/v2) VU dosyalarını uygulama içinde ayrıştırmak

**Durum (2026-10-06):** ATC 8256'dan ITS üzerinden indirilen VU dosyaları
kaydediliyor ve paylaşılabiliyor, ama uygulama içinde Overview, Activities,
Events/Faults, Detailed Speed ve Technical Data bölümleri boş görünüyor.
ATC 8256 pratikte hep **Gen2 v2** indirme verecek, bu yüzden bu iş
yapılmadıkça ATC'nin VU verisi Analiz/Çizelge'ye girmez.

Bu, mobil uygulamaya bir tachograph file viewer yazmak demek; ayrı bir iş
olarak planlanmalı.

## Neden boş görünüyor

`lib/core/services/vu/` altındaki çözücü yalnız Gen1'i tanıyor:

- `vu_block_framer.dart` blok başı olarak yalnız `76 01..06` arıyor.
  Gen2 v1 TREP'leri `0x21..0x25`, Gen2 v2 TREP'leri `0x31..0x35`; hiçbiri
  bulunmuyor.
- Blok içleri Gen1'in sabit düzenine göre okunuyor. Gen2'de her blok bir
  **RecordArray** dizisi: `recordType (1) | recordSize (2) | noOfRecords (2)`
  ve ardından kayıtlar. İmzalar da ayrı bir RecordArray olarak geliyor.

## Örnek dosya (bench, 2026-10-06, 23 880 bayt)

| Konum | Başlık | Blok |
|---|---|---|
| 0 | `76 31` | Overview (v2) — ilk RecordArray `04 00CD 0001` |
| 795, 1278 | `76 32` | Activities (gün başına bir blok) |
| 1465 | `76 33` | Events and faults |
| 6548 | `76 24` | Detailed speed (v2 bu transferde v1 değerini kullanır, `0x34` yok) |
| 22240 | `76 35` | Technical data |

## Yapılacaklar

1. `vu_block_framer.dart`: `0x21..0x25` ve `0x31..0x35` (ve `0x24`)
   TREP'lerini tanı; nesli bloktan çıkar.
2. Ortak bir RecordArray okuyucu: tip/boyut/adet başlığını yürüyerek
   kayıtları ayıran, bilinmeyen tipleri atlayan bir katman
   (`Appendix7.parseDownloadablePeriod` bunun küçük bir örneği).
3. Her TREP için Annex 1C Appendix 7'deki Gen2 kayıt tiplerini mevcut
   modellere eşle (`VehicleUnitData`): Overview (VIN/VRN, kart takma/çıkarma,
   kalibrasyon özeti, VuDownloadablePeriod), Activities (VuActivityDailyRecord,
   CardIW, Place, GNSS AD), Events/Faults, Detailed Speed, Technical Data.
4. v1 ile v2 arasındaki farklar (v2'de ek kayıtlar: border crossing,
   load/unload, GNSS konumları) için sürüm kontrolü.
5. İmza ve sertifika doğrulaması kapsam dışı kalabilir; ama imza
   RecordArray'leri atlanmalı.
6. Testler: bu örnek dosyayı `assets/ddd_samples/` altına koyup (kişisel
   veri yoksa) gerçek dosya testi.

Gen1 indirmeyi uygulama okuyabiliyor; o zamana kadar uygulama içinde görmek
için Veri indirme ekranında **Gen 1** seçilebilir.
