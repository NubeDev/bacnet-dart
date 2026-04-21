/// Standard BACnet property identifier constants.
///
/// Matches the API surface of `bacnet_plugin`'s `BacnetPropertyId`.
abstract final class BacnetPropertyId {
  static const int ackedTransitions = 0;
  static const int ackRequired = 1;
  static const int action = 2;
  static const int actionText = 3;
  static const int activeText = 4;
  static const int alarmValue = 6;
  static const int all = 8;
  static const int apduTimeout = 11;
  static const int applicationSoftwareVersion = 12;
  static const int description = 28;
  static const int deviceAddressBinding = 30;
  static const int deviceType = 31;
  static const int eventState = 36;
  static const int firmwareRevision = 44;
  static const int inactiveText = 46;
  static const int limitEnable = 52;
  static const int localDate = 56;
  static const int localTime = 57;
  static const int location = 58;
  static const int maxApduLengthAccepted = 62;
  static const int maxPresValue = 65;
  static const int minPresValue = 69;
  static const int modelName = 70;
  static const int numberOfStates = 74;
  static const int objectIdentifier = 75;
  static const int objectList = 76;
  static const int objectName = 77;
  static const int objectType = 79;
  static const int outOfService = 81;
  static const int polarity = 84;
  static const int presentValue = 85;
  static const int priority = 86;
  static const int priorityArray = 87;
  static const int protocolObjectTypesSupported = 96;
  static const int protocolServicesSupported = 97;
  static const int protocolVersion = 98;
  static const int reliability = 103;
  static const int relinquishDefault = 104;
  static const int resolution = 106;
  static const int segmentationSupported = 107;
  static const int stateText = 110;
  static const int statusFlags = 111;
  static const int systemStatus = 112;
  static const int units = 117;
  static const int vendorIdentifier = 120;
  static const int vendorName = 121;
  static const int weeklySchedule = 123;
  static const int protocolRevision = 139;
  static const int logBuffer = 131;

  /// Human-readable name for a property identifier.
  static String getName(int propertyId) {
    return switch (propertyId) {
      description => 'Description',
      objectIdentifier => 'Object Identifier',
      objectList => 'Object List',
      objectName => 'Object Name',
      objectType => 'Object Type',
      outOfService => 'Out of Service',
      presentValue => 'Present Value',
      priorityArray => 'Priority Array',
      relinquishDefault => 'Relinquish Default',
      statusFlags => 'Status Flags',
      units => 'Units',
      vendorIdentifier => 'Vendor Identifier',
      vendorName => 'Vendor Name',
      modelName => 'Model Name',
      firmwareRevision => 'Firmware Revision',
      applicationSoftwareVersion => 'Application Software Version',
      protocolVersion => 'Protocol Version',
      protocolRevision => 'Protocol Revision',
      systemStatus => 'System Status',
      location => 'Location',
      _ => 'Property $propertyId',
    };
  }
}
