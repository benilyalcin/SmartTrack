class CardFileDetails {
  final DateTime? lastDownloadDate;

  final String drivingLicenceAuthority;
  final String drivingLicenceNumber;

  final DateTime? currentUsageSessionOpenTime;
  final String currentUsageVehicleRegistration;

  final ControlActivityRecord? lastControlActivity;

  final List<VehicleUsageRecord> vehicleRecords;

  final List<PlaceRecord> places;

  final List<SpecificConditionRecord> specificConditions;

  const CardFileDetails({
    this.lastDownloadDate,
    this.drivingLicenceAuthority = '',
    this.drivingLicenceNumber = '',
    this.currentUsageSessionOpenTime,
    this.currentUsageVehicleRegistration = '',
    this.lastControlActivity,
    this.vehicleRecords = const [],
    this.places = const [],
    this.specificConditions = const [],
  });
}

class ControlActivityRecord {
  final int controlType;
  final DateTime? controlTime;
  final String controlCardNumber;
  final String controlVehicleRegistration;
  final DateTime? downloadPeriodBegin;
  final DateTime? downloadPeriodEnd;

  const ControlActivityRecord({
    required this.controlType,
    required this.controlTime,
    required this.controlCardNumber,
    required this.controlVehicleRegistration,
    required this.downloadPeriodBegin,
    required this.downloadPeriodEnd,
  });
}

class PlaceRecord {
  final DateTime? entryTime;
  final int entryType;
  final int countryCode;
  final int region;
  final int odometerKm;

  const PlaceRecord({
    required this.entryTime,
    required this.entryType,
    required this.countryCode,
    required this.region,
    required this.odometerKm,
  });
}

class VehicleUsageRecord {
  final String vehicleRegistration;
  final int odometerBeginKm;

  final int? odometerEndKm;
  final DateTime? firstUse;
  final DateTime? lastUse;

  const VehicleUsageRecord({
    required this.vehicleRegistration,
    required this.odometerBeginKm,
    required this.odometerEndKm,
    required this.firstUse,
    required this.lastUse,
  });
}

class SpecificConditionRecord {
  final DateTime? time;
  final int type;

  const SpecificConditionRecord({required this.time, required this.type});
}
