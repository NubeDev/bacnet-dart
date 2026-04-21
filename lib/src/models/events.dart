import 'dart:io';

import '../codec/apdu.dart' show AtomicReadFileAck, AtomicWriteFileAck, RpmObjectResult;

/// Base class for all BACnet events received from the network.
sealed class BacnetEvent {
  const BacnetEvent();
}

/// An I-Am response received after a Who-Is broadcast.
class IAmResponse extends BacnetEvent {
  const IAmResponse({
    required this.deviceId,
    required this.maxApduLength,
    required this.segmentationSupported,
    required this.vendorId,
    required this.sourceAddress,
    required this.sourcePort,
  });

  final int deviceId;
  final int maxApduLength;
  final int segmentationSupported;
  final int vendorId;
  final InternetAddress sourceAddress;
  final int sourcePort;

  @override
  String toString() =>
      'IAmResponse(device: $deviceId, from: ${sourceAddress.address}:$sourcePort)';
}

/// A ReadProperty-ACK received in response to a read request.
class ReadPropertyResponse extends BacnetEvent {
  const ReadPropertyResponse({
    required this.invokeId,
    required this.objectType,
    required this.objectInstance,
    required this.propertyId,
    this.arrayIndex,
    required this.value,
  });

  final int invokeId;
  final int objectType;
  final int objectInstance;
  final int propertyId;
  final int? arrayIndex;
  final dynamic value;

  @override
  String toString() =>
      'ReadPropertyResponse(invokeId: $invokeId, value: $value)';
}

/// An AtomicReadFile-ACK response.
class AtomicReadFileResponse extends BacnetEvent {
  const AtomicReadFileResponse({
    required this.invokeId,
    required this.ack,
  });

  final int invokeId;
  final AtomicReadFileAck ack;

  @override
  String toString() =>
      'AtomicReadFileResponse(invokeId: $invokeId, eof: ${ack.endOfFile}, bytes: ${ack.data.fold<int>(0, (s, d) => s + d.length)})';
}

/// An AtomicWriteFile-ACK response.
class AtomicWriteFileResponse extends BacnetEvent {
  const AtomicWriteFileResponse({
    required this.invokeId,
    required this.ack,
  });

  final int invokeId;
  final AtomicWriteFileAck ack;

  @override
  String toString() =>
      'AtomicWriteFileResponse(invokeId: $invokeId, pos: ${ack.startPosition})';
}

/// A ReadPropertyMultiple-ACK received in response to an RPM request.
class ReadPropertyMultipleResponse extends BacnetEvent {
  const ReadPropertyMultipleResponse({
    required this.invokeId,
    required this.results,
  });

  final int invokeId;

  /// Per-object, per-property results.
  final List<RpmObjectResult> results;

  @override
  String toString() =>
      'ReadPropertyMultipleResponse(invokeId: $invokeId, objects: ${results.length})';
}

/// A BACnet error response.
class ErrorResponse extends BacnetEvent {
  const ErrorResponse({
    required this.invokeId,
    required this.errorClass,
    required this.errorCode,
  });

  final int invokeId;
  final int errorClass;
  final int errorCode;

  @override
  String toString() =>
      'ErrorResponse(invokeId: $invokeId, class: $errorClass, code: $errorCode)';
}

/// A simple ACK (e.g. WriteProperty success).
class SimpleAckResponse extends BacnetEvent {
  const SimpleAckResponse({
    required this.invokeId,
    required this.serviceChoice,
  });

  final int invokeId;
  final int serviceChoice;

  @override
  String toString() =>
      'SimpleAckResponse(invokeId: $invokeId, service: $serviceChoice)';
}
