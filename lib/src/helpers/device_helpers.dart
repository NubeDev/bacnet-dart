/// Helpers for reading BACnet device-level information.
import '../client/bacnet_client.dart';
import '../constants/object_types.dart';
import '../constants/property_ids.dart';

/// Device info snapshot returned by [DeviceHelpers.readDeviceInfo].
class BacnetDeviceInfo {
  const BacnetDeviceInfo({
    required this.deviceId,
    this.name,
    this.description,
    this.location,
    this.modelName,
    this.vendorName,
    this.vendorId,
    this.firmwareRevision,
    this.applicationSoftwareVersion,
    this.protocolVersion,
    this.protocolRevision,
    this.systemStatus,
    this.maxApduLength,
    this.segmentationSupported,
    this.objectCount,
  });

  final int deviceId;
  final String? name;
  final String? description;
  final String? location;
  final String? modelName;
  final String? vendorName;
  final int? vendorId;
  final String? firmwareRevision;
  final String? applicationSoftwareVersion;
  final int? protocolVersion;
  final int? protocolRevision;
  final int? systemStatus;
  final int? maxApduLength;
  final int? segmentationSupported;
  final int? objectCount;

  @override
  String toString() => 'BacnetDeviceInfo('
      'id: $deviceId, '
      'name: $name, '
      'model: $modelName, '
      'vendor: $vendorName [$vendorId], '
      'fw: $firmwareRevision, '
      'app: $applicationSoftwareVersion, '
      'protocol: $protocolVersion.$protocolRevision, '
      'objects: $objectCount)';
}

/// Extension on [BacnetClient] for device-level queries.
extension DeviceHelpers on BacnetClient {
  /// Read a single device property, returning null on failure.
  Future<T?> _readDeviceProp<T>(int deviceId, int propertyId) async {
    try {
      final value = await readProperty(
        deviceId,
        BacnetObjectType.device,
        deviceId,
        propertyId,
      );
      if (value is T) return value;
      if (T == String) return value?.toString() as T?;
      if (T == int && value is num) return value.toInt() as T?;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Read the device object name.
  Future<String?> readDeviceName(int deviceId) =>
      _readDeviceProp<String>(deviceId, BacnetPropertyId.objectName);

  /// Read the device model name.
  Future<String?> readModelName(int deviceId) =>
      _readDeviceProp<String>(deviceId, BacnetPropertyId.modelName);

  /// Read the device vendor name.
  Future<String?> readVendorName(int deviceId) =>
      _readDeviceProp<String>(deviceId, BacnetPropertyId.vendorName);

  /// Read the device vendor identifier.
  Future<int?> readVendorId(int deviceId) =>
      _readDeviceProp<int>(deviceId, BacnetPropertyId.vendorIdentifier);

  /// Read the device firmware revision.
  Future<String?> readFirmwareRevision(int deviceId) =>
      _readDeviceProp<String>(deviceId, BacnetPropertyId.firmwareRevision);

  /// Read the device application software version.
  Future<String?> readAppSoftwareVersion(int deviceId) =>
      _readDeviceProp<String>(
          deviceId, BacnetPropertyId.applicationSoftwareVersion);

  /// Read the device description.
  Future<String?> readDeviceDescription(int deviceId) =>
      _readDeviceProp<String>(deviceId, BacnetPropertyId.description);

  /// Read the device location string.
  Future<String?> readDeviceLocation(int deviceId) =>
      _readDeviceProp<String>(deviceId, BacnetPropertyId.location);

  /// Read all common device properties in one call.
  ///
  /// Reads each property individually. For batch reads, use
  /// [BacnetClient.readPropertyMultiple] directly.
  /// Properties that fail silently return null.
  Future<BacnetDeviceInfo> readDeviceInfo(int deviceId) async {
    final results = await Future.wait([
      _readDeviceProp<String>(deviceId, BacnetPropertyId.objectName),       // 0
      _readDeviceProp<String>(deviceId, BacnetPropertyId.description),      // 1
      _readDeviceProp<String>(deviceId, BacnetPropertyId.location),         // 2
      _readDeviceProp<String>(deviceId, BacnetPropertyId.modelName),        // 3
      _readDeviceProp<String>(deviceId, BacnetPropertyId.vendorName),       // 4
      _readDeviceProp<int>(deviceId, BacnetPropertyId.vendorIdentifier),    // 5
      _readDeviceProp<String>(deviceId, BacnetPropertyId.firmwareRevision), // 6
      _readDeviceProp<String>(                                              // 7
          deviceId, BacnetPropertyId.applicationSoftwareVersion),
      _readDeviceProp<int>(deviceId, BacnetPropertyId.protocolVersion),     // 8
      _readDeviceProp<int>(deviceId, BacnetPropertyId.protocolRevision),    // 9
      _readDeviceProp<int>(deviceId, BacnetPropertyId.systemStatus),        // 10
      _readDeviceProp<int>(deviceId, BacnetPropertyId.maxApduLengthAccepted), // 11
      _readDeviceProp<int>(deviceId, BacnetPropertyId.segmentationSupported), // 12
      _readObjectCount(deviceId),                                           // 13
    ]);

    return BacnetDeviceInfo(
      deviceId: deviceId,
      name: results[0] as String?,
      description: results[1] as String?,
      location: results[2] as String?,
      modelName: results[3] as String?,
      vendorName: results[4] as String?,
      vendorId: results[5] as int?,
      firmwareRevision: results[6] as String?,
      applicationSoftwareVersion: results[7] as String?,
      protocolVersion: results[8] as int?,
      protocolRevision: results[9] as int?,
      systemStatus: results[10] as int?,
      maxApduLength: results[11] as int?,
      segmentationSupported: results[12] as int?,
      objectCount: results[13] as int?,
    );
  }

  /// Read the object list count (array index 0).
  Future<int?> _readObjectCount(int deviceId) async {
    try {
      final value = await readProperty(
        deviceId,
        BacnetObjectType.device,
        deviceId,
        BacnetPropertyId.objectList,
        arrayIndex: 0,
      );
      return value is int ? value : null;
    } catch (_) {
      return null;
    }
  }
}
