import '../../localization/localization.dart';
import '../kline_protocol.dart';
import '../rhmi/rhmi.dart';

/// Reads an Annex 8 answer the way its request asked for it - a port of
/// AvuItsTester's DiagDecoder.kt. [frame] is the long-form KWP2000 answer
/// ItsLink hands back.
class DiagDecoder {
  DiagDecoder._();

  static String _t(String key, [Map<String, Object?> args = const {}]) =>
      AppLocalizations.text(key, args);

  static DiagDecoded decode(List<int> frame) {
    final sid = frame[4];
    final data = frame.length > 5 ? frame.sublist(5, 4 + frame[3]) : <int>[];
    if (sid == 0x7F && data.length >= 2) {
      return DiagDecoded(
        false,
        _t('diag.serviceRefused', {'sid': _h2(data[0])}),
        '${RdbiResponseParser.describeNrc(data[1])} (${_h2(data[1])})',
      );
    }
    return switch (sid) {
      0xC1 => DiagDecoded(
        true,
        _t('diag.commStarted'),
        _t('diag.keyBytes', {'bytes': _hex(data)}),
      ),
      0x50 => DiagDecoded(
        true,
        _t('diag.sessionStarted'),
        data.isEmpty
            ? _t('diag.noSessionByte')
            : _t('diag.session', {'code': _h2(data[0])}),
      ),
      0x62 => _read(data),
      0x71 => _routine(data),
      _ => DiagDecoded(
        true,
        _t('diag.serviceAnswered', {'sid': _h2(sid - 0x40)}),
        _hexOr(data),
      ),
    };
  }

  static DiagDecoded _routine(List<int> d) {
    if (d.length < 3) {
      return DiagDecoded(true, _t('diag.routineAnswered'), _hex(d));
    }
    final routine = (d[1] << 8) | d[2];
    final rest = d.sublist(3);
    if (routine == Rhmi.ridOpenSession &&
        d[0] == Rhmi.routineRequestResults &&
        rest.isNotEmpty) {
      return DiagDecoded(
        true,
        _t('diag.rhmiStatus'),
        RhmiSessionStatus.of(rest[0])?.label ??
            _t('diag.state', {'code': _h2(rest[0])}),
      );
    }
    return DiagDecoded(
      true,
      _t('diag.routineIdAnswered', {
        'id': routine.toRadixString(16).toUpperCase(),
      }),
      _hexOr(rest),
    );
  }

  static DiagDecoded _read(List<int> d) {
    if (d.length < 2) return DiagDecoded(true, _t('diag.readData'), _hex(d));
    final id = (d[0] << 8) | d[1];
    final v = d.sublist(2);
    final idHex = id.toRadixString(16).toUpperCase().padLeft(4, '0');
    final name = _named.contains(id)
        ? _t('diag.id.$idHex')
        : _t('diag.identifier', {'id': idHex});
    String? value;
    try {
      value = _value(id, v);
    } catch (_) {}
    value ??=
        '${_hexOr(v)}${_printable(v) == null ? '' : '  "${_printable(v)}"'}'
        '  ${_t('diag.noDecoder', {'id': idHex})}';
    return DiagDecoded(true, '$name ($idHex)', value);
  }

  static String? _value(int id, List<int> v) {
    String? need(int n, String Function() f) => v.length >= n ? f() : null;
    return switch (id) {
      0xF90B || 0xF97F => _timeDate(v),
      0xF902 => need(2, () => '${(v[0] + v[1] / 256).toStringAsFixed(2)} km/h'),
      0xF903 || 0xF904 => need(1, () => _activity(v[0])),
      0xF905 => need(
        1,
        () => _t(v[0] == 1 ? 'diag.driving' : 'diag.notDriving'),
      ),
      0xF906 || 0xF909 => need(1, () => _timeWarning(v[0])),
      0xF907 || 0xF90A => need(
        1,
        () => _t(v[0] == 1 ? 'diag.cardPresent' : 'diag.cardAbsent'),
      ),
      0xF908 => need(
        1,
        () => _t(v[0] != 0 ? 'diag.overspeed' : 'diag.noOverspeed'),
      ),
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
            ? _t('diag.notSet')
            : '${_d2(v[1] ~/ 4 + 1)}.${_d2(v[0])}.${v[2] + 1985}',
      ),
      0xF923 || 0xF924 || 0xF99A => need(2, () => _minutes(_u16(v, 0))),
      0xF92C => need(2, () => '${(_u16(v, 0) / 256).toStringAsFixed(2)} km/h'),
      0xF930 || 0xF933 => need(1, () => _cardSlot(v[0])),
      0xF931 ||
      0xF932 => need(72, () => '${_text(v, 37, 35)} ${_text(v, 1, 35)}'.trim()),
      0xF936 => need(
        1,
        () => _t(v[0] == 1 ? 'diag.oosActive' : 'diag.oosInactive'),
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
    if (day == 0 || month == 0) return _t('diag.notSet');
    final t = DateTime.utc(v[5] + 1985, month, day, v[2], v[1], v[0] ~/ 4);
    final h = v[7] - 125, m = (v[6] - 125).abs();
    return _t('diag.utcLocal', {
      'time':
          '${_d2(t.day)}.${_d2(t.month)}.${t.year}-${_d2(t.hour)}:'
          '${_d2(t.minute)}:${_d2(t.second)}',
      'offset': '${h >= 0 ? '+' : ''}$h:${_d2(m)}',
    });
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
        _t('diag.countryCode', {'code': _h2(v[12])});
    final place = lat == 0x7FFFFF || lon == 0x7FFFFF
        ? _t('diag.positionUnknown')
        : '${degrees(lat).toStringAsFixed(5)}, ${degrees(lon).toStringAsFixed(5)}';
    final at = time == 0
        ? _t('diag.noTime')
        : DateTime.fromMillisecondsSinceEpoch(
            time * 1000,
            isUtc: true,
          ).toIso8601String();
    final check = _t(v[11] == 1 ? 'diag.verified' : 'diag.unverified');
    return '$place ($check), $at, $country';
  }

  /// `<prefix>.<v>` for the values 0..[last], `<other>` with the code past
  /// them.
  static String _named0(String prefix, int v, int last, String other) =>
      v >= 0 && v <= last ? _t('$prefix.$v') : _t(other, {'code': _h2(v)});

  static String _activity(int v) => _named0('diag.act', v, 3, 'diag.act.other');

  static String _cardSlot(int v) => _named0('diag.slot', v, 4, 'diag.state');

  static String _mode(int v) => _named0('diag.mode', v, 3, 'diag.mode.other');

  static String _loadType(int v) =>
      _named0('diag.load', v, 2, 'diag.load.other');

  static String _timeWarning(int v) => _named0('diag.tw', v, 12, 'diag.state');

  static String _minutes(int t) =>
      _t('diag.hm', {'h': t ~/ 60, 'm': _d2(t % 60)});
  static int _u16(List<int> v, int at) => (v[at] << 8) | v[at + 1];
  static String _d2(int v) => v.toString().padLeft(2, '0');
  static String _h2(int v) =>
      '0x${v.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  static String _hex(List<int> d) =>
      d.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
  static String _hexOr(List<int> d) => d.isEmpty ? _t('diag.noData') : _hex(d);

  static String _text(List<int> v, int at, int length) {
    final end = (at + length).clamp(0, v.length);
    if (at >= end) return '';
    return String.fromCharCodes(
      v.sublist(at, end).where((b) => b >= 0x20 && b != 0xFF),
    ).trim();
  }

  static String? _printable(List<int> v) {
    if (v.isEmpty || v.any((b) => (b < 0x20 || b > 0x7E) && b != 0)) {
      return null;
    }
    final s = String.fromCharCodes(v.where((b) => b != 0)).trim();
    return s.isEmpty ? null : s;
  }

  /// The identifiers with a name, `diag.id.<XXXX>` in the localization map.
  static const Set<int> _named = {
    0xF190,
    0xF902,
    0xF903,
    0xF904,
    0xF905,
    0xF906,
    0xF907,
    0xF908,
    0xF909,
    0xF90A,
    0xF90B,
    0xF912,
    0xF913,
    0xF916,
    0xF917,
    0xF918,
    0xF91B,
    0xF91C,
    0xF91D,
    0xF921,
    0xF922,
    0xF923,
    0xF924,
    0xF92C,
    0xF930,
    0xF931,
    0xF932,
    0xF933,
    0xF936,
    0xF937,
    0xF97D,
    0xF97E,
    0xF97F,
    0xF98B,
    0xF99A,
    0xF99D,
    0xF9D5,
    0xF9D7,
  };
}

class DiagDecoded {
  const DiagDecoded(this.positive, this.title, this.value);
  final bool positive;
  final String title;
  final String value;
}
