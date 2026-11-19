import 'package:flutter/foundation.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show PdfGoogleFonts;

import '../localization/localization.dart';
import '../models/card_file_details.dart';
import '../models/role_permissions.dart';
import '../models/vehicle_unit_data.dart';
import 'driving_time_calculator.dart';
import 'eu_event_fault_codes.dart';
import 'eu_nation_codes.dart';
import 'tachograph_parser.dart';
import 'violation_analyzer.dart';

class PdfExportService {
  PdfExportService._();

  // The report is written in the language the app is showing.
  static String _t(String key, [Map<String, Object?> args = const {}]) =>
      AppLocalizations.text(key, args);

  static Future<Uint8List> buildPdf({
    TachographDriverData? cardData,
    CardFileDetails? cardDetails,
    VehicleUnitData? vuData,
    List<Violation> violations = const [],
    required RolePermissions perms,
  }) async {
    pw.ThemeData? theme;
    try {
      final baseFont = await PdfGoogleFonts.notoSansRegular();
      final boldFont = await PdfGoogleFonts.notoSansBold();
      theme = pw.ThemeData.withFont(base: baseFont, bold: boldFont);
    } catch (e) {
      debugPrint(
        'PdfExportService: Noto Sans font fetch failed, falling back to default font: $e',
      );
    }
    final doc = pw.Document(theme: theme);

    final content = <pw.Widget>[
      pw.Header(level: 0, text: _t('pdf.title')),
      pw.Text(_t('pdf.generated', {'time': _fmt(DateTime.now())})),
    ];

    if (cardData != null) {
      content.add(pw.SizedBox(height: 12));
      content.addAll(_cardSections(cardData, cardDetails, violations, perms));
    }
    if (vuData != null) {
      if (cardData != null) {
        content.add(pw.SizedBox(height: 20));
        content.add(pw.Header(level: 0, text: _t('pdf.vuHeader')));
      }
      content.add(pw.SizedBox(height: 12));
      content.addAll(_vuSections(vuData));
    }
    if (cardData == null && vuData == null) {
      content.add(pw.Text(_t('pdf.noData')));
    }

    doc.addPage(pw.MultiPage(maxPages: 500, build: (context) => content));
    return doc.save();
  }

  static List<pw.Widget> _cardSections(
    TachographDriverData data,
    CardFileDetails? details,
    List<Violation> violations,
    RolePermissions perms,
  ) {
    return [
      if (perms.viewCardHolderPii)
        ..._section(_t('pdf.cardHolder'), _cardHolderLines(data)),
      if (perms.viewCardHolderPii && details != null)
        ..._section(_t('pdf.licenceAndUsage'), _licenceAndUsageLines(details)),
      ..._section(_t('pdf.drivingSummary'), _drivingSummaryLines(data)),
      ..._tableSection(
        _t('pdf.activityLog'),
        data.activityLog.length,
        headers: [
          _t('pdf.start'),
          _t('pdf.end'),
          _t('pdf.type'),
          _t('pdf.manual'),
        ],
        rows: data.activityLog
            .map(
              (a) => [
                _fmt(a.startTime),
                _fmt(a.endTime),
                _activityLabel(a.type),
                a.isManualEntry ? _t('pdf.yes') : _t('pdf.no'),
              ],
            )
            .toList(),
      ),
      if (perms.viewViolations) ...[
        ..._tableSection(
          _t('pdf.violations'),
          violations.length,
          headers: [
            _t('pdf.start'),
            _t('pdf.end'),
            _t('pdf.type'),
            _t('pdf.rule'),
          ],
          rows: violations
              .map(
                (v) => [
                  _fmt(v.start),
                  _fmt(v.end),
                  _violationLabel(v),
                  v.ruleReference,
                ],
              )
              .toList(),
        ),
        ..._tableSection(
          _t('pdf.events'),
          data.lastEvents.length,
          headers: [_t('pdf.time'), _t('pdf.description')],
          rows: data.lastEvents
              .map((e) => [_fmt(e.timestamp), e.description])
              .toList(),
        ),
        ..._tableSection(
          _t('pdf.faults'),
          data.lastFaults.length,
          headers: [_t('pdf.time'), _t('pdf.description')],
          rows: data.lastFaults
              .map((e) => [_fmt(e.timestamp), e.description])
              .toList(),
        ),
        if (details != null) ...[
          ..._tableSection(
            _t('pdf.vehiclesUsed'),
            details.vehicleRecords.length,
            headers: [
              _t('pdf.plate'),
              _t('pdf.firstUse'),
              _t('pdf.lastUse'),
              _t('pdf.km'),
            ],
            rows: details.vehicleRecords
                .map(
                  (r) => [
                    r.vehicleRegistration.isEmpty ? '-' : r.vehicleRegistration,
                    r.firstUse != null ? _fmt(r.firstUse!) : '-',
                    r.lastUse != null ? _fmt(r.lastUse!) : _t('ddd.stillInUse'),
                    r.odometerEndKm != null
                        ? '${r.odometerBeginKm} → ${r.odometerEndKm}'
                        : '${r.odometerBeginKm} (${_t('ddd.stillInUse')})',
                  ],
                )
                .toList(),
          ),
          ..._section(
            _t('pdf.lastControl'),
            _controlActivityLines(details.lastControlActivity),
          ),
          ..._tableSection(
            _t('pdf.places'),
            details.places.length,
            headers: [_t('pdf.time'), _t('pdf.country'), _t('pdf.km')],
            rows: details.places
                .map(
                  (p) => [
                    p.entryTime != null ? _fmt(p.entryTime!) : '-',
                    EuNationCodes.label(p.countryCode),
                    '${p.odometerKm}',
                  ],
                )
                .toList(),
          ),
          ..._tableSection(
            _t('pdf.specificConditions'),
            details.specificConditions.length,
            headers: [_t('pdf.time'), _t('pdf.type')],
            rows: details.specificConditions
                .map(
                  (c) => [
                    c.time != null ? _fmt(c.time!) : '-',
                    _specificConditionLabel(c.type),
                  ],
                )
                .toList(),
          ),
        ],
      ],
    ];
  }

  static List<String> _cardHolderLines(TachographDriverData data) {
    return [
      _t('pdf.holderName', {'value': data.holderFullName}),
      _t('pdf.cardNumber', {'value': data.cardNumber}),
      _t('pdf.issuingState', {
        'value': _countryLabel(data.cardIssuingMemberState),
      }),
      if (data.cardIssueDate != null)
        _t('pdf.issueDate', {'value': _fmt(data.cardIssueDate!)}),
      if (data.cardExpiryDate != null)
        _t('pdf.expiryDate', {'value': _fmt(data.cardExpiryDate!)}),
      if (data.dateOfBirth != null)
        _t('pdf.birthDate', {'value': _fmtDateOnly(data.dateOfBirth!)}),
      _t('pdf.vehicleReg', {'value': data.vehicleRegistration}),
    ];
  }

  static List<String> _licenceAndUsageLines(CardFileDetails details) {
    return [
      if (details.drivingLicenceAuthority.isNotEmpty)
        _t('pdf.licenceAuthority', {'value': details.drivingLicenceAuthority}),
      if (details.drivingLicenceNumber.isNotEmpty)
        _t('pdf.licenceNumber', {'value': details.drivingLicenceNumber}),
      if (details.lastDownloadDate != null)
        _t('pdf.lastDownload', {'value': _fmt(details.lastDownloadDate!)}),
      if (details.currentUsageSessionOpenTime != null)
        _t('pdf.sessionOpen', {
          'value': _fmt(details.currentUsageSessionOpenTime!),
        }),
      if (details.currentUsageVehicleRegistration.isNotEmpty)
        _t('pdf.vehicleInUse', {
          'value': details.currentUsageVehicleRegistration,
        }),
    ];
  }

  static List<String> _drivingSummaryLines(TachographDriverData data) {
    return [
      _t('pdf.currentDriving', {
        'value': TachographDriverData.formatMinutes(data.currentDrivingMinutes),
      }),
      _t('pdf.dailyDriving', {
        'value': TachographDriverData.formatMinutes(data.dailyDrivingMinutes),
      }),
      _t('pdf.weeklyDriving', {
        'value': TachographDriverData.formatMinutes(data.weeklyDrivingMinutes),
      }),
      _t('pdf.biWeeklyDriving', {
        'value': TachographDriverData.formatMinutes(
          data.biWeeklyDrivingMinutes,
        ),
      }),
      _t('pdf.odometer', {'value': data.odometerKm}),
    ];
  }

  static List<String> _controlActivityLines(ControlActivityRecord? control) {
    if (control == null) return [_t('pdf.noControl')];
    return [
      _t('pdf.controlTime', {'value': _fmt(control.controlTime!)}),
      if (control.controlVehicleRegistration.isNotEmpty)
        _t('pdf.controlVehicle', {'value': control.controlVehicleRegistration}),
      if (control.controlCardNumber.isNotEmpty)
        _t('pdf.controlCard', {'value': control.controlCardNumber}),
      if (control.downloadPeriodBegin != null &&
          control.downloadPeriodEnd != null)
        _t('pdf.controlPeriod', {
          'from': _fmtDateOnly(control.downloadPeriodBegin!),
          'to': _fmtDateOnly(control.downloadPeriodEnd!),
        }),
    ];
  }

  static List<pw.Widget> _vuSections(VehicleUnitData data) {
    return [
      ..._section(_t('pdf.general'), _vuOverviewLines(data)),
      ..._section(
        _t('pdf.technical'),
        _vuTechnicalDataLines(data.technicalData),
      ),
      ..._vuIdentificationTextsSection(data.identificationTexts),
      ..._tableSection(
        _t('pdf.speedSessions'),
        data.speedSessions.length,
        headers: [
          _t('pdf.start'),
          _t('pdf.end'),
          _t('pdf.maxKmh'),
          _t('pdf.avgKmh'),
        ],
        rows: data.speedSessions
            .map(
              (s) => [
                _fmt(s.start),
                _fmt(s.end),
                '${s.maxSpeedKmh}',
                s.avgSpeedKmh.toStringAsFixed(1),
              ],
            )
            .toList(),
      ),
      ..._tableSection(
        _t('pdf.vuDaily'),
        data.dailyActivities.length,
        headers: [_t('pdf.date'), _t('pdf.kmMidnight'), _t('pdf.cardSessions')],
        rows: data.dailyActivities
            .map(
              (d) => [
                _fmtDateOnly(d.date),
                '${d.odometerMidnightKm}',
                d.cardSessions.isEmpty
                    ? '-'
                    : d.cardSessions
                          .map((s) => s.fullName.isEmpty ? '-' : s.fullName)
                          .join(', '),
              ],
            )
            .toList(),
      ),
      ..._tableSection(
        _t('pdf.vuEvents'),
        data.eventsAndFaults.length,
        headers: [
          _t('pdf.start'),
          _t('pdf.end'),
          _t('pdf.description'),
          _t('pdf.type'),
        ],
        rows: data.eventsAndFaults
            .map(
              (e) => [
                e.beginTime != null ? _fmt(e.beginTime!) : '-',
                e.endTime != null ? _fmt(e.endTime!) : _t('ddd.stillInUse'),
                e.isFault
                    ? EuEventFaultCodes.faultLabel(e.type)
                    : EuEventFaultCodes.eventLabel(e.type),
                e.isFault ? _t('ddd.faultBadge') : _t('ddd.eventBadge'),
              ],
            )
            .toList(),
      ),
      ..._tableSection(
        _t('pdf.vuOverspeed'),
        data.overspeedingEvents.length,
        headers: [
          _t('pdf.start'),
          _t('pdf.end'),
          _t('pdf.maxKmh'),
          _t('pdf.avgKmh'),
        ],
        rows: data.overspeedingEvents
            .map(
              (o) => [
                o.beginTime != null ? _fmt(o.beginTime!) : '-',
                o.endTime != null ? _fmt(o.endTime!) : '-',
                '${o.maxSpeedKmh}',
                '${o.avgSpeedKmh}',
              ],
            )
            .toList(),
      ),
      ..._tableSection(
        _t('pdf.calibration'),
        data.calibrationRecords.length,
        headers: [
          _t('pdf.workshop'),
          _t('pdf.authorisedSpeed'),
          _t('pdf.kmOldNew'),
          _t('pdf.nextCalibration'),
        ],
        rows: data.calibrationRecords
            .map(
              (c) => [
                c.workshopName.isEmpty ? '-' : c.workshopName,
                '${c.authorisedSpeedKmh} km/h',
                '${c.oldOdometerKm} → ${c.newOdometerKm}',
                c.nextCalibrationDate != null
                    ? _fmtDateOnly(c.nextCalibrationDate!)
                    : '-',
              ],
            )
            .toList(),
      ),
    ];
  }

  static List<String> _vuOverviewLines(VehicleUnitData data) {
    return [
      if (data.vin.isNotEmpty) 'VIN: ${data.vin}',
      if (data.vehicleRegistrationNumber.isNotEmpty)
        _t('pdf.plateValue', {'value': data.vehicleRegistrationNumber}),
      if (data.overview?.currentDateTime != null)
        _t('pdf.deviceTime', {'value': _fmt(data.overview!.currentDateTime!)}),
      if (data.overview?.downloadablePeriodStart != null &&
          data.overview?.downloadablePeriodEnd != null)
        _t('pdf.downloadable', {
          'from': _fmt(data.overview!.downloadablePeriodStart!),
          'to': _fmt(data.overview!.downloadablePeriodEnd!),
        }),
    ];
  }

  static List<String> _vuTechnicalDataLines(VuTechnicalData? t) {
    if (t == null) return [_t('pdf.none')];
    return [
      _t('pdf.manufacturer', {'value': t.manufacturerName}),
      if (t.manufacturerAddress.isNotEmpty)
        _t('pdf.manufacturerAddress', {'value': t.manufacturerAddress}),
      _t('pdf.partNumber', {'value': t.partNumber}),
      _t('pdf.serialNumber', {
        'value':
            '${t.serialNumber} (${t.serialMonth.toString().padLeft(2, '0')}/20${t.serialYear.toString().padLeft(2, '0')})',
      }),
      _t('pdf.software', {'value': t.softwareVersion}),
      if (t.manufacturingDate != null)
        _t('pdf.manufacturingDate', {'value': _fmt(t.manufacturingDate!)}),
      _t('pdf.approval', {'value': t.approvalNumber}),
      _t('pdf.sensorSerial', {
        'value':
            '${t.sensorSerialNumber} (${t.sensorSerialMonth.toString().padLeft(2, '0')}/20${t.sensorSerialYear.toString().padLeft(2, '0')})',
      }),
      _t('pdf.sensorApproval', {'value': t.sensorApprovalNumber}),
      if (t.sensorPairingDateFirst != null)
        _t('pdf.sensorPairing', {'value': _fmt(t.sensorPairingDateFirst!)}),
    ];
  }

  static List<pw.Widget> _vuIdentificationTextsSection(
    List<IdentifiedText> items,
  ) {
    final title = _t('pdf.idTexts', {'count': items.length});
    if (items.isEmpty) {
      return [
        pw.Header(level: 1, text: title),
        pw.Text(_t('pdf.noRecords')),
        pw.SizedBox(height: 12),
      ];
    }
    return [
      pw.Header(level: 1, text: title),
      pw.Paragraph(
        text: items.map((t) => t.text).join('\n'),
        style: const pw.TextStyle(fontSize: 10),
      ),
      pw.SizedBox(height: 12),
    ];
  }

  static List<pw.Widget> _section(String title, List<String> lines) {
    return [
      pw.Header(level: 1, text: title),
      if (lines.isEmpty)
        pw.Text(_t('pdf.noRecords'))
      else
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: lines.map((l) => pw.Text(l)).toList(),
        ),
      pw.SizedBox(height: 12),
    ];
  }

  static List<pw.Widget> _tableSection(
    String title,
    int count, {
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final full = '$title ($count)';
    if (rows.isEmpty) {
      return [
        pw.Header(level: 1, text: full),
        pw.Text(_t('pdf.noRecords')),
        pw.SizedBox(height: 12),
      ];
    }
    return [
      pw.Header(level: 1, text: full),
      pw.TableHelper.fromTextArray(headers: headers, data: rows),
      pw.SizedBox(height: 12),
    ];
  }

  static String _fmt(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.${dt.year} $h:$min';
  }

  static String _fmtDateOnly(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d.$m.${dt.year}';
  }

  static String _activityLabel(ActivityType type) {
    switch (type) {
      case ActivityType.driving:
        return _t('pdf.actDriving');
      case ActivityType.rest:
        return _t('pdf.actRest');
      case ActivityType.available:
        return _t('pdf.actAvailable');
      case ActivityType.work:
        return _t('pdf.actWork');
      case ActivityType.unknown:
        return _t('pdf.actUnknown');
    }
  }

  static String _violationLabel(Violation v) => _t(v.descriptionKey);

  static String _specificConditionLabel(int type) {
    switch (type) {
      case 1:
        return _t('ddd.specificConditionOutOfScopeBegin');
      case 2:
        return _t('ddd.specificConditionOutOfScopeEnd');
      case 3:
        return _t('ddd.specificConditionFerryTrain');
      default:
        return _t('ddd.specificConditionUnknown', {'code': type});
    }
  }

  static String _countryLabel(String raw) {
    if (raw.isEmpty) return '-';
    final code = int.tryParse(raw);
    return code != null ? EuNationCodes.label(code) : raw;
  }
}
