/// Helpers for reading/writing BACnet object metadata (name, units, description).
import '../client/bacnet_client.dart';
import '../codec/tag.dart' show AppTag;
import '../constants/property_ids.dart';

/// Extension on [BacnetClient] for object metadata operations.
extension ObjectHelpers on BacnetClient {
  // ---------------------------------------------------------------------------
  // Object name
  // ---------------------------------------------------------------------------

  /// Read the object name.
  Future<String?> readObjectName(
    int deviceId,
    int objectType,
    int objectInstance,
  ) async {
    final value = await readProperty(
      deviceId, objectType, objectInstance, BacnetPropertyId.objectName,
    );
    return value?.toString();
  }

  /// Write the object name.
  Future<void> writeObjectName(
    int deviceId,
    int objectType,
    int objectInstance,
    String name,
  ) {
    return writeProperty(
      deviceId,
      objectType,
      objectInstance,
      BacnetPropertyId.objectName,
      name,
      tag: AppTag.characterString,
    );
  }

  // ---------------------------------------------------------------------------
  // Description
  // ---------------------------------------------------------------------------

  /// Read the object description.
  Future<String?> readDescription(
    int deviceId,
    int objectType,
    int objectInstance,
  ) async {
    final value = await readProperty(
      deviceId, objectType, objectInstance, BacnetPropertyId.description,
    );
    return value?.toString();
  }

  /// Write the object description.
  Future<void> writeDescription(
    int deviceId,
    int objectType,
    int objectInstance,
    String description,
  ) {
    return writeProperty(
      deviceId,
      objectType,
      objectInstance,
      BacnetPropertyId.description,
      description,
      tag: AppTag.characterString,
    );
  }

  // ---------------------------------------------------------------------------
  // Units
  // ---------------------------------------------------------------------------

  /// Read engineering units (returns ASHRAE 135 enum integer).
  Future<int?> readUnits(
    int deviceId,
    int objectType,
    int objectInstance,
  ) async {
    final value = await readProperty(
      deviceId, objectType, objectInstance, BacnetPropertyId.units,
    );
    return value is int ? value : null;
  }

  /// Write engineering units (ASHRAE 135 enum integer).
  ///
  /// Common values: 62=degC, 64=degF, 98=percent, 95=no-units.
  Future<void> writeUnits(
    int deviceId,
    int objectType,
    int objectInstance,
    int units,
  ) {
    return writeProperty(
      deviceId,
      objectType,
      objectInstance,
      BacnetPropertyId.units,
      units,
      tag: AppTag.enumerated,
    );
  }
}
