String bytesToHex(List<int> bytes) {
  final hex = bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');
  final ascii = String.fromCharCodes(bytes.where((b) => b >= 32 && b < 127));
  return '$hex${ascii.isNotEmpty ? ' ("$ascii")' : ''}';
}

const int _sidSecurityAccess = 0x27;
const int _subFnSendKey = 0x7E;

bool isSecurityAccessSendKeyFrame(List<int> bytes) =>
    bytes.length > 5 &&
    bytes[4] == _sidSecurityAccess &&
    bytes[5] == _subFnSendKey;

String bytesToHexRedacted(List<int> bytes) {
  if (!isSecurityAccessSendKeyFrame(bytes)) return bytesToHex(bytes);
  final visible = bytes
      .sublist(0, 6)
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');
  final pinByteCount = bytes.length - 7;
  return '$visible ** PIN REDACTED ** ($pinByteCount bytes + checksum)';
}
