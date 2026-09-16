import 'package:flutter/foundation.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show PdfGoogleFonts;

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
      pw.Header(level: 0, text: 'SmartTrack Takograf Raporu'),
      pw.Text('Oluşturulma: ${_fmt(DateTime.now())}'),
    ];

    if (cardData != null) {
      content.add(pw.SizedBox(height: 12));
      content.addAll(_cardSections(cardData, cardDetails, violations, perms));
    }
    if (vuData != null) {
      if (cardData != null) {
        content.add(pw.SizedBox(height: 20));
        content.add(pw.Header(level: 0, text: 'Araç Ünitesi (VU) Verileri'));
      }
      content.add(pw.SizedBox(height: 12));
      content.addAll(_vuSections(vuData));
    }
    if (cardData == null && vuData == null) {
      content.add(pw.Text('Bu dosyada gösterilecek veri bulunamadı.'));
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
        ..._section('Kart Sahibi Bilgileri', _cardHolderLines(data)),
      if (perms.viewCardHolderPii && details != null)
        ..._section(
          'Ehliyet ve Kullanım Bilgileri',
          _licenceAndUsageLines(details),
        ),
      ..._section('Sürüş Özeti', _drivingSummaryLines(data)),
      ..._tableSection(
        'Aktivite Kaydı',
        data.activityLog.length,
        headers: const ['Başlangıç', 'Bitiş', 'Tür', 'Manuel mi?'],
        rows: data.activityLog
            .map(
              (a) => [
                _fmt(a.startTime),
                _fmt(a.endTime),
                _activityLabel(a.type),
                a.isManualEntry ? 'Evet' : 'Hayır',
              ],
            )
            .toList(),
      ),
      if (perms.viewViolations) ...[
        ..._tableSection(
          'İhlaller',
          violations.length,
          headers: const ['Başlangıç', 'Bitiş', 'Tür', 'Kural'],
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
          'Olaylar',
          data.lastEvents.length,
          headers: const ['Zaman', 'Açıklama'],
          rows: data.lastEvents
              .map((e) => [_fmt(e.timestamp), e.description])
              .toList(),
        ),
        ..._tableSection(
          'Arızalar',
          data.lastFaults.length,
          headers: const ['Zaman', 'Açıklama'],
          rows: data.lastFaults
              .map((e) => [_fmt(e.timestamp), e.description])
              .toList(),
        ),
        if (details != null) ...[
          ..._tableSection(
            'Kullanılan Araçlar',
            details.vehicleRecords.length,
            headers: const ['Plaka', 'İlk Kullanım', 'Son Kullanım', 'Km'],
            rows: details.vehicleRecords
                .map(
                  (r) => [
                    r.vehicleRegistration.isEmpty ? '-' : r.vehicleRegistration,
                    r.firstUse != null ? _fmt(r.firstUse!) : '-',
                    r.lastUse != null ? _fmt(r.lastUse!) : 'kullanımda',
                    r.odometerEndKm != null
                        ? '${r.odometerBeginKm} → ${r.odometerEndKm}'
                        : '${r.odometerBeginKm} (kullanımda)',
                  ],
                )
                .toList(),
          ),
          ..._section(
            'Son Denetim',
            _controlActivityLines(details.lastControlActivity),
          ),
          ..._tableSection(
            'Konum Kayıtları',
            details.places.length,
            headers: const ['Zaman', 'Ülke', 'Km'],
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
            'Özel Durum Kayıtları',
            details.specificConditions.length,
            headers: const ['Zaman', 'Tür'],
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
      'Ad Soyad: ${data.holderFullName}',
      'Kart No: ${data.cardNumber}',
      'Düzenleyen Ülke: ${_countryLabel(data.cardIssuingMemberState)}',
      if (data.cardIssueDate != null)
        'Düzenleme Tarihi: ${_fmt(data.cardIssueDate!)}',
      if (data.cardExpiryDate != null)
        'Son Geçerlilik: ${_fmt(data.cardExpiryDate!)}',
      if (data.dateOfBirth != null)
        'Doğum Tarihi: ${_fmtDateOnly(data.dateOfBirth!)}',
      'Araç Plakası: ${data.vehicleRegistration}',
    ];
  }

  static List<String> _licenceAndUsageLines(CardFileDetails details) {
    return [
      if (details.drivingLicenceAuthority.isNotEmpty)
        'Ehliyet Veren Makam: ${details.drivingLicenceAuthority}',
      if (details.drivingLicenceNumber.isNotEmpty)
        'Ehliyet No: ${details.drivingLicenceNumber}',
      if (details.lastDownloadDate != null)
        'Son İndirme Tarihi: ${_fmt(details.lastDownloadDate!)}',
      if (details.currentUsageSessionOpenTime != null)
        'Açık Oturum Başlangıcı: ${_fmt(details.currentUsageSessionOpenTime!)}',
      if (details.currentUsageVehicleRegistration.isNotEmpty)
        'Kullanımdaki Araç: ${details.currentUsageVehicleRegistration}',
    ];
  }

  static List<String> _drivingSummaryLines(TachographDriverData data) {
    return [
      'Güncel Sürüş: ${TachographDriverData.formatMinutes(data.currentDrivingMinutes)}',
      'Günlük Sürüş: ${TachographDriverData.formatMinutes(data.dailyDrivingMinutes)}',
      'Haftalık Sürüş: ${TachographDriverData.formatMinutes(data.weeklyDrivingMinutes)}',
      'İki Haftalık Sürüş: ${TachographDriverData.formatMinutes(data.biWeeklyDrivingMinutes)}',
      'Kilometre: ${data.odometerKm} km',
    ];
  }

  static List<String> _controlActivityLines(ControlActivityRecord? control) {
    if (control == null) return ['Denetim kaydı yok.'];
    return [
      'Denetim Zamanı: ${_fmt(control.controlTime!)}',
      if (control.controlVehicleRegistration.isNotEmpty)
        'Denetim Aracı: ${control.controlVehicleRegistration}',
      if (control.controlCardNumber.isNotEmpty)
        'Denetim Kart No: ${control.controlCardNumber}',
      if (control.downloadPeriodBegin != null &&
          control.downloadPeriodEnd != null)
        'İndirme Aralığı: ${_fmtDateOnly(control.downloadPeriodBegin!)} - ${_fmtDateOnly(control.downloadPeriodEnd!)}',
    ];
  }

  static List<pw.Widget> _vuSections(VehicleUnitData data) {
    return [
      ..._section('Genel Bilgiler', _vuOverviewLines(data)),
      ..._section(
        'Cihaz Teknik Bilgileri',
        _vuTechnicalDataLines(data.technicalData),
      ),
      ..._vuIdentificationTextsSection(data.identificationTexts),
      ..._tableSection(
        'Hız Oturumları',
        data.speedSessions.length,
        headers: const ['Başlangıç', 'Bitiş', 'Maks. km/h', 'Ort. km/h'],
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
        'Günlük Aktivite - VU',
        data.dailyActivities.length,
        headers: const ['Tarih', 'Km (gece yarısı)', 'Kart Oturumları'],
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
        'Olaylar ve Arızalar - VU',
        data.eventsAndFaults.length,
        headers: const ['Başlangıç', 'Bitiş', 'Açıklama', 'Tür'],
        rows: data.eventsAndFaults
            .map(
              (e) => [
                e.beginTime != null ? _fmt(e.beginTime!) : '-',
                e.endTime != null ? _fmt(e.endTime!) : 'kullanımda',
                e.isFault
                    ? EuEventFaultCodes.faultLabel(e.type)
                    : EuEventFaultCodes.eventLabel(e.type),
                e.isFault ? 'Arıza' : 'Olay',
              ],
            )
            .toList(),
      ),
      ..._tableSection(
        'Hız Aşımları - VU',
        data.overspeedingEvents.length,
        headers: const ['Başlangıç', 'Bitiş', 'Maks. km/h', 'Ort. km/h'],
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
        'Kalibrasyon Geçmişi',
        data.calibrationRecords.length,
        headers: const [
          'Atölye',
          'İzinli Hız',
          'Km (Eski→Yeni)',
          'Sonraki Kalibrasyon',
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
        'Plaka: ${data.vehicleRegistrationNumber}',
      if (data.overview?.currentDateTime != null)
        'Cihaz Saati: ${_fmt(data.overview!.currentDateTime!)}',
      if (data.overview?.downloadablePeriodStart != null &&
          data.overview?.downloadablePeriodEnd != null)
        'İndirilebilir Dönem: ${_fmt(data.overview!.downloadablePeriodStart!)} – ${_fmt(data.overview!.downloadablePeriodEnd!)}',
    ];
  }

  static List<String> _vuTechnicalDataLines(VuTechnicalData? t) {
    if (t == null) return ['Veri yok.'];
    return [
      'Üretici: ${t.manufacturerName}',
      if (t.manufacturerAddress.isNotEmpty)
        'Üretici Adresi: ${t.manufacturerAddress}',
      'Parça No: ${t.partNumber}',
      'Seri No: ${t.serialNumber} (${t.serialMonth.toString().padLeft(2, '0')}/20${t.serialYear.toString().padLeft(2, '0')})',
      'Yazılım Sürümü: ${t.softwareVersion}',
      if (t.manufacturingDate != null)
        'Üretim Tarihi: ${_fmt(t.manufacturingDate!)}',
      'Onay No: ${t.approvalNumber}',
      'Hareket Sensörü — Seri No: ${t.sensorSerialNumber} (${t.sensorSerialMonth.toString().padLeft(2, '0')}/20${t.sensorSerialYear.toString().padLeft(2, '0')})',
      'Hareket Sensörü — Onay No: ${t.sensorApprovalNumber}',
      if (t.sensorPairingDateFirst != null)
        'Hareket Sensörü — İlk Eşleştirme Tarihi: ${_fmt(t.sensorPairingDateFirst!)}',
    ];
  }

  static List<pw.Widget> _vuIdentificationTextsSection(
    List<IdentifiedText> items,
  ) {
    final title = 'Kimlik Metinleri (${items.length})';
    if (items.isEmpty) {
      return [
        pw.Header(level: 1, text: title),
        pw.Text('Kayıt yok.'),
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
        pw.Text('Kayıt yok.')
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
        pw.Text('Kayıt yok.'),
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
        return 'Sürüş';
      case ActivityType.rest:
        return 'Dinlenme';
      case ActivityType.available:
        return 'Hazır Bulunma';
      case ActivityType.work:
        return 'Diğer Çalışma';
      case ActivityType.unknown:
        return 'Bilinmiyor';
    }
  }

  static String _violationLabel(Violation v) {
    const labels = {
      'violation.continuousDrivingExceeded': 'Sürekli sürüş limiti aşıldı',
      'violation.dailyDrivingExceeded': 'Günlük sürüş limiti aşıldı',
      'violation.weeklyDrivingExceeded': 'Haftalık sürüş limiti aşıldı',
      'violation.biWeeklyDrivingExceeded': 'İki haftalık sürüş limiti aşıldı',
      'violation.dailyRestInsufficient': 'Günlük dinlenme süresi yetersiz',
      'violation.weeklyRestInsufficient': 'Haftalık dinlenme süresi yetersiz',
      'violation.missingRecord': 'Kayıtsız zaman aralığı',
    };
    return labels[v.descriptionKey] ?? v.descriptionKey;
  }

  static String _specificConditionLabel(int type) {
    switch (type) {
      case 1:
        return 'Kapsam dışı sürüş başlangıcı';
      case 2:
        return 'Kapsam dışı sürüş bitişi';
      case 3:
        return 'Feribot/tren geçişi';
      default:
        return 'Bilinmeyen (kod $type)';
    }
  }

  static String _countryLabel(String raw) {
    if (raw.isEmpty) return '-';
    final code = int.tryParse(raw);
    return code != null ? EuNationCodes.label(code) : raw;
  }
}
