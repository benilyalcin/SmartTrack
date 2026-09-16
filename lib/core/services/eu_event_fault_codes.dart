class EuEventFaultCodes {
  EuEventFaultCodes._();

  static const Map<int, String> eventLabels = {
    1: 'Geçersiz kart takıldı',
    2: 'Kart çakışması',
    3: 'Zaman çakışması',
    4: 'Uygun olmayan kartla sürüş',
    5: 'Sürüş sırasında kart takıldı',
    6: 'Kart oturumu düzgün kapatılmadı',
    7: 'Hız aşımı',
    8: 'Güç kesintisi',
    9: 'Hareket verisi hatası',
    10: 'Araç hareket çakışması',

    19: 'Hareket sensöründe yetkisiz değişiklik',
  };

  static const Map<int, String> faultLabels = {
    48: 'Kayıt cihazı arızası: detay yok',
    49: 'Kayıt cihazı arızası: cihaz iç arızası',
    50: 'Kayıt cihazı arızası: yazıcı arızası',
    51: 'Kayıt cihazı arızası: ekran arızası',
    52: 'Kayıt cihazı arızası: indirme arızası',
    53: 'Kayıt cihazı arızası: sensör arızası',
    64: 'Kart arızası: detay yok',
  };

  static String eventLabel(int code) =>
      '${eventLabels[code] ?? 'Bilinmeyen olay'} (kod $code)';

  static String faultLabel(int code) =>
      '${faultLabels[code] ?? 'Bilinmeyen arıza'} (kod $code)';
}
