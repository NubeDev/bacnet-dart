/// BACnet error class and error code definitions (ASHRAE 135).
///
/// Provides human-readable names for the numeric error class / code pairs
/// returned by BACnet devices.

/// Error class names — the broad category of the error.
const Map<int, String> bacnetErrorClasses = {
  0: 'device',
  1: 'object',
  2: 'property',
  3: 'resources',
  4: 'security',
  5: 'services',
  6: 'vt',
  7: 'communication',
};

/// Error code names — the specific reason for the error.
const Map<int, String> bacnetErrorCodes = {
  0: 'other',
  1: 'authentication-failed',
  2: 'configuration-in-progress',
  3: 'device-busy',
  4: 'dynamic-creation-not-supported',
  5: 'file-access-denied',
  9: 'inconsistent-parameters',
  10: 'inconsistent-selection-criterion',
  11: 'invalid-file-start-position',
  14: 'invalid-array-index',
  15: 'invalid-configuration-data',
  20: 'invalid-data-type',
  21: 'invalid-file-access-method',
  23: 'invalid-file-start-position',
  25: 'invalid-parameter-data-type',
  26: 'invalid-time-stamp',
  31: 'missing-required-parameter',
  32: 'no-objects-of-specified-type',
  33: 'no-space-for-object',
  34: 'no-space-to-add-list-element',
  35: 'no-space-to-write-property',
  36: 'no-vt-sessions-available',
  40: 'object-deletion-not-permitted',
  41: 'object-identifier-already-exists',
  42: 'operational-problem',
  43: 'optional-functionality-not-supported',
  44: 'password-failure',
  46: 'read-access-denied',
  47: 'security-not-supported',
  48: 'service-request-denied',
  49: 'timeout',
  50: 'unknown-object',
  51: 'unknown-property',
  53: 'unknown-vt-class',
  54: 'unknown-vt-session',
  55: 'unsupported-object-type',
  56: 'value-out-of-range',
  57: 'vt-session-already-closed',
  58: 'vt-session-termination-failure',
  59: 'write-access-denied',
  60: 'character-set-not-supported',
  61: 'invalid-data-encoding',
  62: 'datatype-not-supported',
  63: 'duplicate-name',
  64: 'duplicate-object-id',
  65: 'property-is-not-an-array',
  73: 'abort-buffer-overflow',
  74: 'abort-invalid-apdu-in-this-state',
  75: 'abort-preempted-by-higher-priority-task',
  76: 'abort-segmentation-not-supported',
  77: 'abort-proprietary',
  78: 'abort-other',
  80: 'key-generation-error',
  81: 'security-not-configured',
  82: 'source-security-required',
  83: 'too-many-keys',
  84: 'unknown-authentication-type',
  85: 'unknown-key',
  86: 'unknown-key-revision',
  87: 'unknown-source-message',
  113: 'not-configured',
};

/// User-friendly descriptions for common error class + code combos.
const Map<String, String> bacnetErrorHints = {
  '2:9': 'The value type or priority does not match what the device expects '
      '(e.g. writing a float to an integer point, or wrong priority).',
  '2:20': 'The data type sent does not match the property data type.',
  '2:25': 'The parameter data type is wrong for this property.',
  '2:46': 'The device denied read access — check device security settings.',
  '2:59': 'The device denied write access — the point may be read-only or '
      'require a different priority.',
  '2:56': 'The value is outside the acceptable range for this property.',
  '1:50': 'The object does not exist on the device.',
  '1:51': 'The property does not exist on this object.',
  '5:48': 'The device rejected the service request.',
  '0:3': 'The device is busy — retry after a short delay.',
};

/// Returns a human-readable label for a BACnet error class number.
String errorClassName(int errorClass) =>
    bacnetErrorClasses[errorClass] ?? 'unknown($errorClass)';

/// Returns a human-readable label for a BACnet error code number.
String errorCodeName(int errorCode) =>
    bacnetErrorCodes[errorCode] ?? 'unknown($errorCode)';

/// Returns a formatted, user-friendly error description.
///
/// Example output:
/// ```
/// property / inconsistent-parameters (class=2, code=9)
/// Hint: The value type or priority does not match what the device expects.
/// ```
String formatBacnetError(int errorClass, int errorCode) {
  final className = errorClassName(errorClass);
  final codeName = errorCodeName(errorCode);
  final buf = StringBuffer('$className / $codeName (class=$errorClass, code=$errorCode)');

  final hint = bacnetErrorHints['$errorClass:$errorCode'];
  if (hint != null) {
    buf.write('\nHint: $hint');
  }
  return buf.toString();
}
