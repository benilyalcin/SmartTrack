import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/localization/localization.dart';
import '../../core/models/card_file_details.dart';
import '../../core/models/ddd_file.dart';
import '../../core/models/role_permissions.dart';
import '../../core/models/vehicle_unit_data.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/ddd_file_repository.dart';
import '../../core/services/driving_time_calculator.dart';
import '../../core/services/eu_event_fault_codes.dart';
import '../../core/services/eu_nation_codes.dart';
import '../../core/services/pdf_export_service.dart';
import '../../core/services/real_card_details_parser.dart';
import '../../core/services/tachograph_parser.dart';
import '../../core/services/violation_analyzer.dart';
import '../../core/services/vu/vu_file_decoder.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/activity_day_bar_chart.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/vu_speed_day_chart.dart';

class DddFileDetailPage extends StatefulWidget {
  final String fileId;
  const DddFileDetailPage({super.key, required this.fileId});

  @override
  State<DddFileDetailPage> createState() => _DddFileDetailPageState();
}

class _DddFileDetailPageState extends State<DddFileDetailPage> {
  DddFile? _file;
  TachographDriverData? _parsed;
  CardFileDetails? _details;
  VehicleUnitData? _vuData;
  bool _loading = true;
  bool _exporting = false;

  String _t(String key) => AppLocalizations.getText(
    AppStateProvider.of(context).selectedLanguage,
    key,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final appState = AppStateProvider.of(context);
    DddFile? file;
    for (final f in appState.dddFiles) {
      if (f.id == widget.fileId) {
        file = f;
        break;
      }
    }
    if (file == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final bytes = await DddFileRepository.instance.readFileBytes(file);

    final isVehicleUnit = file.downloadKind == 'vehicleUnit';
    final isBoth = file.downloadKind == 'both';
    final parsed = bytes.isEmpty
        ? null
        : (isVehicleUnit ? null : DddFileParser().parse(bytes));
    final details = bytes.isNotEmpty && !isVehicleUnit
        ? RealCardDetailsParser.parse(bytes)
        : null;

    VehicleUnitData? vuData;
    if (isVehicleUnit && bytes.isNotEmpty) {
      vuData = VuFileDecoder.decode(bytes);
    } else if (isBoth) {
      final vuBytes = await DddFileRepository.instance.readSecondaryFileBytes(
        file,
      );
      if (vuBytes.isNotEmpty) vuData = VuFileDecoder.decode(vuBytes);
    }
    if (!mounted) return;
    setState(() {
      _file = file;
      _parsed = parsed;
      _details = details;
      _vuData = vuData;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final perms = appState.rolePermissions;
    final isDesktop = isDesktopLayout(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_file == null || (_parsed == null && _vuData == null)) {
      return Scaffold(
        appBar: AppBar(title: Text(_t('ddd.detailTitle'))),
        body: Center(child: Text(_t('ddd.filesEmpty'))),
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: isDesktop
              ? const EdgeInsets.all(48)
              : const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 16),
                  _file!.downloadKind == 'both' && _parsed != null
                      ? _buildCombinedBody(context, _parsed!, _vuData, perms)
                      : (_vuData != null
                            ? _buildVuBody(context, _vuData!, perms)
                            : _buildCardBody(context, _parsed!, perms)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        const SizedBox(width: 4),
        Text(
          _t('ddd.detailTitle'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildCombinedBody(
    BuildContext context,
    TachographDriverData cardData,
    VehicleUnitData? vuData,
    RolePermissions perms,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final violations = ViolationAnalyzer().analyze(
      cardData.activityLog,
      DateTime.now(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCardBody(context, cardData, perms, showExportButton: false),
        if (vuData != null) ...[
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: Divider(color: scheme.outlineVariant, thickness: 2),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  _t('ddd.vuHeader'),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Divider(color: scheme.outlineVariant, thickness: 2),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildVuBody(context, vuData, perms, showExportButton: false),
        ],
        if (perms.canExportPdf) ...[
          const SizedBox(height: 32),
          _buildExportButton(
            context,
            cardData,
            _details,
            vuData,
            violations,
            perms,
          ),
        ],
      ],
    );
  }

  Widget _buildCardBody(
    BuildContext context,
    TachographDriverData data,
    RolePermissions perms, {
    bool showExportButton = true,
  }) {
    final violations = ViolationAnalyzer().analyze(
      data.activityLog,
      DateTime.now(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (perms.viewCardHolderPii)
          _buildCardHolderSection(context, data, _file!),
        if (perms.viewCardHolderPii && _details != null) ...[
          const SizedBox(height: 20),
          _buildLicenceAndUsageSection(context, _details!),
        ],
        const SizedBox(height: 20),
        _buildActivityLogSection(context, data),
        if (perms.viewViolations) ...[
          const SizedBox(height: 20),
          _buildViolationsSection(context, violations),
          const SizedBox(height: 20),
          _buildEventsSection(context, data),
          if (_details != null) ...[
            const SizedBox(height: 20),
            _buildVehiclesUsedSection(context, _details!.vehicleRecords),
            const SizedBox(height: 20),
            _buildControlActivitySection(
              context,
              _details!.lastControlActivity,
            ),
            const SizedBox(height: 20),
            _buildPlacesSection(context, _details!.places),
            const SizedBox(height: 20),
            _buildSpecificConditionsSection(
              context,
              _details!.specificConditions,
            ),
          ],
        ],
        if (showExportButton && perms.canExportPdf) ...[
          const SizedBox(height: 20),
          _buildExportButton(context, data, _details, null, violations, perms),
        ],
      ],
    );
  }

  Widget _buildLicenceAndUsageSection(
    BuildContext context,
    CardFileDetails details,
  ) {
    return _sectionCard(
      context,
      title: _t('ddd.licenceAndUsage'),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _infoChip(
            context,
            _t('ddd.drivingLicenceAuthority'),
            details.drivingLicenceAuthority,
          ),
          _infoChip(
            context,
            _t('ddd.licenseNumber'),
            details.drivingLicenceNumber,
          ),
          _infoChip(
            context,
            _t('ddd.lastDownloadDate'),
            details.lastDownloadDate != null
                ? _formatDateTime(details.lastDownloadDate!)
                : '',
          ),
          _infoChip(
            context,
            _t('ddd.currentUsageSession'),
            details.currentUsageSessionOpenTime != null
                ? _formatDateTime(details.currentUsageSessionOpenTime!)
                : '',
          ),
          _infoChip(
            context,
            _t('ddd.currentUsageVehicle'),
            details.currentUsageVehicleRegistration,
          ),
        ],
      ),
    );
  }

  Widget _buildVehiclesUsedSection(
    BuildContext context,
    List<VehicleUsageRecord> records,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return _sectionCard(
      context,
      title: '${_t('ddd.vehiclesUsed')} (${records.length})',
      child: records.isEmpty
          ? Text(
              _t('ddd.noVehiclesUsed'),
              style: TextStyle(color: scheme.outline),
            )
          : Column(
              children: records
                  .map(
                    (r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.local_shipping_outlined,
                            size: 18,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.vehicleRegistration.isEmpty
                                      ? '-'
                                      : r.vehicleRegistration,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${r.firstUse != null ? _formatDateTime(r.firstUse!) : '-'} '
                                  '- ${r.lastUse != null ? _formatDateTime(r.lastUse!) : _t('ddd.stillInUse')}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            r.odometerEndKm != null
                                ? '${r.odometerBeginKm} → ${r.odometerEndKm} km'
                                : '${r.odometerBeginKm} km (${_t('ddd.stillInUse')})',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildControlActivitySection(
    BuildContext context,
    ControlActivityRecord? control,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return _sectionCard(
      context,
      title: _t('ddd.lastControl'),
      child: control == null
          ? Text(
              _t('ddd.noControlRecord'),
              style: TextStyle(color: scheme.outline),
            )
          : Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _infoChip(
                  context,
                  _t('ddd.controlTime'),
                  _formatDateTime(control.controlTime!),
                ),
                _infoChip(
                  context,
                  _t('ddd.controlVehicle'),
                  control.controlVehicleRegistration,
                ),
                _infoChip(
                  context,
                  _t('ddd.controlCardNumber'),
                  control.controlCardNumber,
                ),
                if (control.downloadPeriodBegin != null &&
                    control.downloadPeriodEnd != null)
                  _infoChip(
                    context,
                    _t('ddd.controlPeriod'),
                    '${_formatDate(control.downloadPeriodBegin!)} - ${_formatDate(control.downloadPeriodEnd!)}',
                  ),
              ],
            ),
    );
  }

  Widget _buildPlacesSection(BuildContext context, List<PlaceRecord> places) {
    final scheme = Theme.of(context).colorScheme;
    return _sectionCard(
      context,
      title: '${_t('ddd.places')} (${places.length})',
      child: places.isEmpty
          ? Text(_t('ddd.noPlaces'), style: TextStyle(color: scheme.outline))
          : Column(
              children: places
                  .map(
                    (p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 18,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 88,
                            child: Text(
                              p.entryTime != null
                                  ? _formatDateTime(p.entryTime!)
                                  : '-',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              EuNationCodes.label(p.countryCode),
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 84,
                            child: Text(
                              '${p.odometerKm} km',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildSpecificConditionsSection(
    BuildContext context,
    List<SpecificConditionRecord> conditions,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return _sectionCard(
      context,
      title: '${_t('ddd.specificConditions')} (${conditions.length})',
      child: conditions.isEmpty
          ? Text(
              _t('ddd.noSpecificConditions'),
              style: TextStyle(color: scheme.outline),
            )
          : Column(
              children: conditions
                  .map(
                    (c) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            Icons.directions_boat_filled_outlined,
                            size: 18,
                            color: scheme.tertiary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c.time != null ? _formatDateTime(c.time!) : '-',
                            ),
                          ),
                          Text(
                            _specificConditionLabel(c.type),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  String _specificConditionLabel(int type) {
    switch (type) {
      case 1:
        return _t('ddd.specificConditionOutOfScopeBegin');
      case 2:
        return _t('ddd.specificConditionOutOfScopeEnd');
      case 3:
        return _t('ddd.specificConditionFerryTrain');
      default:
        return _t(
          'ddd.specificConditionUnknown',
        ).replaceFirst('{code}', '$type');
    }
  }

  Widget _buildVuBody(
    BuildContext context,
    VehicleUnitData data,
    RolePermissions perms, {
    bool showExportButton = true,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionCard(
          context,
          title: _t('ddd.vuHeader'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_shipping, color: scheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _t('ddd.vuHeaderDesc'),
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _infoChip(context, _t('ddd.vin'), data.vin),
                  _infoChip(
                    context,
                    _t('ddd.vehicleReg'),
                    data.vehicleRegistrationNumber,
                  ),

                  if (data.overview?.currentDateTime != null)
                    _infoChip(
                      context,
                      _t('ddd.vuCurrentDateTime'),
                      _formatDateTime(data.overview!.currentDateTime!),
                    ),
                  if (data.overview?.downloadablePeriodStart != null &&
                      data.overview?.downloadablePeriodEnd != null)
                    _infoChip(
                      context,
                      _t('ddd.vuDownloadablePeriod'),
                      '${_formatDateTime(data.overview!.downloadablePeriodStart!)} – ${_formatDateTime(data.overview!.downloadablePeriodEnd!)}',
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _sectionCard(
          context,
          title:
              '${_t('ddd.vuIdentificationTexts')} (${data.identificationTexts.length})',
          child: data.identificationTexts.isEmpty
              ? Text(
                  _t('ddd.vuNoData'),
                  style: TextStyle(color: scheme.outline),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('ddd.vuIdentificationTextsHint'),
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.outline,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...data.identificationTexts.map(
                      (t) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.text_snippet_outlined,
                              size: 16,
                              color: scheme.outline,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                t.text,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            if (t.sourceLabelKey != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _t(t.sourceLabelKey!),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 20),
        _buildVuSpeedSessionsSection(context, data.speedSessions),
        const SizedBox(height: 20),
        _buildVuDailyActivitySection(context, data.dailyActivities),
        const SizedBox(height: 20),
        _buildVuEventsSection(context, data.eventsAndFaults),
        const SizedBox(height: 20),
        _buildVuOverspeedingSection(context, data.overspeedingEvents),
        const SizedBox(height: 20),
        _buildVuCalibrationSection(context, data.calibrationRecords),
        const SizedBox(height: 20),
        _buildVuTechnicalDataSection(context, data.technicalData),
        if (showExportButton && perms.canExportPdf) ...[
          const SizedBox(height: 20),
          _buildExportButton(context, null, null, data, const [], perms),
        ],
      ],
    );
  }

  Widget _buildVuTechnicalDataSection(
    BuildContext context,
    VuTechnicalData? t,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return _sectionCard(
      context,
      title: _t('ddd.vuTechnicalData'),
      child: t == null
          ? Text(_t('ddd.vuNoData'), style: TextStyle(color: scheme.outline))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('ddd.vuTechnicalDataVu'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.outline,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _infoChip(
                      context,
                      _t('ddd.vuManufacturerName'),
                      t.manufacturerName,
                    ),
                    _infoChip(
                      context,
                      _t('ddd.vuManufacturerAddress'),
                      t.manufacturerAddress,
                    ),
                    _infoChip(context, _t('ddd.vuPartNumber'), t.partNumber),
                    _infoChip(
                      context,
                      _t('ddd.vuSerialNumber'),
                      '${t.serialNumber} (${t.serialMonth.toString().padLeft(2, '0')}/20${t.serialYear.toString().padLeft(2, '0')})',
                    ),
                    _infoChip(
                      context,
                      _t('ddd.vuSoftwareVersion'),
                      t.softwareVersion,
                    ),
                    if (t.manufacturingDate != null)
                      _infoChip(
                        context,
                        _t('ddd.vuManufacturingDate'),
                        _formatDateTime(t.manufacturingDate!),
                      ),
                    _infoChip(
                      context,
                      _t('ddd.vuApprovalNumber'),
                      t.approvalNumber,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _t('ddd.vuTechnicalDataSensor'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.outline,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _infoChip(
                      context,
                      _t('ddd.vuSensorSerialNumber'),
                      '${t.sensorSerialNumber} (${t.sensorSerialMonth.toString().padLeft(2, '0')}/20${t.sensorSerialYear.toString().padLeft(2, '0')})',
                    ),
                    _infoChip(
                      context,
                      _t('ddd.vuSensorApprovalNumber'),
                      t.sensorApprovalNumber,
                    ),
                    if (t.sensorPairingDateFirst != null)
                      _infoChip(
                        context,
                        _t('ddd.vuSensorPairingDate'),
                        _formatDateTime(t.sensorPairingDateFirst!),
                      ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildVuEventsSection(
    BuildContext context,
    List<VuEventOrFault> items,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return _sectionCard(
      context,
      title: '${_t('ddd.vuEventsAndFaults')} (${items.length})',
      child: items.isEmpty
          ? Text(
              _t('ddd.vuNoEventsAndFaults'),
              style: TextStyle(color: scheme.outline),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEventFrequencyChart(context, items),
                const SizedBox(height: 16),
                ...items.map(
                  (e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          e.isFault ? Icons.report : Icons.info_outline,
                          size: 18,
                          color: e.isFault ? scheme.error : scheme.tertiary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _vuEventLabel(e.type, e.isFault),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${_formatDateTime(e.beginTime!)} - ${e.endTime != null ? _formatDateTime(e.endTime!) : _t('ddd.stillInUse')}'
                                '${e.driverCardNumber.isNotEmpty ? ' • ${e.driverCardNumber}' : ''}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEventFrequencyChart(
    BuildContext context,
    List<VuEventOrFault> items,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final counts = <String, int>{};
    final isFaultByLabel = <String, bool>{};
    for (final e in items) {
      final label = _vuEventLabel(e.type, e.isFault);
      counts[label] = (counts[label] ?? 0) + 1;
      isFaultByLabel[label] = e.isFault;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCount = sorted.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('ddd.eventFrequencyTitle'),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        for (final entry in sorted)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 130,
                  child: Text(
                    entry.key,
                    style: const TextStyle(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        Container(
                          height: 14,
                          color: scheme.surfaceContainerHighest,
                        ),
                        FractionallySizedBox(
                          widthFactor: entry.value / maxCount,
                          child: Container(
                            height: 14,
                            color: isFaultByLabel[entry.key]!
                                ? scheme.error
                                : scheme.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 22,
                  child: Text(
                    '${entry.value}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _vuEventLabel(int type, bool isFault) {
    return isFault
        ? EuEventFaultCodes.faultLabel(type)
        : EuEventFaultCodes.eventLabel(type);
  }

  Widget _buildVuOverspeedingSection(
    BuildContext context,
    List<VuOverspeedingEvent> items,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return _sectionCard(
      context,
      title: '${_t('ddd.vuOverspeeding')} (${items.length})',
      child: items.isEmpty
          ? Text(
              _t('ddd.vuNoOverspeeding'),
              style: TextStyle(color: scheme.outline),
            )
          : Column(
              children: items
                  .map(
                    (o) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.speed, size: 18, color: scheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_formatDateTime(o.beginTime!)} - ${o.endTime != null ? _formatDateTime(o.endTime!) : '-'}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (o.driverCardNumber.isNotEmpty)
                                  Text(
                                    o.driverCardNumber,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.outline,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${o.maxSpeedKmh} km/h',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: scheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildVuCalibrationSection(
    BuildContext context,
    List<VuCalibrationRecord> items,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return _sectionCard(
      context,
      title: '${_t('ddd.vuCalibration')} (${items.length})',
      child: items.isEmpty
          ? Text(
              _t('ddd.vuNoCalibration'),
              style: TextStyle(color: scheme.outline),
            )
          : Column(
              children: items
                  .map(
                    (c) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.build_circle_outlined,
                                size: 18,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  c.workshopName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 26),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                if (c.workshopAddress.isNotEmpty)
                                  Text(
                                    c.workshopAddress,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.outline,
                                    ),
                                  ),
                                Text(
                                  '${_t('ddd.authorisedSpeed')}: ${c.authorisedSpeedKmh} km/h',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.outline,
                                  ),
                                ),
                                Text(
                                  '${_t('ddd.odometer')}: ${c.oldOdometerKm} → ${c.newOdometerKm} km',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.outline,
                                  ),
                                ),
                                if (c.nextCalibrationDate != null)
                                  Text(
                                    '${_t('ddd.nextCalibration')}: ${_formatDate(c.nextCalibrationDate!)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.outline,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildVuDailyActivitySection(
    BuildContext context,
    List<VuDailyActivity> days,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return _sectionCard(
      context,
      title: '${_t('ddd.vuDailyActivity')} (${days.length})',
      child: days.isEmpty
          ? Text(
              _t('ddd.vuNoDailyActivity'),
              style: TextStyle(color: scheme.outline),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ActivityChartLegend(
                  drivingColor: scheme.primary,
                  drivingLabel: _t('timeline.driving'),
                  breakLabel: _t('timeline.break_'),
                  workLabel: _t('timeline.otherWork'),
                  availableLabel: _t('timeline.available'),
                  unknownLabel: _t('violation.missingRecord'),
                ),
                const SizedBox(height: 12),
                ...days.map((d) => _buildVuDayTile(context, d)),
              ],
            ),
    );
  }

  Widget _buildVuDayTile(BuildContext context, VuDailyActivity day) {
    final scheme = Theme.of(context).colorScheme;
    final byType = <ActivityType, int>{};
    for (final a in day.activities) {
      byType[a.type] = (byType[a.type] ?? 0) + a.duration.inMinutes;
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        title: Row(
          children: [
            Expanded(
              child: Text(
                _formatDate(day.date),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${day.odometerMidnightKm} km',
              style: TextStyle(fontSize: 12, color: scheme.outline),
            ),
          ],
        ),
        subtitle: Wrap(
          spacing: 8,
          children: [
            for (final e in byType.entries)
              Text(
                '${_activityLabel(e.key)}: ${_fmtMinutes(e.value)}',
                style: TextStyle(fontSize: 11, color: scheme.outline),
              ),
          ],
        ),
        children: [
          if (day.activities.where((a) => a.slot == DriverSlot.driver).length >
              1) ...[
            _buildVuDaySlotChart(
              context,
              day,
              DriverSlot.driver,
              _slotHolderName(day, DriverSlot.driver) ?? _t('ddd.slotDriver'),
            ),
            if (day.activities.any((a) => a.slot == DriverSlot.coDriver)) ...[
              const SizedBox(height: 10),
              _buildVuDaySlotChart(
                context,
                day,
                DriverSlot.coDriver,
                _slotHolderName(day, DriverSlot.coDriver) ??
                    _t('ddd.slotCoDriver'),
              ),
            ],
            const SizedBox(height: 12),
            ..._buildVuDayActivityTimeline(context, day),
            const SizedBox(height: 12),
          ] else if (day.cardSessions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                _t('ddd.vuNoCardSessions'),
                style: TextStyle(fontSize: 12, color: scheme.outline),
              ),
            ),
          if (day.cardSessions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                _t('ddd.vuNoCardSessions'),
                style: TextStyle(fontSize: 12, color: scheme.outline),
              ),
            )
          else
            ...day.cardSessions.map(
              (s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _cardTypeIcon(s.cardType),
                      size: 16,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  s.fullName.isEmpty ? '-' : s.fullName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              if (s.cardType != 1) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _cardTypeLabel(s.cardType),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: scheme.onSecondaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            '${s.insertionTime != null ? _formatDateTime(s.insertionTime!) : '-'} - '
                            '${s.withdrawalTime != null ? _formatDateTime(s.withdrawalTime!) : _t('ddd.stillInUse')}',
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.outline,
                            ),
                          ),

                          Text(
                            _cardSlotLabel(s.cardSlot),
                            style: TextStyle(
                              fontSize: 10,
                              color: scheme.outline,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _cardTypeLabel(int cardType) {
    switch (cardType) {
      case 1:
        return _t('ddd.cardTypeDriver');
      case 2:
        return _t('ddd.cardTypeWorkshop');
      case 3:
        return _t('ddd.cardTypeControl');
      case 4:
        return _t('ddd.cardTypeCompany');
      case 5:
        return _t('ddd.cardTypeManufacturer');
      default:
        return _t('ddd.cardTypeUnknown');
    }
  }

  String _cardSlotLabel(int cardSlot) =>
      cardSlot == 0 ? _t('ddd.slotDriver') : _t('ddd.slotCoDriver');

  IconData _cardTypeIcon(int cardType) {
    switch (cardType) {
      case 2:
        return Icons.build_outlined;
      case 3:
        return Icons.local_police_outlined;
      case 4:
        return Icons.business_outlined;
      case 5:
        return Icons.factory_outlined;
      default:
        return Icons.badge_outlined;
    }
  }

  String? _slotHolderName(VuDailyActivity day, DriverSlot slot) {
    final targetCardSlot = slot == DriverSlot.driver ? 0 : 1;
    for (final s in day.cardSessions) {
      if (s.cardSlot == targetCardSlot &&
          s.cardType == 1 &&
          s.fullName.isNotEmpty) {
        return s.fullName;
      }
    }
    return null;
  }

  Widget _buildVuDaySlotChart(
    BuildContext context,
    VuDailyActivity day,
    DriverSlot slot,
    String label,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final activities = day.activities.where((a) => a.slot == slot).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: scheme.outline,
          ),
        ),
        const SizedBox(height: 4),
        ActivityDayBarChart(
          activities: activities,
          day: day.date,
          showTimeAxis: slot == DriverSlot.driver,
        ),
      ],
    );
  }

  String _fmtMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}s ${m}d';
  }

  List<Widget> _buildVuDayActivityTimeline(
    BuildContext context,
    VuDailyActivity day,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final sorted = [...day.activities]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return [
      for (final a in sorted)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                _activityIcon(a.type),
                size: 14,
                color: _activityTimelineColor(a, scheme),
              ),
              const SizedBox(width: 8),
              Text(
                '${_formatTimeOnly(a.startTime)} - ${_formatTimeOnly(a.endTime)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _activityLabel(a.type),
                  style: TextStyle(fontSize: 12, color: scheme.outline),
                ),
              ),
              if (a.slot == DriverSlot.coDriver) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _slotHolderName(day, DriverSlot.coDriver) ??
                        _t('ddd.slotCoDriver'),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
    ];
  }

  Color _activityTimelineColor(TachographActivity a, ColorScheme scheme) {
    switch (a.type) {
      case ActivityType.driving:
        return scheme.primary;
      case ActivityType.rest:
        return ActivityDayBarChart.breakColor;
      case ActivityType.work:
        return ActivityDayBarChart.workColor;
      case ActivityType.available:
        return ActivityDayBarChart.availableColor;
      case ActivityType.unknown:
        return ActivityDayBarChart.unknownColor;
    }
  }

  String _formatTimeOnly(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  List<DateTime> _speedChartDays(List<VuSpeedSession> sessions) {
    final days = <DateTime>{};
    for (final s in sessions) {
      var d = DateTime(s.start.year, s.start.month, s.start.day);
      final endDay = DateTime(s.end.year, s.end.month, s.end.day);
      while (!d.isAfter(endDay)) {
        days.add(d);
        d = d.add(const Duration(days: 1));
      }
    }
    return days.toList()..sort((a, b) => b.compareTo(a));
  }

  Widget _buildVuSpeedSessionsSection(
    BuildContext context,
    List<VuSpeedSession> sessions,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final totalMinutes = sessions.fold<int>(
      0,
      (sum, s) => sum + s.duration.inMinutes,
    );
    return _sectionCard(
      context,
      title: '${_t('ddd.vuSpeedSessions')} (${sessions.length})',
      child: sessions.isEmpty
          ? Text(
              _t('ddd.vuNoSpeedSessions'),
              style: TextStyle(color: scheme.outline),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('ddd.vuSpeedSessionsTotal').replaceFirst(
                    '{hours}',
                    (totalMinutes / 60).toStringAsFixed(1),
                  ),
                  style: TextStyle(fontSize: 12, color: scheme.outline),
                ),
                const SizedBox(height: 16),
                ..._speedChartDays(sessions).map(
                  (day) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(day),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        VuSpeedDayChart(sessions: sessions, day: day),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                ...sessions.map(
                  (s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.speed_outlined,
                          size: 18,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_formatDateTime(s.start)} - ${_formatDateTime(s.end)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${s.duration.inMinutes} ${_t('ddd.minutesShort')}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${_t('ddd.maxSpeed')}: ${s.maxSpeedKmh} km/h',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCardHolderSection(
    BuildContext context,
    TachographDriverData data,
    DddFile file,
  ) {
    final initials = _initialsFor(data.holderFullName);
    return _sectionCard(
      context,
      title: _t('ddd.cardHolder'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.holderFullName.isEmpty ? '-' : data.holderFullName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          file.cardType,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                            fontSize: 13,
                          ),
                        ),
                        if (file.isSimulated) ...[
                          const SizedBox(width: 8),
                          _tag(
                            context,
                            _t('ddd.simulatedBadge'),
                            Theme.of(context).colorScheme.tertiary,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _infoChip(context, _t('ddd.cardNumber'), data.cardNumber),
              _infoChip(
                context,
                _t('ddd.issuingState'),
                _countryLabel(data.cardIssuingMemberState),
              ),
              if (data.dateOfBirth != null)
                _infoChip(
                  context,
                  _t('ddd.dateOfBirth'),
                  _formatDate(data.dateOfBirth!),
                ),
              if (data.language.isNotEmpty)
                _infoChip(context, _t('ddd.language'), data.language),
              if (data.licenseNumber.isNotEmpty)
                _infoChip(context, _t('ddd.licenseNumber'), data.licenseNumber),
              if (data.cardIssueDate != null)
                _infoChip(
                  context,
                  _t('ddd.cardIssueDate'),
                  _formatDate(data.cardIssueDate!),
                ),
              if (data.cardExpiryDate != null)
                _infoChip(
                  context,
                  _t('ddd.expiryDate'),
                  _formatDate(data.cardExpiryDate!),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _initialsFor(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Widget _tag(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _infoChip(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsSection(BuildContext context, TachographDriverData data) {
    final totalCount = data.lastEvents.length + data.lastFaults.length;
    final card = _sectionCard(
      context,
      title: '${_t('ddd.eventsAndFaults')} ($totalCount)',
      child: totalCount == 0
          ? Text(
              _t('ddd.noEvents'),
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data.lastFaults.isNotEmpty) ...[
                  Text(
                    '${_t('ddd.faultsSubheader')} (${data.lastFaults.length})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  ..._buildEventTiles(context, data.lastFaults),
                  if (data.lastEvents.isNotEmpty) const SizedBox(height: 12),
                ],
                if (data.lastEvents.isNotEmpty) ...[
                  Text(
                    '${_t('ddd.eventsSubheader')} (${data.lastEvents.length})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                  ),
                  ..._buildEventTiles(context, data.lastEvents),
                ],
              ],
            ),
    );
    if (data.lastFaults.isEmpty) return card;
    return Badge(
      label: Text('${data.lastFaults.length}'),
      backgroundColor: Theme.of(context).colorScheme.error,
      alignment: Alignment.topRight,
      offset: const Offset(-8, 8),
      child: card,
    );
  }

  List<Widget> _buildEventTiles(BuildContext context, List<TachoEvent> items) {
    return items.map((e) {
      final color = e.isFault
          ? Theme.of(context).colorScheme.error
          : Theme.of(context).colorScheme.tertiary;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: Icon(
          e.isFault ? Icons.report : Icons.info_outline,
          color: color,
          size: 20,
        ),
        title: Text(
          e.description,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _formatDateTime(e.timestamp),
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        trailing: _tag(
          context,
          e.isFault ? _t('ddd.faultBadge') : _t('ddd.eventBadge'),
          color,
        ),
      );
    }).toList();
  }

  Widget _buildActivityLogSection(
    BuildContext context,
    TachographDriverData data,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final groups = _groupActivitiesByDay(data.activityLog);
    return _sectionCard(
      context,
      title: '${_t('ddd.activityLog')} (${groups.length})',
      child: data.activityLog.isEmpty
          ? Text(_t('timeline.noData'), style: TextStyle(color: scheme.outline))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ActivityChartLegend(
                  drivingColor: scheme.primary,
                  drivingLabel: _t('timeline.driving'),
                  breakLabel: _t('timeline.break_'),
                  workLabel: _t('timeline.otherWork'),
                  availableLabel: _t('timeline.available'),
                  unknownLabel: _t('violation.missingRecord'),
                ),
                const SizedBox(height: 12),
                for (final g in groups)
                  _buildCardActivityDayTile(context, g.day, g.activities),
              ],
            ),
    );
  }

  List<_CardActivityRecordGroup> _groupActivitiesByDay(
    List<TachographActivity> log,
  ) {
    final byKey = <String, _CardActivityRecordGroup>{};
    for (final a in log) {
      var cursor = DateTime.utc(
        a.startTime.year,
        a.startTime.month,
        a.startTime.day,
      );

      final effectiveEnd = a.endTime.subtract(const Duration(microseconds: 1));
      final endDay = DateTime.utc(
        effectiveEnd.year,
        effectiveEnd.month,
        effectiveEnd.day,
      );
      while (!cursor.isAfter(endDay)) {
        final key = '${cursor.toIso8601String()}#${a.recordPresenceCounter}';
        final group = byKey.putIfAbsent(
          key,
          () => _CardActivityRecordGroup(
            day: cursor,
            recordPresenceCounter: a.recordPresenceCounter,
          ),
        );
        group.activities.add(a);
        cursor = cursor.add(const Duration(days: 1));
      }
    }
    final groups = byKey.values.toList()
      ..sort((a, b) {
        final dayCmp = b.day.compareTo(a.day);
        if (dayCmp != 0) return dayCmp;
        return (a.recordPresenceCounter ?? 0).compareTo(
          b.recordPresenceCounter ?? 0,
        );
      });
    return groups;
  }

  Widget _buildCardActivityDayTile(
    BuildContext context,
    DateTime day,
    List<TachographActivity> activities,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final dayStart = day;
    final dayEnd = day.add(const Duration(days: 1));
    final byType = <ActivityType, int>{};
    for (final a in activities) {
      final start = a.startTime.isBefore(dayStart) ? dayStart : a.startTime;
      final end = a.endTime.isAfter(dayEnd) ? dayEnd : a.endTime;
      final minutes = end.difference(start).inMinutes;
      if (minutes > 0) byType[a.type] = (byType[a.type] ?? 0) + minutes;
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        title: Text(
          _formatDate(day),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Wrap(
          spacing: 8,
          children: [
            for (final e in byType.entries)
              Text(
                '${_activityLabel(e.key)}: ${_fmtMinutes(e.value)}',
                style: TextStyle(fontSize: 11, color: scheme.outline),
              ),
          ],
        ),
        children: [
          ActivityDayBarChart(
            activities: activities,
            day: day,
            showTimeAxis: true,
          ),
          const SizedBox(height: 12),
          ...activities.map((a) {
            final color = _activityTimelineColor(a, scheme);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(_activityIcon(a.type), size: 18, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_formatTimeOnly(a.startTime)} - ${_formatTimeOnly(a.endTime)}',
                      style: TextStyle(color: color),
                    ),
                  ),
                  Text(
                    _activityLabel(a.type),
                    style: TextStyle(fontWeight: FontWeight.w600, color: color),
                  ),
                  if (a.isCrew) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message:
                          '${_t('ddd.crewBadge')} · ${a.slot == DriverSlot.coDriver ? _t('ddd.slotCoDriver') : _t('ddd.slotDriver')}',
                      child: Icon(
                        Icons.people_alt,
                        size: 16,
                        color: scheme.tertiary,
                      ),
                    ),
                  ],
                  if (a.isManualEntry) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: _t('ddd.manualEntryBadge'),
                      child: Icon(
                        Icons.edit_note,
                        size: 16,
                        color: scheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildViolationsSection(
    BuildContext context,
    List<Violation> violations,
  ) {
    return _sectionCard(
      context,
      title: _t('ddd.violations'),
      child: violations.isEmpty
          ? Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(_t('ddd.noViolations')),
              ],
            )
          : Column(
              children: violations
                  .map(
                    (v) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning,
                            color: Theme.of(context).colorScheme.error,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _t(v.descriptionKey),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${_formatDateTime(v.start)} - ${_formatDateTime(v.end)} • ${v.ruleReference}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildExportButton(
    BuildContext context,
    TachographDriverData? cardData,
    CardFileDetails? cardDetails,
    VehicleUnitData? vuData,
    List<Violation> violations,
    RolePermissions perms,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _exporting
            ? null
            : () =>
                  _exportPdf(cardData, cardDetails, vuData, violations, perms),
        icon: _exporting
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            : const Icon(Icons.picture_as_pdf),
        label: Text(_exporting ? _t('ddd.exporting') : _t('ddd.exportPdf')),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Future<void> _exportPdf(
    TachographDriverData? cardData,
    CardFileDetails? cardDetails,
    VehicleUnitData? vuData,
    List<Violation> violations,
    RolePermissions perms,
  ) async {
    setState(() => _exporting = true);
    try {
      final bytes = await PdfExportService.buildPdf(
        cardData: cardData,
        cardDetails: cardDetails,
        vuData: vuData,
        violations: violations,
        perms: perms,
      );

      try {
        await Printing.layoutPdf(onLayout: (_) async => bytes);
        if (mounted)
          showAppSnackBar(
            context,
            _t('ddd.exportSuccess'),
            type: AppSnackBarType.success,
          );
      } catch (e, st) {
        debugPrint('Printing.layoutPdf failed, falling back to share: $e\n$st');
        final fileName =
            'smarttrack_${_file?.id ?? DateTime.now().millisecondsSinceEpoch}.pdf';
        await Share.shareXFiles(
          [XFile.fromData(bytes, name: fileName, mimeType: 'application/pdf')],
          fileNameOverrides: [fileName],
        );
        if (mounted)
          showAppSnackBar(
            context,
            _t('ddd.exportSuccess'),
            type: AppSnackBarType.success,
          );
      }
    } catch (e, st) {
      debugPrint('PDF export failed: $e\n$st');
      if (mounted) {
        showAppSnackBar(
          context,
          _t('ddd.exportError'),
          type: AppSnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  String _countryLabel(String raw) {
    final code = int.tryParse(raw);
    return code != null ? EuNationCodes.label(code) : raw;
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.${dt.year} $h:$min';
  }

  IconData _activityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.driving:
        return Icons.directions_car;
      case ActivityType.rest:
        return Icons.hotel;
      case ActivityType.work:
        return Icons.engineering;
      case ActivityType.available:
        return Icons.event_available;
      case ActivityType.unknown:
        return Icons.help_outline;
    }
  }

  String _activityLabel(ActivityType type) {
    switch (type) {
      case ActivityType.driving:
        return _t('logs.driving');
      case ActivityType.rest:
        return _t('logs.break_');
      case ActivityType.work:
        return _t('timeline.work');
      case ActivityType.available:
        return _t('timeline.available');
      case ActivityType.unknown:
        return _t('violation.missingRecord');
    }
  }
}

class _CardActivityRecordGroup {
  _CardActivityRecordGroup({
    required this.day,
    required this.recordPresenceCounter,
  });

  final DateTime day;
  final int? recordPresenceCounter;
  final List<TachographActivity> activities = [];
}
