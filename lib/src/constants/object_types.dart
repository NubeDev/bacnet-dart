/// Standard BACnet object type constants.
///
/// Matches the API surface of `bacnet_plugin`'s `BacnetObjectType`.
abstract final class BacnetObjectType {
  static const int analogInput = 0;
  static const int analogOutput = 1;
  static const int analogValue = 2;
  static const int binaryInput = 3;
  static const int binaryOutput = 4;
  static const int binaryValue = 5;
  static const int calendar = 6;
  static const int command = 7;
  static const int device = 8;
  static const int eventEnrollment = 9;
  static const int file = 10;
  static const int group = 11;
  static const int loop = 12;
  static const int multiStateInput = 13;
  static const int multiStateOutput = 14;
  static const int notificationClass = 15;
  static const int program = 16;
  static const int schedule = 17;
  static const int averaging = 18;
  static const int multiStateValue = 19;
  static const int trendLog = 20;
  static const int lifeSafetyPoint = 21;
  static const int lifeSafetyZone = 22;
  static const int accumulator = 23;
  static const int pulseConverter = 24;

  /// Human-readable name for an object type.
  static String getName(int objectType) {
    return switch (objectType) {
      analogInput => 'Analog Input',
      analogOutput => 'Analog Output',
      analogValue => 'Analog Value',
      binaryInput => 'Binary Input',
      binaryOutput => 'Binary Output',
      binaryValue => 'Binary Value',
      calendar => 'Calendar',
      command => 'Command',
      device => 'Device',
      eventEnrollment => 'Event Enrollment',
      file => 'File',
      group => 'Group',
      loop => 'Loop',
      multiStateInput => 'Multi-State Input',
      multiStateOutput => 'Multi-State Output',
      notificationClass => 'Notification Class',
      program => 'Program',
      schedule => 'Schedule',
      averaging => 'Averaging',
      multiStateValue => 'Multi-State Value',
      trendLog => 'Trend Log',
      lifeSafetyPoint => 'Life Safety Point',
      lifeSafetyZone => 'Life Safety Zone',
      accumulator => 'Accumulator',
      pulseConverter => 'Pulse Converter',
      _ => 'Unknown ($objectType)',
    };
  }
}
