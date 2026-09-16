import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smarttrack_mine/core/services/real_card_identification_parser.dart';

List<int> _epochBytes(DateTime utc) {
  final secs = utc.millisecondsSinceEpoch ~/ 1000;
  return [
    (secs >> 24) & 0xFF,
    (secs >> 16) & 0xFF,
    (secs >> 8) & 0xFF,
    secs & 0xFF,
  ];
}

List<int> _name(String text) {
  final bytes = text.codeUnits;
  final padded = List<int>.filled(35, 0x20);
  for (var i = 0; i < bytes.length && i < 35; i++) {
    padded[i] = bytes[i];
  }
  return [0x01, ...padded];
}

List<int> _cardIdentification({
  required String cardNumber,
  required DateTime issueDate,
  required DateTime expiryDate,
}) {
  final numberBytes = List<int>.filled(16, 0x20);
  final numChars = cardNumber.codeUnits;
  for (var i = 0; i < numChars.length && i < 16; i++) {
    numberBytes[i] = numChars[i];
  }
  return [
    0x01,
    ...numberBytes,
    ..._name('Some Authority'),
    ..._epochBytes(issueDate),
    ..._epochBytes(issueDate),
    ..._epochBytes(expiryDate),
  ];
}

void main() {
  group('RealCardIdentificationParser.parse', () {
    test(
      'driver card layout: surname/firstNames read right after CardIdentification',
      () {
        final ef = Uint8List.fromList([
          ..._cardIdentification(
            cardNumber: 'DRV1234567890',
            issueDate: DateTime.utc(2020, 1, 1),
            expiryDate: DateTime.utc(2030, 1, 1),
          ),
          ..._name('Smith'),
          ..._name('Alice'),
          0x20,
          0x25,
          0x03,
          0x15,
          0x65,
          0x6E,
        ]);

        final identity = RealCardIdentificationParser.parse(ef);

        expect(identity, isNotNull);
        expect(identity!.holderSurname, 'Smith');
        expect(identity.holderFirstName, 'Alice');
        expect(identity.language, 'en');
      },
    );

    test(
      'workshop card layout: workshopName/workshopAddress precede the real holder name (no birth date field)',
      () {
        final ef = Uint8List.fromList([
          ..._cardIdentification(
            cardNumber: 'WSH1234567890',
            issueDate: DateTime.utc(2020, 1, 1),
            expiryDate: DateTime.utc(2030, 1, 1),
          ),
          ..._name('UTOPIA Workshop'),
          ..._name('UTOPIA Address'),
          ..._name('Williams'),
          ..._name('John'),
          0x65,
          0x6E,
        ]);

        final identity = RealCardIdentificationParser.parse(ef);

        expect(identity, isNotNull);
        expect(identity!.holderSurname, 'Williams');
        expect(identity.holderFirstName, 'John');
        expect(identity.language, 'en');
      },
    );
  });
}
