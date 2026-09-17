/// Pure-Dart BACnet/IP client.
///
/// Uses [RawDatagramSocket] for UDP — no FFI, no native code, works on
/// Android, iOS, macOS, Linux, and Windows.
///
/// API surface designed to be a drop-in replacement for `bacnet_plugin`.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../codec/apdu.dart';
import '../codec/npdu.dart';
import '../codec/tag.dart' show ObjectId;
import '../constants/object_types.dart';
import '../constants/error_codes.dart';
import '../constants/property_ids.dart';
import '../models/bacnet_object.dart';
import '../models/events.dart';
import '../transport/udp_transport.dart';

/// Configuration for the BACnet client.
class BacnetClientConfig {
  const BacnetClientConfig({
    this.port = 47808,
    this.timeout = const Duration(seconds: 5),
  });

  /// BACnet/IP port (default ACnet standard 0xBAC0 = 47808).
  final int port;

  /// Default timeout for confirmed requests.
  final Duration timeout;
}

/// Pure-Dart BACnet/IP client.
class BacnetClient {
  BacnetClient({this.config = const BacnetClientConfig()});

  final BacnetClientConfig config;
  final UdpTransport _transport = UdpTransport();
  final _eventController = StreamController<BacnetEvent>.broadcast();

  /// Monotonically increasing invoke ID for confirmed requests.
  int _nextInvokeId = 0;

  /// Pending confirmed requests awaiting responses.
  final Map<int, Completer<BacnetEvent>> _pending = {};

  /// Device binding table: deviceId → (address, port).
  final Map<int, (InternetAddress, int)> _deviceBindings = {};

  StreamSubscription<void>? _transportSub;

  /// Stream of unsolicited BACnet events (I-Am, errors, etc).
  Stream<BacnetEvent> get events => _eventController.stream;

  /// Whether the client is currently connected.
  bool get isConnected => _transport.isBound;

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  /// Start the BACnet client, binding to a network interface.
  ///
  /// [interface_] — bind address or interface name. Currently used only for
  /// validation; the socket binds to `0.0.0.0` to receive broadcast responses.
  /// [port] — override the default BACnet/IP port.
  Future<void> start({String? interface_, int? port}) async {
    // We always bind to anyIPv4 so we can receive broadcast responses.
    // Binding to a specific IP causes broadcast replies to be missed on Linux.
    await _transport.bind(port: port ?? config.port);

    _transportSub = _transport.datagrams.listen(
      _handleDatagram,
      onError: (Object e) => _eventController.addError(e),
    );
  }

  /// Stop the client and release all resources.
  void dispose() {
    _transportSub?.cancel();
    _transport.close();
    // Fail all pending requests
    for (final completer in _pending.values) {
      completer.completeError(
        StateError('BACnet client disposed while request was pending'),
      );
    }
    _pending.clear();
    _eventController.close();
  }

  // -------------------------------------------------------------------------
  // Device binding
  // -------------------------------------------------------------------------

  /// Register a device's IP address for unicast communication.
  void addDeviceBinding(int deviceId, String ip, {int? port}) {
    _deviceBindings[deviceId] = (
      InternetAddress(ip),
      port ?? config.port,
    );
  }

  /// Remove a device binding.
  void removeDeviceBinding(int deviceId) {
    _deviceBindings.remove(deviceId);
  }

  /// Get the binding for a device, or null.
  (InternetAddress, int)? getDeviceBinding(int deviceId) {
    return _deviceBindings[deviceId];
  }

  // -------------------------------------------------------------------------
  // Who-Is / I-Am
  // -------------------------------------------------------------------------

  /// Broadcast a Who-Is request to discover BACnet devices.
  ///
  /// Responses arrive as [IAmResponse] on the [events] stream.
  void sendWhoIs({int lowLimit = -1, int highLimit = -1}) {
    final apdu = encodeWhoIs(lowLimit: lowLimit, highLimit: highLimit);
    final npdu = _wrapNpdu(apdu, expectingReply: false);
    _transport.sendBroadcast(config.port, npdu);
  }

  /// Send a Who-Is to **one** address rather than to the broadcast domain.
  ///
  /// A device answers a directed Who-Is with the same I-Am it would send to a
  /// broadcast one, so responses arrive as [IAmResponse] on [events] exactly
  /// as they do for [sendWhoIs].
  ///
  /// This exists because broadcast discovery is not dependable everywhere it
  /// is needed: Android's handling of broadcast UDP to 47808 varies by
  /// version and by OEM, and plenty of sites route BACnet across subnets where
  /// a local broadcast never reaches the controller at all. A directed probe
  /// at a known address works in both cases, and it is the only way to
  /// discover a device whose address is known but whose broadcast domain is
  /// not shared.
  void sendWhoIsTo(
    String ip,
    int port, {
    int lowLimit = -1,
    int highLimit = -1,
  }) {
    final apdu = encodeWhoIs(lowLimit: lowLimit, highLimit: highLimit);
    final npdu = _wrapNpdu(apdu, expectingReply: false);
    _transport.sendUnicast(InternetAddress(ip), port, npdu);
  }

  // -------------------------------------------------------------------------
  // ReadProperty
  // -------------------------------------------------------------------------

  /// Read a single property from a BACnet object.
  ///
  /// Returns the property value. Throws on timeout or BACnet error.
  Future<dynamic> readProperty(
    int deviceId,
    int objectType,
    int objectInstance,
    int propertyId, {
    int arrayIndex = -1,
  }) async {
    final invokeId = _allocInvokeId();
    final apdu = encodeReadProperty(
      invokeId: invokeId,
      objectType: objectType,
      objectInstance: objectInstance,
      propertyId: propertyId,
      arrayIndex: arrayIndex,
    );

    final event = await _sendConfirmed(deviceId, apdu, invokeId);
    if (event is ReadPropertyResponse) return event.value;
    if (event is ErrorResponse) {
      throw BacnetException(
        'ReadProperty error: class=${event.errorClass}, code=${event.errorCode}',
        event.errorClass,
        event.errorCode,
      );
    }
    throw StateError('Unexpected response type: ${event.runtimeType}');
  }

  // -------------------------------------------------------------------------
  // WriteProperty
  // -------------------------------------------------------------------------

  /// Write a value to a BACnet object property.
  ///
  /// [tag] is the BACnet application tag for the value (default 4 = REAL).
  Future<void> writeProperty(
    int deviceId,
    int objectType,
    int objectInstance,
    int propertyId,
    dynamic value, {
    int priority = 16,
    int tag = 4,
  }) async {
    final invokeId = _allocInvokeId();
    final apdu = encodeWriteProperty(
      invokeId: invokeId,
      objectType: objectType,
      objectInstance: objectInstance,
      propertyId: propertyId,
      value: value,
      priority: priority,
      tag: tag,
    );

    final event = await _sendConfirmed(deviceId, apdu, invokeId);
    if (event is SimpleAckResponse) return;
    if (event is ErrorResponse) {
      throw BacnetException(
        'WriteProperty error: class=${event.errorClass}, code=${event.errorCode}',
        event.errorClass,
        event.errorCode,
      );
    }
    throw StateError('Unexpected response type: ${event.runtimeType}');
  }

  // -------------------------------------------------------------------------
  // AtomicReadFile
  // -------------------------------------------------------------------------

  /// Read file data from a BACnet File object using stream access.
  ///
  /// Returns an [AtomicReadFileAck] with the file data and end-of-file flag.
  /// To read an entire file, call repeatedly until [AtomicReadFileAck.endOfFile]
  /// is true, advancing [startPosition] by the returned data length each time.
  Future<AtomicReadFileAck> readFile(
    int deviceId,
    int fileInstance, {
    int startPosition = 0,
    int count = 1476,
    bool isStream = true,
  }) async {
    final invokeId = _allocInvokeId();
    final apdu = encodeAtomicReadFile(
      invokeId: invokeId,
      objectInstance: fileInstance,
      startPosition: startPosition,
      count: count,
      isStream: isStream,
    );

    final event = await _sendConfirmed(deviceId, apdu, invokeId);
    if (event is AtomicReadFileResponse) return event.ack;
    if (event is ErrorResponse) {
      throw BacnetException(
        'AtomicReadFile error: class=${event.errorClass}, code=${event.errorCode}',
        event.errorClass,
        event.errorCode,
      );
    }
    throw StateError('Unexpected response type: ${event.runtimeType}');
  }

  /// Read an entire file by looping until end-of-file.
  ///
  /// Convenience wrapper around [readFile] for stream access.
  Future<Uint8List> readFileAll(
    int deviceId,
    int fileInstance, {
    int chunkSize = 1476,
  }) async {
    final buf = BytesBuilder();
    var pos = 0;
    while (true) {
      final ack = await readFile(
        deviceId, fileInstance,
        startPosition: pos, count: chunkSize,
      );
      if (ack.data.isNotEmpty) {
        buf.add(ack.data[0]);
        pos += ack.data[0].length;
      }
      if (ack.endOfFile || ack.data.isEmpty || ack.data[0].isEmpty) break;
    }
    return buf.toBytes();
  }

  // -------------------------------------------------------------------------
  // AtomicWriteFile
  // -------------------------------------------------------------------------

  /// Write file data to a BACnet File object.
  ///
  /// [isStream] selects stream vs record mode. The Node.js bacnet-stack had a
  /// bug where this was hardcoded to false (record mode) — we default to true
  /// (stream mode) which is what most devices expect.
  ///
  /// Returns the start position acknowledged by the device.
  Future<int> writeFile(
    int deviceId,
    int fileInstance,
    Uint8List data, {
    int startPosition = 0,
    bool isStream = true,
  }) async {
    final invokeId = _allocInvokeId();
    final apdu = encodeAtomicWriteFile(
      invokeId: invokeId,
      objectInstance: fileInstance,
      startPosition: startPosition,
      fileData: [data],
      isStream: isStream,
    );

    final event = await _sendConfirmed(deviceId, apdu, invokeId);
    if (event is AtomicWriteFileResponse) return event.ack.startPosition;
    if (event is ErrorResponse) {
      throw BacnetException(
        'AtomicWriteFile error: class=${event.errorClass}, code=${event.errorCode}',
        event.errorClass,
        event.errorCode,
      );
    }
    throw StateError('Unexpected response type: ${event.runtimeType}');
  }

  /// Write file data to a BACnet File object using record access.
  ///
  /// Each entry in [records] is one record (octet string).
  Future<int> writeFileRecords(
    int deviceId,
    int fileInstance,
    List<Uint8List> records, {
    int startRecord = 0,
  }) async {
    final invokeId = _allocInvokeId();
    final apdu = encodeAtomicWriteFile(
      invokeId: invokeId,
      objectInstance: fileInstance,
      startPosition: startRecord,
      fileData: records,
      isStream: false,
    );

    final event = await _sendConfirmed(deviceId, apdu, invokeId);
    if (event is AtomicWriteFileResponse) return event.ack.startPosition;
    if (event is ErrorResponse) {
      throw BacnetException(
        'AtomicWriteFile error: class=${event.errorClass}, code=${event.errorCode}',
        event.errorClass,
        event.errorCode,
      );
    }
    throw StateError('Unexpected response type: ${event.runtimeType}');
  }

  // -------------------------------------------------------------------------
  // ReadPropertyMultiple
  // -------------------------------------------------------------------------

  /// Read multiple properties from one or more objects in a single request.
  ///
  /// Returns a list of [RpmObjectResult], each containing a list of
  /// [RpmPropertyResult] with either a value or a per-property error.
  ///
  /// Example:
  /// ```dart
  /// final results = await client.readPropertyMultiple(deviceId, [
  ///   RpmReadAccessSpec(
  ///     objectType: BacnetObjectType.analogInput,
  ///     objectInstance: 1,
  ///     properties: [
  ///       RpmPropertyRef(BacnetPropertyId.presentValue),
  ///       RpmPropertyRef(BacnetPropertyId.objectName),
  ///     ],
  ///   ),
  /// ]);
  /// ```
  Future<List<RpmObjectResult>> readPropertyMultiple(
    int deviceId,
    List<RpmReadAccessSpec> specs,
  ) async {
    final invokeId = _allocInvokeId();
    final apdu = encodeReadPropertyMultiple(
      invokeId: invokeId,
      specs: specs,
    );

    final event = await _sendConfirmed(deviceId, apdu, invokeId);
    if (event is ReadPropertyMultipleResponse) return event.results;
    if (event is ErrorResponse) {
      throw BacnetException(
        'ReadPropertyMultiple error: class=${event.errorClass}, code=${event.errorCode}',
        event.errorClass,
        event.errorCode,
      );
    }
    throw StateError('Unexpected response type: ${event.runtimeType}');
  }

  // -------------------------------------------------------------------------
  // scanDevice — read the object list from a device
  // -------------------------------------------------------------------------

  /// Enumerate all objects on a device by reading its object list.
  ///
  /// Returns a list of [BacnetObject] with type and instance populated.
  Future<List<BacnetObject>> scanDevice(int deviceId) async {
    // First read array index 0 to get the count
    final countResult = await readProperty(
      deviceId,
      BacnetObjectType.device,
      deviceId,
      BacnetPropertyId.objectList,
      arrayIndex: 0,
    );

    final count = countResult is int ? countResult : 0;
    if (count == 0) return [];

    final objects = <BacnetObject>[];
    for (var i = 1; i <= count; i++) {
      try {
        final objId = await readProperty(
          deviceId,
          BacnetObjectType.device,
          deviceId,
          BacnetPropertyId.objectList,
          arrayIndex: i,
        );

        if (objId is ObjectId) {
          objects.add(BacnetObject(type: objId.type, instance: objId.instance));
        }
      } catch (_) {
        // Skip objects we can't read
      }
    }

    return objects;
  }

  // -------------------------------------------------------------------------
  // Internal: packet handling
  // -------------------------------------------------------------------------

  void _handleDatagram(BacnetDatagram datagram) {
    final npduHeader = decodeNpduHeader(datagram.data);
    if (npduHeader == null) return;
    if (npduHeader.isNetworkLayerMessage) return; // Not an application message

    final apduData = extractApdu(datagram.data, npduHeader);
    final apduHeader = decodeApduHeader(apduData);
    if (apduHeader == null) return;

    switch (apduHeader.type) {
      case ApduType.unconfirmedRequest:
        _handleUnconfirmed(apduHeader, apduData, datagram);

      case ApduType.complexAck:
        _handleComplexAck(apduHeader, apduData);

      case ApduType.simpleAck:
        _handleSimpleAck(apduHeader);

      case ApduType.error:
        _handleError(apduHeader, apduData);

      case ApduType.reject:
      case ApduType.abort:
        _handleRejectAbort(apduHeader);
    }
  }

  void _handleUnconfirmed(
    ApduHeader header,
    Uint8List apduData,
    BacnetDatagram datagram,
  ) {
    if (header.serviceChoice == UnconfirmedService.iAm) {
      final payload = Uint8List.sublistView(apduData, header.headerLength);
      final iam = decodeIAm(payload);
      if (iam == null) return;

      // Auto-register device binding from I-Am source
      _deviceBindings[iam.deviceId] = (
        datagram.sourceAddress,
        datagram.sourcePort,
      );

      final event = IAmResponse(
        deviceId: iam.deviceId,
        maxApduLength: iam.maxApduLength,
        segmentationSupported: iam.segmentationSupported,
        vendorId: iam.vendorId,
        sourceAddress: datagram.sourceAddress,
        sourcePort: datagram.sourcePort,
      );
      _eventController.add(event);
    }
  }

  void _handleComplexAck(ApduHeader header, Uint8List apduData) {
    final payload = Uint8List.sublistView(apduData, header.headerLength);

    if (header.serviceChoice == ConfirmedService.readProperty) {
      final ack = decodeReadPropertyAck(payload);
      if (ack == null) return;

      final event = ReadPropertyResponse(
        invokeId: header.invokeId,
        objectType: ack.objectType,
        objectInstance: ack.objectInstance,
        propertyId: ack.propertyId,
        arrayIndex: ack.arrayIndex,
        value: ack.value,
      );

      _completePending(header.invokeId, event);
      _eventController.add(event);
    } else if (header.serviceChoice ==
        ConfirmedService.readPropertyMultiple) {
      final results = decodeReadPropertyMultipleAck(payload);
      if (results == null) return;

      final event = ReadPropertyMultipleResponse(
        invokeId: header.invokeId,
        results: results,
      );

      _completePending(header.invokeId, event);
      _eventController.add(event);
    } else if (header.serviceChoice ==
        ConfirmedService.atomicReadFile) {
      final ack = decodeAtomicReadFileAck(payload);
      if (ack == null) return;

      final event = AtomicReadFileResponse(
        invokeId: header.invokeId,
        ack: ack,
      );

      _completePending(header.invokeId, event);
      _eventController.add(event);
    } else if (header.serviceChoice ==
        ConfirmedService.atomicWriteFile) {
      final ack = decodeAtomicWriteFileAck(payload);
      if (ack == null) return;

      final event = AtomicWriteFileResponse(
        invokeId: header.invokeId,
        ack: ack,
      );

      _completePending(header.invokeId, event);
      _eventController.add(event);
    }
  }

  void _handleSimpleAck(ApduHeader header) {
    final event = SimpleAckResponse(
      invokeId: header.invokeId,
      serviceChoice: header.serviceChoice,
    );
    _completePending(header.invokeId, event);
    _eventController.add(event);
  }

  void _handleError(ApduHeader header, Uint8List apduData) {
    final payload = Uint8List.sublistView(apduData, header.headerLength);
    final err = decodeBacnetError(payload);

    final event = ErrorResponse(
      invokeId: header.invokeId,
      errorClass: err?.errorClass ?? -1,
      errorCode: err?.errorCode ?? -1,
    );
    _completePending(header.invokeId, event);
    _eventController.add(event);
  }

  void _handleRejectAbort(ApduHeader header) {
    final event = ErrorResponse(
      invokeId: header.invokeId,
      errorClass: -1,
      errorCode: header.serviceChoice, // reject/abort reason
    );
    _completePending(header.invokeId, event);
    _eventController.add(event);
  }

  // -------------------------------------------------------------------------
  // Internal: request/response plumbing
  // -------------------------------------------------------------------------

  int _allocInvokeId() {
    final id = _nextInvokeId;
    _nextInvokeId = (_nextInvokeId + 1) & 0xFF;
    return id;
  }

  Future<BacnetEvent> _sendConfirmed(
    int deviceId,
    Uint8List apdu,
    int invokeId,
  ) async {
    final binding = _deviceBindings[deviceId];
    if (binding == null) {
      throw StateError(
        'No binding for device $deviceId — call addDeviceBinding() '
        'or run Who-Is discovery first',
      );
    }

    final completer = Completer<BacnetEvent>();
    _pending[invokeId] = completer;

    final npdu = _wrapNpdu(apdu, expectingReply: true);
    _transport.sendUnicast(binding.$1, binding.$2, npdu);

    try {
      return await completer.future.timeout(config.timeout);
    } on TimeoutException {
      _pending.remove(invokeId);
      throw TimeoutException(
        'No response from device $deviceId (invokeId=$invokeId)',
        config.timeout,
      );
    }
  }

  void _completePending(int invokeId, BacnetEvent event) {
    final completer = _pending.remove(invokeId);
    if (completer != null && !completer.isCompleted) {
      completer.complete(event);
    }
  }

  Uint8List _wrapNpdu(Uint8List apdu, {required bool expectingReply}) {
    final npduHeader = encodeNpdu(expectingReply: expectingReply);
    final result = Uint8List(npduHeader.length + apdu.length);
    result.setRange(0, npduHeader.length, npduHeader);
    result.setRange(npduHeader.length, result.length, apdu);
    return result;
  }

  Future<InternetAddress?> _resolveInterface(String interface_) async {
    // Try parsing as IP address first
    try {
      return InternetAddress(interface_);
    } catch (_) {}

    // Try finding by interface name
    final interfaces = await NetworkInterface.list();
    for (final iface in interfaces) {
      if (iface.name == interface_) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4) return addr;
        }
      }
    }
    return null;
  }
}

/// Exception thrown for BACnet protocol errors.
///
/// Use [toFriendlyString] for a user-facing description that includes
/// human-readable error class / code names and an optional hint.
class BacnetException implements Exception {
  const BacnetException(this.message, this.errorClass, this.errorCode);
  final String message;
  final int errorClass;
  final int errorCode;

  /// Short human-readable label, e.g. `"property / inconsistent-parameters"`.
  String get friendlyName =>
      '${errorClassName(errorClass)} / ${errorCodeName(errorCode)}';

  /// Optional hint explaining the likely cause, or `null`.
  String? get hint => bacnetErrorHints['$errorClass:$errorCode'];

  /// Full user-facing description with class/code names and hint.
  String toFriendlyString() => formatBacnetError(errorClass, errorCode);

  @override
  String toString() => 'BacnetException: $message\n  → ${toFriendlyString()}';
}
