import '../constants/property_ids.dart';

/// A BACnet object with its type, instance, and cached properties.
///
/// API-compatible with `bacnet_plugin`'s `BacnetObject`.
class BacnetObject {
  const BacnetObject({
    required this.type,
    required this.instance,
    this.properties = const {},
  });

  final int type;
  final int instance;
  final Map<int, dynamic> properties;

  String? get name => properties[BacnetPropertyId.objectName] as String?;
  dynamic get presentValue => properties[BacnetPropertyId.presentValue];
  String? get description => properties[BacnetPropertyId.description] as String?;
  int? get units => properties[BacnetPropertyId.units] as int?;
  bool? get outOfService => properties[BacnetPropertyId.outOfService] as bool?;

  BacnetObject copyWith({
    int? type,
    int? instance,
    Map<int, dynamic>? properties,
  }) {
    return BacnetObject(
      type: type ?? this.type,
      instance: instance ?? this.instance,
      properties: properties ?? this.properties,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BacnetObject && type == other.type && instance == other.instance;

  @override
  int get hashCode => Object.hash(type, instance);

  @override
  String toString() => 'BacnetObject(type: $type, instance: $instance)';
}
