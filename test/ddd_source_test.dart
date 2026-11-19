import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smarttrack_mine/core/models/ddd_file.dart';
import 'package:smarttrack_mine/core/models/tachograph_type.dart';
import 'package:smarttrack_mine/core/providers/app_state.dart';
import 'package:smarttrack_mine/core/widgets/ddd_source_badge.dart';

/// Each saved .ddd file records the tachograph it came from, so files from
/// the STC 8255 and the ATC 8256 can be told apart in the one list.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DddFile file({TachographType? source}) => DddFile(
    id: '1',
    downloadedAt: DateTime.utc(2026, 11, 19, 8, 33),
    cardType: 'Sürücü',
    cardHolderName: 'VRNVDO1',
    fileSizeBytes: 92804,
    isSimulated: false,
    downloadKind: 'vehicleUnit',
    sourceUnit: source,
  );

  group('DddFile.sourceUnit', () {
    for (final type in TachographType.values) {
      test('${type.code} survives saving and loading', () {
        final back = DddFile.fromJson(file(source: type).toJson());
        expect(back.sourceUnit, type);
      });
    }

    test('a file saved before the source was recorded has none', () {
      final json = file().toJson()..remove('sourceUnit');
      expect(DddFile.fromJson(json).sourceUnit, isNull);
    });

    test('an unknown value is read as none, not an error', () {
      final json = file().toJson()..['sourceUnit'] = 'somethingElse';
      expect(DddFile.fromJson(json).sourceUnit, isNull);
    });

    test('moving a file to the bin keeps its source', () {
      final trashed = file(
        source: TachographType.stc8255,
      ).copyWith(isTrashed: true, trashedAt: DateTime.utc(2026, 11, 19));
      expect(trashed.sourceUnit, TachographType.stc8255);
    });
  });

  group('DddSourceBadge', () {
    for (final type in TachographType.values) {
      testWidgets('shows ${type.code}', (tester) async {
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: DddSourceBadge(type))),
        );
        expect(find.text(type.code), findsOneWidget);
      });
    }
  });

  group('AppState.saveRealDddBytes', () {
    late Directory documents;

    setUp(() async {
      documents = await Directory.systemTemp.createTemp('ddd_source_test');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => documents.path,
          );
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          );
      await documents.delete(recursive: true);
    });

    for (final type in TachographType.values) {
      test('records ${type.code} as the source', () async {
        final appState = AppState();
        await pumpEventQueue();

        final saved = await appState.saveRealDddBytes(
          vuBytes: Uint8List.fromList(List.filled(64, 0x00)),
          source: type,
        );

        expect(saved.vehicleUnit?.sourceUnit, type);
        expect(appState.dddFiles.first.sourceUnit, type);
        appState.dispose();
      });
    }
  });
}
