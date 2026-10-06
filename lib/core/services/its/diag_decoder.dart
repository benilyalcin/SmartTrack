import '../kline_protocol.dart';
import '../rhmi/rhmi.dart';

/// Reads an Annex 8 answer the way its request asked for it - a port of
/// AvuItsTester's DiagDecoder.kt. [frame] is the long-form KWP2000 answer
/// ItsLink hands back.
class DiagDecoder {
  DiagDecoder._();

  static DiagDecoded decode(List<int> frame) {
    final sid = frame[4];
    final data = frame.length > 5 ? frame.sublist(5, 4 + frame[3]) : <int>[];
    if (sid == 0x7F && data.length >= 2) {
      return DiagDecoded(
        false,
        'Servis ${_h2(data[0])} reddedildi',
        '${RdbiResponseParser.describeNrc(data[1])} (${_h2(data[1])})',
      );
    }
    return switch (sid) {
      0xC1 => DiagDecoded(
        true,
        'İletişim başladı',
        'anahtar baytlar ${_hex(data)}',
      ),
      0x50 => DiagDecoded(
        true,
        'Diagnostik oturum başladı',
        data.isEmpty ? 'oturum baytı yok' : 'oturum ${_h2(data[0])}',
      ),
      0x62 => _read(data),
      0x71 => _routine(data),
      _ => DiagDecoded(
        true,
        'Servis ${_h2(sid - 0x40)} yanıtladı',
        _hexOr(data),
      ),
    };
  }

  static DiagDecoded _routine(List<int> d) {
    if (d.length < 3) return DiagDecoded(true, 'Rutin yanıtladı', _hex(d));
    final routine = (d[1] << 8) | d[2];
    final rest = d.sublist(3);
    if (routine == Rhmi.ridOpenSession &&
        d[0] == Rhmi.routineRequestResults &&
        rest.isNotEmpty) {
      return DiagDecoded(
        true,
        'RHMI oturum durumu (F211)',
        RhmiSessionStatus.of(rest[0])?.label ?? 'durum ${_h2(rest[0])}',
      );
    }
    return DiagDecoded(
      true,
      'Rutin ${routine.toRadixString(16).toUpperCase()} yanıtladı',
      _hexOr(rest),
    );
  }

  static DiagDecoded _read(List<int> d) {
    if (d.length < 2) return DiagDecoded(true, 'Okunan veri', _hex(d));
    final id = (d[0] << 8) | d[1];
    final v = d.sublist(2);
    final idHex = id.toRadixString(16).toUpperCase().padLeft(4, '0');
    final name = _names[id] ?? 'Tanımlayıcı $idHex';
    String? value;
    try {
      value = _value(id, v);
    } catch (_) {}
    value ??=
        '${_hexOr(v)}${_printable(v) == null ? '' : '  "${_printable(v)}"'}'
        '  ($idHex için çözücü yok)';
    return DiagDecoded(true, '$name ($idHex)', value);
  }

  static String? _value(int id, List<int> v) {
    String? need(int n, String Function() f) => v.length >= n ? f() : null;
    return switch (id) {
      0xF90B || 0xF97F => _timeDate(v),
      0xF902 => need(2, () => '${(v[0] + v[1] / 256).toStringAsFixed(2)} km/h'),
      0xF903 || 0xF904 => need(1, () => _activity(v[0])),
      0xF905 => need(1, () => v[0] == 1 ? 'sürüş' : 'sürüş yok'),
      0xF906 || 0xF909 => need(1, () => _timeWarning(v[0])),
      0xF907 || 0xF90A => need(
        1,
        () => v[0] == 1
            ? 'geçerli sürücü kartı takılı'
            : 'geçerli sürücü kartı yok',
      ),
      0xF908 => need(1, () => v[0] != 0 ? 'hız aşımı' : 'hız aşımı yok'),
      0xF912 || 0xF913 => need(
        4,
        () => '${(Rhmi.readU32(v, 0) * 5 / 1000).toStringAsFixed(3)} km',
      ),
      0xF916 ||
      0xF917 => need(19, () => '${_text(v, 0, 3)} ${_text(v, 3, 16)}'.trim()),
      0xF918 || 0xF91D => need(2, () => '${_u16(v, 0)} imp/km'),
      0xF91B => need(2, () => '${(_u16(v, 0) / 8).toStringAsFixed(3)} rpm'),
      0xF91C => need(2, () => '${(_u16(v, 0) / 8).toStringAsFixed(3)} mm'),
      0xF921 || 0xF190 => _text(v, 0, v.length),
      0xF922 => need(
        3,
        () => v[1] == 0
            ? 'ayarlanmamış'
            : '${_d2(v[1] ~/ 4 + 1)}.${_d2(v[0])}.${v[2] + 1985}',
      ),
      0xF923 || 0xF924 || 0xF99A => need(2, () => _minutes(_u16(v, 0))),
      0xF92C => need(2, () => '${(_u16(v, 0) / 256).toStringAsFixed(2)} km/h'),
      0xF930 || 0xF933 => need(1, () => _cardSlot(v[0])),
      0xF931 ||
      0xF932 => need(72, () => '${_text(v, 37, 35)} ${_text(v, 1, 35)}'.trim()),
      0xF936 => need(
        1,
        () => v[0] == 1 ? 'kapsam dışı aktif' : 'kapsam dışı değil',
      ),
      0xF937 => need(1, () => _mode(v[0])),
      0xF97D => need(3, () => _text(v, 0, 3)),
      0xF97E => need(14, () => _text(v, 1, 13)),
      0xF98B ||
      0xF99D => need(3, () => '${_d2(v[1] ~/ 4)}.${_d2(v[0])}.${v[2] + 1985}'),
      0xF9D5 => need(1, () => _loadType(v[0])),
      0xF9D7 => need(14, () => _position(v)),
      _ => null,
    };
  }

  static String? _timeDate(List<int> v) {
    if (v.length < 8) return null;
    final day = v[4] ~/ 4, month = v[3];
    if (day == 0 || month == 0) return 'ayarlanmamış';
    final t = DateTime.utc(v[5] + 1985, month, day, v[2], v[1], v[0] ~/ 4);
    final h = v[7] - 125, m = (v[6] - 125).abs();
    return '${_d2(t.day)}.${_d2(t.month)}.${t.year}-${_d2(t.hour)}:${_d2(t.minute)}:'
        '${_d2(t.second)} UTC (yerel fark ${h >= 0 ? '+' : ''}$h:${_d2(m)})';
  }

  static String _position(List<int> v) {
    int s24(int at) {
      final raw = (v[at] << 16) | (v[at + 1] << 8) | v[at + 2];
      return raw & 0x800000 != 0 ? raw - 0x1000000 : raw;
    }

    double degrees(int raw) {
      final m = raw.abs();
      final d = m ~/ 1000 + (m % 1000) / 10 / 60;
      return raw < 0 ? -d : d;
    }

    final time = Rhmi.readU32(v, 0);
    final lat = s24(5), lon = s24(8);
    final country =
        Rhmi.countries.where((c) => c.$1 == v[12]).firstOrNull?.$2 ??
        'ülke ${_h2(v[12])}';
    final place = lat == 0x7FFFFF || lon == 0x7FFFFF
        ? 'konum bilinmiyor'
        : '${degrees(lat).toStringAsFixed(5)}, ${degrees(lon).toStringAsFixed(5)}';
    final at = time == 0
        ? 'zaman yok'
        : DateTime.fromMillisecondsSinceEpoch(
            time * 1000,
            isUtc: true,
          ).toIso8601String();
    return '$place (${v[11] == 1 ? 'doğrulanmış' : 'doğrulanmamış'}), $at, $country';
  }

  static String _activity(int v) => switch (v) {
    0 => 'dinlenme / mola',
    1 => 'hazır bulunma',
    2 => 'diğer iş',
    3 => 'sürüş',
    _ => 'aktivite ${_h2(v)}',
  };

  static String _cardSlot(int v) => switch (v) {
    0 => 'kart yok',
    1 => 'sürücü kartı',
    2 => 'atölye kartı',
    3 => 'kontrol kartı',
    4 => 'şirket kartı',
    _ => 'durum ${_h2(v)}',
  };

  static String _mode(int v) => switch (v) {
    0 => 'operasyonel',
    1 => 'kontrol',
    2 => 'kalibrasyon',
    3 => 'şirket',
    _ => 'mod ${_h2(v)}',
  };

  static String _loadType(int v) => switch (v) {
    0 => 'tanımsız',
    1 => 'yük',
    2 => 'yolcu',
    _ => 'yük tipi ${_h2(v)}',
  };

  static String _timeWarning(int v) => switch (v) {
    0 => 'süre uyarısı yok',
    1 => '4s15 kesintisiz sürüş',
    2 => '4s30 kesintisiz sürüşe ulaşıldı',
    3 => 'günlük sürüş ön uyarısı',
    4 => 'günlük sürüş sınırına ulaşıldı',
    5 => 'günlük / haftalık dinlenme ön uyarısı',
    6 => 'günlük / haftalık dinlenme sınırı',
    7 => 'haftalık sürüş ön uyarısı',
    8 => 'haftalık sürüş sınırına ulaşıldı',
    9 => 'iki haftalık sürüş ön uyarısı',
    10 => 'iki haftalık sürüş sınırına ulaşıldı',
    11 => 'sürücü kartı süresi doluyor',
    12 => 'sürücü kartı indirme zamanı',
    _ => 'durum ${_h2(v)}',
  };

  static String _minutes(int t) => '${t ~/ 60} sa ${_d2(t % 60)} dk';
  static int _u16(List<int> v, int at) => (v[at] << 8) | v[at + 1];
  static String _d2(int v) => v.toString().padLeft(2, '0');
  static String _h2(int v) =>
      '0x${v.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  static String _hex(List<int> d) =>
      d.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
  static String _hexOr(List<int> d) => d.isEmpty ? 'veri yok' : _hex(d);

  static String _text(List<int> v, int at, int length) {
    final end = (at + length).clamp(0, v.length);
    if (at >= end) return '';
    return String.fromCharCodes(
      v.sublist(at, end).where((b) => b >= 0x20 && b != 0xFF),
    ).trim();
  }

  static String? _printable(List<int> v) {
    if (v.isEmpty || v.any((b) => (b < 0x20 || b > 0x7E) && b != 0))
      return null;
    final s = String.fromCharCodes(v.where((b) => b != 0)).trim();
    return s.isEmpty ? null : s;
  }

  static const Map<int, String> _names = {
    0xF190: 'VIN',
    0xF902: 'Araç hızı',
    0xF903: 'Sürücü 1 çalışma durumu',
    0xF904: 'Sürücü 2 çalışma durumu',
    0xF905: 'Sürüş algılama',
    0xF906: 'Sürücü 1 süre durumları',
    0xF907: 'Sürücü 1 kartı',
    0xF908: 'Hız aşımı',
    0xF909: 'Sürücü 2 süre durumları',
    0xF90A: 'Sürücü 2 kartı',
    0xF90B: 'Tarih ve saat',
    0xF912: 'Toplam araç mesafesi',
    0xF913: 'Yolculuk mesafesi',
    0xF916: 'Sürücü 1 kimliği',
    0xF917: 'Sürücü 2 kimliği',
    0xF918: 'K faktörü',
    0xF91B: 'Çıkış mili hızı',
    0xF91C: 'L faktörü (lastik çevresi)',
    0xF91D: 'W faktörü',
    0xF921: 'Lastik ölçüsü',
    0xF922: 'Sonraki kalibrasyon tarihi',
    0xF923: 'Sürücü 1 kesintisiz sürüş',
    0xF924: 'Sürücü 2 kesintisiz sürüş',
    0xF92C: 'İzin verilen hız',
    0xF930: 'Kart yuvası 1',
    0xF931: 'Sürücü 1 adı',
    0xF932: 'Sürücü 2 adı',
    0xF933: 'Kart yuvası 2',
    0xF936: 'Kapsam dışı durumu',
    0xF937: 'Çalışma modu',
    0xF97D: 'Tescil ülkesi',
    0xF97E: 'Araç plakası',
    0xF97F: 'Araç tescil tarihi',
    0xF98B: 'Sürücü 2 kart son kullanma',
    0xF99A: 'Sürücü 1 günlük sürüş',
    0xF99D: 'Sürücü 1 kart son kullanma',
    0xF9D5: 'Varsayılan yük tipi',
    0xF9D7: 'Araç konumu',
  };
}

class DiagDecoded {
  const DiagDecoded(this.positive, this.title, this.value);
  final bool positive;
  final String title;
  final String value;
}
