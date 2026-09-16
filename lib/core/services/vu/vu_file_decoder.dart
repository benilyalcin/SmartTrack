import 'dart:typed_data';

import '../../models/vehicle_unit_data.dart';
import 'vu_activity_decoder.dart';
import 'vu_block_framer.dart';
import 'vu_events_decoder.dart';
import 'vu_field_codecs.dart';
import 'vu_overview_decoder.dart';
import 'vu_speed_decoder.dart';
import 'vu_technical_decoder.dart';

class VuFileDecoder {
  VuFileDecoder._();

  static VehicleUnitData decode(Uint8List data) {
    final ranges = VuBlockFramer.locateBlocks(data);

    Uint8List? firstBlock(int trep) {
      for (final r in ranges) {
        if (r.trep == trep) return Uint8List.sublistView(data, r.start, r.end);
      }
      return null;
    }

    final overviewBlock = firstBlock(0x01);
    final overviewResult = overviewBlock != null
        ? VuOverviewDecoder.decode(overviewBlock)
        : null;

    int activitiesSearchFrom = 0;
    for (final r in ranges) {
      if (r.trep == 0x01) {
        activitiesSearchFrom = r.end;
        break;
      }
    }
    final dailyActivities = VuActivityDecoder.decodeFromStream(
      data,
      activitiesSearchFrom,
      referenceNow: overviewResult?.overview?.currentDateTime,
    );

    final eventsBlock = firstBlock(0x03);
    final eventsAndFaults = eventsBlock != null
        ? VuEventsDecoder.decode(eventsBlock)
        : const <VuEventOrFault>[];
    final overspeedingEvents = eventsBlock != null
        ? VuEventsDecoder.decodeOverspeeding(eventsBlock)
        : const <VuOverspeedingEvent>[];

    final speedBlock = firstBlock(0x04);
    final speedSessions = speedBlock != null
        ? VuSpeedDecoder.decode(speedBlock)
        : const <VuSpeedSession>[];

    final technicalBlock = firstBlock(0x05);
    final technicalResult = technicalBlock != null
        ? VuTechnicalDecoder.decode(technicalBlock)
        : null;

    final identificationTexts = _buildIdentificationTexts(
      overviewBlock,
      technicalResult?.technicalData,
      technicalResult?.calibrationRecords ?? const [],
      dailyActivities,
    );

    return VehicleUnitData(
      vin: overviewResult?.vin ?? '',
      vehicleRegistrationNumber: overviewResult?.vrn ?? '',
      identificationTexts: identificationTexts,
      speedSessions: speedSessions,
      dailyActivities: dailyActivities,
      eventsAndFaults: eventsAndFaults,
      overspeedingEvents: overspeedingEvents,
      calibrationRecords: technicalResult?.calibrationRecords ?? const [],
      technicalData: technicalResult?.technicalData,
      overview: overviewResult?.overview,
    );
  }

  static List<IdentifiedText> _buildIdentificationTexts(
    Uint8List? overviewBlock,
    VuTechnicalData? technicalData,
    List<VuCalibrationRecord> calibrationRecords,
    List<VuDailyActivity> dailyActivities,
  ) {
    final texts = overviewBlock != null
        ? _scanNameFields(overviewBlock)
        : const <String>[];

    final sourceLabels = <String, String>{};
    if (technicalData != null) {
      sourceLabels[technicalData.manufacturerName] =
          'ddd.identitySourceManufacturer';
      sourceLabels[technicalData.manufacturerAddress] =
          'ddd.identitySourceManufacturer';
    }
    for (final c in calibrationRecords) {
      sourceLabels[c.workshopName] = 'ddd.identitySourceWorkshop';
      sourceLabels[c.workshopAddress] = 'ddd.identitySourceWorkshop';
    }

    final cardHolderNames = <String, String>{};
    final cardHolderFragments = <String>{};
    for (final day in dailyActivities) {
      for (final s in day.cardSessions) {
        if (s.fullName.isEmpty) continue;
        cardHolderNames[s.fullName] = _cardTypeSourceKey(s.cardType);
        cardHolderFragments.add(s.surname);
        cardHolderFragments.add(s.firstName);
      }
    }

    return [
      for (final t in texts)
        if (!cardHolderFragments.contains(t))
          IdentifiedText(text: t, sourceLabelKey: sourceLabels[t]),
      for (final entry in cardHolderNames.entries)
        IdentifiedText(text: entry.key, sourceLabelKey: entry.value),
    ];
  }

  static String _cardTypeSourceKey(int cardType) {
    switch (cardType) {
      case 1:
        return 'ddd.cardTypeDriver';
      case 2:
        return 'ddd.cardTypeWorkshop';
      case 3:
        return 'ddd.cardTypeControl';
      case 4:
        return 'ddd.cardTypeCompany';
      case 5:
        return 'ddd.cardTypeManufacturer';
      default:
        return 'ddd.cardTypeUnknown';
    }
  }

  static List<String> _scanNameFields(Uint8List data) {
    const width = 35;
    final seen = <String>{};
    final result = <String>[];
    var i = 0;
    while (i + 1 + width <= data.length) {
      if (!VuFieldCodecs.identityCodepages.contains(data[i]) ||
          !VuFieldCodecs.isCleanAsciiField(
            Uint8List.sublistView(data, i + 1, i + 1 + width),
          )) {
        i++;
        continue;
      }
      final text = VuFieldCodecs.cleanAsciiText(
        Uint8List.sublistView(data, i + 1, i + 1 + width),
      );
      if (text.length >= 4 && seen.add(text)) {
        result.add(text);
      }
      i += 1 + width;
    }
    return result;
  }
}
