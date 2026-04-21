/// Helpers for BACnet priority array operations (override / release).
import '../client/bacnet_client.dart';
import '../codec/tag.dart' show AppTag;
import '../constants/property_ids.dart';

/// Extension on [BacnetClient] for priority array operations.
extension PriorityHelpers on BacnetClient {
  /// Override present value at a specific priority level.
  ///
  /// [priority] 1 = manual life-safety, 8 = manual-operator, 16 = lowest.
  Future<void> overrideValue(
    int deviceId,
    int objectType,
    int objectInstance,
    double value, {
    required int priority,
  }) {
    return writeProperty(
      deviceId,
      objectType,
      objectInstance,
      BacnetPropertyId.presentValue,
      value,
      priority: priority,
      tag: AppTag.real,
    );
  }

  /// Release (relinquish) a priority slot by writing null.
  ///
  /// The object falls back to the next active priority, or relinquish-default.
  Future<void> releasePriority(
    int deviceId,
    int objectType,
    int objectInstance, {
    required int priority,
  }) {
    return writeProperty(
      deviceId,
      objectType,
      objectInstance,
      BacnetPropertyId.presentValue,
      null,
      priority: priority,
      tag: AppTag.null_,
    );
  }

  /// Read the full 16-slot priority array.
  ///
  /// Returns a list or raw value depending on device support.
  Future<dynamic> readPriorityArray(
    int deviceId,
    int objectType,
    int objectInstance,
  ) {
    return readProperty(
      deviceId,
      objectType,
      objectInstance,
      BacnetPropertyId.priorityArray,
    );
  }

  /// Read a single priority slot (1-16).
  Future<dynamic> readPrioritySlot(
    int deviceId,
    int objectType,
    int objectInstance, {
    required int slot,
  }) {
    return readProperty(
      deviceId,
      objectType,
      objectInstance,
      BacnetPropertyId.priorityArray,
      arrayIndex: slot,
    );
  }

  /// Read the relinquish default value.
  Future<dynamic> readRelinquishDefault(
    int deviceId,
    int objectType,
    int objectInstance,
  ) {
    return readProperty(
      deviceId,
      objectType,
      objectInstance,
      BacnetPropertyId.relinquishDefault,
    );
  }
}
