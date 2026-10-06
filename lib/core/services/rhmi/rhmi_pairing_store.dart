import 'package:shared_preferences/shared_preferences.dart';

import 'rhmi.dart';

/// The session identifiers this phone holds, kept across restarts - which is
/// the point: VerifyRHMIsessionId exists so a client can check after a power
/// cycle that the identifier it still holds is the one the unit stored in
/// flash. Kept per unit and client, since an identifier belongs to exactly
/// one of each. A port of AvuItsTester's PairingStore.kt.
class RhmiPairingStore {
  RhmiPairingStore._();
  static final RhmiPairingStore instance = RhmiPairingStore._();

  String _key(String device, int client, String field) =>
      'rhmi/$device/$client/$field';

  Future<RhmiPairing?> get(String device, int client) async {
    final prefs = await SharedPreferences.getInstance();
    final sid = _decode(prefs.getString(_key(device, client, 'sid')));
    if (sid == null || sid.length != Rhmi.sessionIdSize) return null;
    return RhmiPairing(
      client: client,
      sessionId: sid,
      pairedAt: DateTime.fromMillisecondsSinceEpoch(
        prefs.getInt(_key(device, client, 'at')) ?? 0,
      ),
    );
  }

  Future<List<RhmiPairing>> all(String device) async => [
    for (final c in const [0, 1, 2])
      if (await get(device, c) case final p?) p,
  ];

  Future<void> put(String device, int client, List<int> sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(device, client, 'sid'), _encode(sessionId));
    await prefs.setInt(
      _key(device, client, 'at'),
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> forget(String device, int client) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(device, client, 'sid'));
    await prefs.remove(_key(device, client, 'at'));
  }

  static String _encode(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static List<int>? _decode(String? hex) {
    if (hex == null || hex.length.isOdd) return null;
    try {
      return [
        for (var i = 0; i < hex.length; i += 2)
          int.parse(hex.substring(i, i + 2), radix: 16),
      ];
    } on FormatException {
      return null;
    }
  }
}

class RhmiPairing {
  const RhmiPairing({
    required this.client,
    required this.sessionId,
    required this.pairedAt,
  });

  final int client;
  final List<int> sessionId;
  final DateTime pairedAt;
}
