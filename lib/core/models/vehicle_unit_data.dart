import 'card_file_details.dart';
import '../services/driving_time_calculator.dart';

class IdentifiedText {
  final String text;
  final String? sourceLabelKey;

  const IdentifiedText({required this.text, this.sourceLabelKey});
}

class VehicleUnitData {
  final String vin;
  final String vehicleRegistrationNumber;

  final List<IdentifiedText> identificationTexts;

  final List<VuSpeedSession> speedSessions;

  final List<VuDailyActivity> dailyActivities;

  final List<VuEventOrFault> eventsAndFaults;

  final List<VuOverspeedingEvent> overspeedingEvents;

  final List<VuCalibrationRecord> calibrationRecords;

  final VuTechnicalData? technicalData;

  final VuOverviewData? overview;

  const VehicleUnitData({
    this.vin = '',
    this.vehicleRegistrationNumber = '',
    this.identificationTexts = const [],
    this.speedSessions = const [],
    this.dailyActivities = const [],
    this.eventsAndFaults = const [],
    this.overspeedingEvents = const [],
    this.calibrationRecords = const [],
    this.technicalData,
    this.overview,
  });
}

class VuOverviewData {
  final DateTime? currentDateTime;
  final DateTime? downloadablePeriodStart;
  final DateTime? downloadablePeriodEnd;

  const VuOverviewData({
    this.currentDateTime,
    this.downloadablePeriodStart,
    this.downloadablePeriodEnd,
  });
}

class VuTechnicalData {
  final String manufacturerName;
  final String manufacturerAddress;
  final String partNumber;
  final int serialNumber;
  final int serialMonth;
  final int serialYear;
  final int equipmentType;
  final int manufacturerCode;
  final String softwareVersion;
  final DateTime? softInstallationDate;
  final DateTime? manufacturingDate;
  final String approvalNumber;

  final int sensorSerialNumber;
  final int sensorSerialMonth;
  final int sensorSerialYear;
  final int sensorEquipmentType;
  final int sensorManufacturerCode;
  final String sensorApprovalNumber;
  final DateTime? sensorPairingDateFirst;

  final int numberOfCalibrationRecords;

  const VuTechnicalData({
    required this.manufacturerName,
    required this.manufacturerAddress,
    required this.partNumber,
    required this.serialNumber,
    required this.serialMonth,
    required this.serialYear,
    required this.equipmentType,
    required this.manufacturerCode,
    required this.softwareVersion,
    required this.softInstallationDate,
    required this.manufacturingDate,
    required this.approvalNumber,
    required this.sensorSerialNumber,
    required this.sensorSerialMonth,
    required this.sensorSerialYear,
    required this.sensorEquipmentType,
    required this.sensorManufacturerCode,
    required this.sensorApprovalNumber,
    required this.sensorPairingDateFirst,
    required this.numberOfCalibrationRecords,
  });
}

class VuSpeedSession {
  final DateTime start;
  final DateTime end;
  final int maxSpeedKmh;
  final double avgSpeedKmh;

  final List<int> speedSamples;

  const VuSpeedSession({
    required this.start,
    required this.end,
    required this.maxSpeedKmh,
    required this.avgSpeedKmh,
    this.speedSamples = const [],
  });

  Duration get duration => end.difference(start);
}

class VuDailyActivity {
  final DateTime date;
  final int odometerMidnightKm;
  final List<VuCardSession> cardSessions;
  final List<TachographActivity> activities;
  final List<PlaceRecord> places;
  final List<SpecificConditionRecord> specificConditions;

  const VuDailyActivity({
    required this.date,
    required this.odometerMidnightKm,
    this.cardSessions = const [],
    this.activities = const [],
    this.places = const [],
    this.specificConditions = const [],
  });
}

class VuCardSession {
  final String surname;
  final String firstName;
  final String cardNumber;
  final DateTime? insertionTime;
  final DateTime? withdrawalTime;
  final int odometerAtInsertionKm;
  final int odometerAtWithdrawalKm;
  final int cardSlot;

  final int cardType;

  const VuCardSession({
    required this.surname,
    required this.firstName,
    required this.cardNumber,
    required this.insertionTime,
    required this.withdrawalTime,
    required this.odometerAtInsertionKm,
    required this.odometerAtWithdrawalKm,
    required this.cardSlot,
    this.cardType = 1,
  });

  String get fullName => '$firstName $surname'.trim();
}

class VuEventOrFault {
  final int type;
  final int recordPurpose;
  final bool isFault;
  final DateTime? beginTime;
  final DateTime? endTime;
  final String driverCardNumber;
  final String codriverCardNumber;
  final int similarEventsNumber;

  const VuEventOrFault({
    required this.type,
    required this.recordPurpose,
    required this.isFault,
    required this.beginTime,
    required this.endTime,
    required this.driverCardNumber,
    required this.codriverCardNumber,
    required this.similarEventsNumber,
  });
}

class VuOverspeedingEvent {
  final DateTime? beginTime;
  final DateTime? endTime;
  final int maxSpeedKmh;
  final int avgSpeedKmh;
  final String driverCardNumber;
  final int similarEventsNumber;

  const VuOverspeedingEvent({
    required this.beginTime,
    required this.endTime,
    required this.maxSpeedKmh,
    required this.avgSpeedKmh,
    required this.driverCardNumber,
    required this.similarEventsNumber,
  });
}

class VuCalibrationRecord {
  final int purpose;
  final String workshopName;
  final String workshopAddress;
  final String workshopCardNumber;
  final DateTime? workshopCardExpiryDate;
  final String vin;
  final String vrn;
  final int tyreCircumferenceMm;
  final int authorisedSpeedKmh;
  final int oldOdometerKm;
  final int newOdometerKm;
  final DateTime? oldTime;
  final DateTime? newTime;
  final DateTime? nextCalibrationDate;

  const VuCalibrationRecord({
    required this.purpose,
    required this.workshopName,
    required this.workshopAddress,
    required this.workshopCardNumber,
    required this.workshopCardExpiryDate,
    required this.vin,
    required this.vrn,
    required this.tyreCircumferenceMm,
    required this.authorisedSpeedKmh,
    required this.oldOdometerKm,
    required this.newOdometerKm,
    required this.oldTime,
    required this.newTime,
    required this.nextCalibrationDate,
  });
}
