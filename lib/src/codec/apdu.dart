/// BACnet Application Protocol Data Unit (APDU) encoding/decoding.
///
/// Handles the four APDU types:
///   - Unconfirmed request (Who-Is, I-Am)
///   - Confirmed request (ReadProperty, WriteProperty)
///   - Simple ACK
///   - Complex ACK (ReadProperty-ACK)
///   - Error
import 'dart:typed_data';

import 'tag.dart';

// ---------------------------------------------------------------------------
// APDU type constants (upper nibble of first byte)
// ---------------------------------------------------------------------------

abstract final class ApduType {
  static const int confirmedRequest = 0x00;
  static const int unconfirmedRequest = 0x10;
  static const int simpleAck = 0x20;
  static const int complexAck = 0x30;
  static const int segmentAck = 0x40;
  static const int error = 0x50;
  static const int reject = 0x60;
  static const int abort = 0x70;
}

// ---------------------------------------------------------------------------
// BACnet service choices
// ---------------------------------------------------------------------------

abstract final class ConfirmedService {
  static const int subscribeCOV = 5;
  static const int atomicReadFile = 6;
  static const int atomicWriteFile = 7;
  static const int readProperty = 12;
  static const int readPropertyMultiple = 14;
  static const int writeProperty = 15;
}

abstract final class UnconfirmedService {
  static const int iAm = 0;
  static const int iHave = 1;
  static const int whoIs = 8;
  static const int whoHas = 7;
  static const int covNotification = 2;
  static const int timeSynchronization = 6;
}

// ---------------------------------------------------------------------------
// APDU header decoding
// ---------------------------------------------------------------------------

/// Minimal parsed APDU header.
class ApduHeader {
  const ApduHeader({
    required this.type,
    required this.invokeId,
    required this.serviceChoice,
    required this.headerLength,
  });

  final int type;
  final int invokeId;
  final int serviceChoice;
  final int headerLength;
}

/// Decode an APDU header from raw bytes.
ApduHeader? decodeApduHeader(Uint8List data) {
  if (data.isEmpty) return null;

  final typeByte = data[0] & 0xF0;

  switch (typeByte) {
    case ApduType.confirmedRequest:
      // Byte 0: type | segmentation flags
      // Byte 1: max-segments | max-apdu-length
      // Byte 2: invoke ID
      // Byte 3: service choice
      if (data.length < 4) return null;
      return ApduHeader(
        type: typeByte,
        invokeId: data[2],
        serviceChoice: data[3],
        headerLength: 4,
      );

    case ApduType.unconfirmedRequest:
      // Byte 0: type
      // Byte 1: service choice
      if (data.length < 2) return null;
      return ApduHeader(
        type: typeByte,
        invokeId: -1,
        serviceChoice: data[1],
        headerLength: 2,
      );

    case ApduType.simpleAck:
      // Byte 0: type, Byte 1: invoke ID, Byte 2: service choice
      if (data.length < 3) return null;
      return ApduHeader(
        type: typeByte,
        invokeId: data[1],
        serviceChoice: data[2],
        headerLength: 3,
      );

    case ApduType.complexAck:
      // Byte 0: type, Byte 1: invoke ID, Byte 2: service choice
      if (data.length < 3) return null;
      return ApduHeader(
        type: typeByte,
        invokeId: data[1],
        serviceChoice: data[2],
        headerLength: 3,
      );

    case ApduType.error:
      // Byte 0: type, Byte 1: invoke ID, Byte 2: service choice
      if (data.length < 3) return null;
      return ApduHeader(
        type: typeByte,
        invokeId: data[1],
        serviceChoice: data[2],
        headerLength: 3,
      );

    case ApduType.reject:
      if (data.length < 3) return null;
      return ApduHeader(
        type: typeByte,
        invokeId: data[1],
        serviceChoice: data[2], // reject reason
        headerLength: 3,
      );

    case ApduType.abort:
      if (data.length < 3) return null;
      return ApduHeader(
        type: typeByte,
        invokeId: data[1],
        serviceChoice: data[2], // abort reason
        headerLength: 3,
      );

    default:
      return null;
  }
}

// ---------------------------------------------------------------------------
// Who-Is
// ---------------------------------------------------------------------------

/// Encode a Who-Is unconfirmed request.
///
/// If [lowLimit] and [highLimit] are both -1, sends an unrestricted Who-Is
/// (discovers all devices).
Uint8List encodeWhoIs({int lowLimit = -1, int highLimit = -1}) {
  final buf = BytesBuilder();
  // APDU header: unconfirmed request, service = whoIs
  buf.addByte(ApduType.unconfirmedRequest);
  buf.addByte(UnconfirmedService.whoIs);

  if (lowLimit >= 0 && highLimit >= 0) {
    // Context tag 0: low limit
    buf.add(encodeContextUnsigned(0, lowLimit));
    // Context tag 1: high limit
    buf.add(encodeContextUnsigned(1, highLimit));
  }

  return buf.toBytes();
}

// ---------------------------------------------------------------------------
// I-Am (decode only — we receive these, don't send them)
// ---------------------------------------------------------------------------

/// Parsed I-Am response.
class IAmData {
  const IAmData({
    required this.deviceId,
    required this.maxApduLength,
    required this.segmentationSupported,
    required this.vendorId,
  });

  final int deviceId;
  final int maxApduLength;
  final int segmentationSupported;
  final int vendorId;
}

/// Decode an I-Am unconfirmed request payload (after APDU header).
IAmData? decodeIAm(Uint8List data) {
  if (data.length < 8) return null;
  var offset = 0;

  // 1. BACnet Object Identifier (application tag 12 = object-identifier)
  final objIdTag = decodeTag(data, offset);
  if (objIdTag == null) return null;
  offset = objIdTag.valueOffset;
  if (offset + 4 > data.length) return null;
  final objIdValue = (data[offset] << 24) |
      (data[offset + 1] << 16) |
      (data[offset + 2] << 8) |
      data[offset + 3];
  final deviceId = objIdValue & 0x3FFFFF; // lower 22 bits = instance
  offset += objIdTag.valueLength;

  // 2. Max APDU length accepted (application tag 2 = unsigned)
  final maxApduTag = decodeTag(data, offset);
  if (maxApduTag == null) return null;
  offset = maxApduTag.valueOffset;
  final maxApduLength = decodeUnsignedValue(data, offset, maxApduTag.valueLength);
  offset += maxApduTag.valueLength;

  // 3. Segmentation supported (application tag 9 = enumerated)
  final segTag = decodeTag(data, offset);
  if (segTag == null) return null;
  offset = segTag.valueOffset;
  final segSupported = decodeUnsignedValue(data, offset, segTag.valueLength);
  offset += segTag.valueLength;

  // 4. Vendor ID (application tag 2 = unsigned)
  final vendorTag = decodeTag(data, offset);
  if (vendorTag == null) return null;
  offset = vendorTag.valueOffset;
  final vendorId = decodeUnsignedValue(data, offset, vendorTag.valueLength);

  return IAmData(
    deviceId: deviceId,
    maxApduLength: maxApduLength,
    segmentationSupported: segSupported,
    vendorId: vendorId,
  );
}

// ---------------------------------------------------------------------------
// ReadProperty
// ---------------------------------------------------------------------------

/// Encode a ReadProperty confirmed request APDU.
Uint8List encodeReadProperty({
  required int invokeId,
  required int objectType,
  required int objectInstance,
  required int propertyId,
  int arrayIndex = -1,
}) {
  final buf = BytesBuilder();

  // APDU header: confirmed request
  buf.addByte(ApduType.confirmedRequest | 0x04); // max-segs=0, SA=0
  buf.addByte(0x05); // max-apdu=1476
  buf.addByte(invokeId);
  buf.addByte(ConfirmedService.readProperty);

  // Context 0: object identifier
  buf.add(encodeContextObjectId(0, objectType, objectInstance));

  // Context 1: property identifier
  buf.add(encodeContextUnsigned(1, propertyId));

  // Context 2: array index (optional)
  if (arrayIndex >= 0) {
    buf.add(encodeContextUnsigned(2, arrayIndex));
  }

  return buf.toBytes();
}

/// Decoded ReadProperty-ACK payload.
class ReadPropertyAck {
  const ReadPropertyAck({
    required this.objectType,
    required this.objectInstance,
    required this.propertyId,
    this.arrayIndex,
    required this.value,
  });

  final int objectType;
  final int objectInstance;
  final int propertyId;
  final int? arrayIndex;
  final dynamic value;
}

/// Decode a ReadProperty-ACK complex-ACK payload (after APDU header).
ReadPropertyAck? decodeReadPropertyAck(Uint8List data) {
  var offset = 0;

  // Context 0: object identifier
  final objIdTag = decodeTag(data, offset);
  if (objIdTag == null || objIdTag.tagNumber != 0) return null;
  offset = objIdTag.valueOffset;
  final objectId = decodeObjectId(data, offset);
  offset += objIdTag.valueLength;

  // Context 1: property identifier
  final propTag = decodeTag(data, offset);
  if (propTag == null || propTag.tagNumber != 1) return null;
  offset = propTag.valueOffset;
  final propertyId = decodeUnsignedValue(data, offset, propTag.valueLength);
  offset += propTag.valueLength;

  // Context 2: array index (optional)
  int? arrayIndex;
  if (offset < data.length) {
    final maybeArrayTag = decodeTag(data, offset);
    if (maybeArrayTag != null &&
        maybeArrayTag.tagNumber == 2 &&
        maybeArrayTag.isContext) {
      offset = maybeArrayTag.valueOffset;
      arrayIndex = decodeUnsignedValue(data, offset, maybeArrayTag.valueLength);
      offset += maybeArrayTag.valueLength;
    }
  }

  // Context 3: property value — opening tag [3], value(s), closing tag [3]
  if (offset >= data.length) return null;
  final openTag = data[offset];
  if (openTag != 0x3E) return null; // opening tag 3
  offset += 1;

  // Find closing tag 0x3F
  final valueStart = offset;
  var depth = 1;
  while (offset < data.length && depth > 0) {
    if (data[offset] == 0x3F) {
      depth--;
    } else if (data[offset] == 0x3E) {
      depth++;
    }
    if (depth > 0) {
      // Skip this tag's value
      final t = decodeTag(data, offset);
      if (t == null) break;
      offset = t.valueOffset + t.valueLength;
    }
  }
  final valueEnd = offset;
  if (offset < data.length) offset += 1; // skip closing tag

  final valueData = Uint8List.sublistView(data, valueStart, valueEnd);
  final value = decodeApplicationValue(valueData);

  return ReadPropertyAck(
    objectType: objectId.type,
    objectInstance: objectId.instance,
    propertyId: propertyId,
    arrayIndex: arrayIndex,
    value: value,
  );
}

// ---------------------------------------------------------------------------
// WriteProperty
// ---------------------------------------------------------------------------

/// Encode a WriteProperty confirmed request APDU.
Uint8List encodeWriteProperty({
  required int invokeId,
  required int objectType,
  required int objectInstance,
  required int propertyId,
  required dynamic value,
  int arrayIndex = -1,
  int priority = 16,
  int tag = 4, // default application tag: real
}) {
  final buf = BytesBuilder();

  // APDU header
  buf.addByte(ApduType.confirmedRequest);
  buf.addByte(0x75); // max-apdu=1476
  buf.addByte(invokeId);
  buf.addByte(ConfirmedService.writeProperty);

  // Context 0: object identifier
  buf.add(encodeContextObjectId(0, objectType, objectInstance));

  // Context 1: property identifier
  buf.add(encodeContextUnsigned(1, propertyId));

  // Context 2: array index (optional)
  if (arrayIndex >= 0) {
    buf.add(encodeContextUnsigned(2, arrayIndex));
  }

  // Context 3: property value (opening tag, value, closing tag)
  buf.addByte(0x3E); // opening tag 3
  buf.add(encodeApplicationValue(value, tag));
  buf.addByte(0x3F); // closing tag 3

  // Context 4: priority (optional)
  if (priority > 0 && priority <= 16) {
    buf.add(encodeContextUnsigned(4, priority));
  }

  return buf.toBytes();
}

// ---------------------------------------------------------------------------
// AtomicReadFile
// ---------------------------------------------------------------------------

/// Access method for file services.
enum FileAccessMethod { stream, record }

/// Encode an AtomicReadFile confirmed request APDU.
///
/// [isStream] selects stream access (byte offset) vs record access.
/// For stream: [startPosition] is the byte offset, [count] is octets to read.
/// For record: [startPosition] is the record number, [count] is records to read.
Uint8List encodeAtomicReadFile({
  required int invokeId,
  required int objectInstance,
  required int startPosition,
  required int count,
  bool isStream = true,
}) {
  final buf = BytesBuilder();

  // APDU header
  buf.addByte(ApduType.confirmedRequest);
  buf.addByte(0x75);
  buf.addByte(invokeId);
  buf.addByte(ConfirmedService.atomicReadFile);

  // Application-tagged object identifier (type=10 = file)
  buf.add(encodeApplicationObjectId(10, objectInstance));

  if (isStream) {
    // Stream access [0]
    buf.add(encodeOpeningTag(0));
    buf.add(encodeApplicationSigned(startPosition));
    buf.add(encodeApplicationUnsigned(count));
    buf.add(encodeClosingTag(0));
  } else {
    // Record access [1]
    buf.add(encodeOpeningTag(1));
    buf.add(encodeApplicationSigned(startPosition));
    buf.add(encodeApplicationUnsigned(count));
    buf.add(encodeClosingTag(1));
  }

  return buf.toBytes();
}

/// Decoded AtomicReadFile-ACK.
class AtomicReadFileAck {
  const AtomicReadFileAck({
    required this.endOfFile,
    required this.isStream,
    required this.startPosition,
    required this.data,
    this.recordCount,
  });

  final bool endOfFile;
  final bool isStream;
  final int startPosition;

  /// For stream: single Uint8List. For record: list of Uint8List.
  final List<Uint8List> data;
  final int? recordCount;
}

/// Decode an AtomicReadFile-ACK payload (after APDU header).
AtomicReadFileAck? decodeAtomicReadFileAck(Uint8List data) {
  var offset = 0;

  // endOfFile (application boolean)
  final boolTag = decodeTag(data, offset);
  if (boolTag == null) return null;
  // Boolean value is encoded in the length/value field for 1-byte booleans
  final endOfFile = boolTag.valueLength > 0
      ? data[boolTag.valueOffset] != 0
      : false;
  offset = boolTag.valueOffset + boolTag.valueLength;

  // Access method choice
  final choiceTag = decodeTag(data, offset);
  if (choiceTag == null) return null;

  if (choiceTag.isOpening && choiceTag.tagNumber == 0) {
    // Stream access
    offset = choiceTag.valueOffset;

    // fileStartPosition (application signed)
    final posTag = decodeTag(data, offset);
    if (posTag == null) return null;
    offset = posTag.valueOffset;
    final startPos = decodeSignedValue(data, offset, posTag.valueLength);
    offset += posTag.valueLength;

    // fileData (application octet string)
    final dataTag = decodeTag(data, offset);
    if (dataTag == null) return null;
    offset = dataTag.valueOffset;
    final fileData = Uint8List.sublistView(
        data, offset, offset + dataTag.valueLength);
    offset += dataTag.valueLength;

    // closing tag 0
    final closeTag = decodeTag(data, offset);
    if (closeTag != null) offset = closeTag.valueOffset;

    return AtomicReadFileAck(
      endOfFile: endOfFile,
      isStream: true,
      startPosition: startPos,
      data: [Uint8List.fromList(fileData)],
    );
  } else if (choiceTag.isOpening && choiceTag.tagNumber == 1) {
    // Record access
    offset = choiceTag.valueOffset;

    // fileStartRecord (application signed)
    final posTag = decodeTag(data, offset);
    if (posTag == null) return null;
    offset = posTag.valueOffset;
    final startRecord = decodeSignedValue(data, offset, posTag.valueLength);
    offset += posTag.valueLength;

    // returnedRecordCount (application unsigned)
    final countTag = decodeTag(data, offset);
    if (countTag == null) return null;
    offset = countTag.valueOffset;
    final recordCount = decodeUnsignedValue(data, offset, countTag.valueLength);
    offset += countTag.valueLength;

    // SEQUENCE OF OCTET STRING
    final records = <Uint8List>[];
    for (var i = 0; i < recordCount; i++) {
      final recTag = decodeTag(data, offset);
      if (recTag == null) break;
      offset = recTag.valueOffset;
      records.add(Uint8List.fromList(
          Uint8List.sublistView(data, offset, offset + recTag.valueLength)));
      offset += recTag.valueLength;
    }

    // closing tag 1
    final closeTag = decodeTag(data, offset);
    if (closeTag != null) offset = closeTag.valueOffset;

    return AtomicReadFileAck(
      endOfFile: endOfFile,
      isStream: false,
      startPosition: startRecord,
      data: records,
      recordCount: recordCount,
    );
  }

  return null;
}

// ---------------------------------------------------------------------------
// AtomicWriteFile
// ---------------------------------------------------------------------------

/// Encode an AtomicWriteFile confirmed request APDU.
///
/// [isStream] selects stream access (byte offset) vs record access.
/// For stream: [startPosition] is the byte offset, [fileData] should have 1 entry.
/// For record: [startPosition] is the record number, [fileData] is the list of records.
Uint8List encodeAtomicWriteFile({
  required int invokeId,
  required int objectInstance,
  required int startPosition,
  required List<Uint8List> fileData,
  bool isStream = true,
}) {
  final buf = BytesBuilder();

  // APDU header
  buf.addByte(ApduType.confirmedRequest);
  buf.addByte(0x75);
  buf.addByte(invokeId);
  buf.addByte(ConfirmedService.atomicWriteFile);

  // Application-tagged object identifier (type=10 = file)
  buf.add(encodeApplicationObjectId(10, objectInstance));

  if (isStream) {
    // Stream access [0]
    buf.add(encodeOpeningTag(0));
    buf.add(encodeApplicationSigned(startPosition));
    buf.add(encodeApplicationOctetString(
        fileData.isNotEmpty ? fileData[0] : Uint8List(0)));
    buf.add(encodeClosingTag(0));
  } else {
    // Record access [1]
    buf.add(encodeOpeningTag(1));
    buf.add(encodeApplicationSigned(startPosition));
    buf.add(encodeApplicationUnsigned(fileData.length));
    for (final record in fileData) {
      buf.add(encodeApplicationOctetString(record));
    }
    buf.add(encodeClosingTag(1));
  }

  return buf.toBytes();
}

/// Decoded AtomicWriteFile-ACK.
class AtomicWriteFileAck {
  const AtomicWriteFileAck({
    required this.isStream,
    required this.startPosition,
  });

  final bool isStream;
  final int startPosition;
}

/// Decode an AtomicWriteFile-ACK payload (after APDU header).
///
/// The ACK is just a CHOICE:
///   [0] file-start-position INTEGER  (stream)
///   [1] file-start-record INTEGER    (record)
AtomicWriteFileAck? decodeAtomicWriteFileAck(Uint8List data) {
  if (data.isEmpty) return null;
  var offset = 0;

  final tag = decodeTag(data, offset);
  if (tag == null || !tag.isContext) return null;
  offset = tag.valueOffset;
  final pos = decodeSignedValue(data, offset, tag.valueLength);

  return AtomicWriteFileAck(
    isStream: tag.tagNumber == 0,
    startPosition: pos,
  );
}

// ---------------------------------------------------------------------------
// ReadPropertyMultiple
// ---------------------------------------------------------------------------

/// A single property reference for an RPM request.
class RpmPropertyRef {
  const RpmPropertyRef(this.propertyId, [this.arrayIndex = -1]);
  final int propertyId;
  final int arrayIndex;
}

/// A single object + property list for an RPM request.
class RpmReadAccessSpec {
  const RpmReadAccessSpec({
    required this.objectType,
    required this.objectInstance,
    required this.properties,
  });
  final int objectType;
  final int objectInstance;
  final List<RpmPropertyRef> properties;
}

/// Encode a ReadPropertyMultiple confirmed request APDU.
Uint8List encodeReadPropertyMultiple({
  required int invokeId,
  required List<RpmReadAccessSpec> specs,
}) {
  final buf = BytesBuilder();

  // APDU header
  buf.addByte(ApduType.confirmedRequest);
  buf.addByte(0x75); // max-apdu=1476
  buf.addByte(invokeId);
  buf.addByte(ConfirmedService.readPropertyMultiple);

  for (final spec in specs) {
    // Context 0: object identifier
    buf.add(encodeContextObjectId(0, spec.objectType, spec.objectInstance));

    // Opening tag 1: list of property references
    buf.addByte(0x1E);
    for (final prop in spec.properties) {
      // Context 0: property identifier
      buf.add(encodeContextUnsigned(0, prop.propertyId));
      // Context 1: array index (optional)
      if (prop.arrayIndex >= 0) {
        buf.add(encodeContextUnsigned(1, prop.arrayIndex));
      }
    }
    // Closing tag 1
    buf.addByte(0x1F);
  }

  return buf.toBytes();
}

/// One property result from an RPM ACK — either a value or an error.
class RpmPropertyResult {
  const RpmPropertyResult({
    required this.propertyId,
    this.arrayIndex,
    this.value,
    this.errorClass,
    this.errorCode,
  });

  final int propertyId;
  final int? arrayIndex;

  /// Non-null when the device returned a value.
  final dynamic value;

  /// Non-null when the device returned a per-property error.
  final int? errorClass;
  final int? errorCode;

  bool get isError => errorClass != null;
}

/// One object's results from an RPM ACK.
class RpmObjectResult {
  const RpmObjectResult({
    required this.objectType,
    required this.objectInstance,
    required this.properties,
  });
  final int objectType;
  final int objectInstance;
  final List<RpmPropertyResult> properties;
}

/// Decode a ReadPropertyMultiple-ACK complex-ACK payload (after APDU header).
List<RpmObjectResult>? decodeReadPropertyMultipleAck(Uint8List data) {
  final results = <RpmObjectResult>[];
  var offset = 0;

  while (offset < data.length) {
    // Context 0: object identifier
    final objIdTag = decodeTag(data, offset);
    if (objIdTag == null || objIdTag.tagNumber != 0 || !objIdTag.isContext) {
      break;
    }
    offset = objIdTag.valueOffset;
    final objectId = decodeObjectId(data, offset);
    offset += objIdTag.valueLength;

    // Opening tag 1: list of results
    final openTag1 = decodeTag(data, offset);
    if (openTag1 == null || !openTag1.isOpening || openTag1.tagNumber != 1) {
      break;
    }
    offset = openTag1.valueOffset;

    final propResults = <RpmPropertyResult>[];

    // Decode properties until closing tag 1
    while (offset < data.length) {
      final nextTag = decodeTag(data, offset);
      if (nextTag == null) break;

      // Closing tag 1 — end of this object's results
      if (nextTag.isClosing && nextTag.tagNumber == 1) {
        offset = nextTag.valueOffset;
        break;
      }

      // Context 2: property identifier
      if (nextTag.tagNumber != 2 || !nextTag.isContext) break;
      offset = nextTag.valueOffset;
      final propertyId = decodeUnsignedValue(data, offset, nextTag.valueLength);
      offset += nextTag.valueLength;

      // Optional context 3: array index
      int? arrayIndex;
      final maybeIdx = decodeTag(data, offset);
      if (maybeIdx != null &&
          maybeIdx.isContext &&
          !maybeIdx.isOpening &&
          maybeIdx.tagNumber == 3) {
        offset = maybeIdx.valueOffset;
        arrayIndex = decodeUnsignedValue(data, offset, maybeIdx.valueLength);
        offset += maybeIdx.valueLength;
      }

      final choiceTag = decodeTag(data, offset);
      if (choiceTag == null) break;

      if (choiceTag.isOpening && choiceTag.tagNumber == 4) {
        // --- Property value ---
        offset = choiceTag.valueOffset;

        // Find closing tag 4 and extract value bytes
        final valueStart = offset;
        var depth = 1;
        while (offset < data.length && depth > 0) {
          final t = decodeTag(data, offset);
          if (t == null) break;
          if (t.isClosing && t.tagNumber == 4) {
            depth--;
            if (depth == 0) {
              break;
            }
          }
          if (t.isOpening && t.tagNumber == 4) depth++;
          offset = t.valueOffset + t.valueLength;
        }
        final valueEnd = offset;

        dynamic value;
        if (valueEnd > valueStart) {
          final valueData =
              Uint8List.sublistView(data, valueStart, valueEnd);
          value = decodeApplicationValue(valueData);
        }

        // Skip past closing tag 4
        final closeTag4 = decodeTag(data, offset);
        if (closeTag4 != null) offset = closeTag4.valueOffset;

        propResults.add(RpmPropertyResult(
          propertyId: propertyId,
          arrayIndex: arrayIndex,
          value: value,
        ));
      } else if (choiceTag.isOpening && choiceTag.tagNumber == 5) {
        // --- Property access error ---
        offset = choiceTag.valueOffset;

        // Error class (application enumerated)
        final classTag = decodeTag(data, offset);
        int errClass = -1;
        if (classTag != null) {
          offset = classTag.valueOffset;
          errClass =
              decodeUnsignedValue(data, offset, classTag.valueLength);
          offset += classTag.valueLength;
        }

        // Error code (application enumerated)
        final codeTag = decodeTag(data, offset);
        int errCode = -1;
        if (codeTag != null) {
          offset = codeTag.valueOffset;
          errCode =
              decodeUnsignedValue(data, offset, codeTag.valueLength);
          offset += codeTag.valueLength;
        }

        // Skip past closing tag 5
        final closeTag5 = decodeTag(data, offset);
        if (closeTag5 != null) offset = closeTag5.valueOffset;

        propResults.add(RpmPropertyResult(
          propertyId: propertyId,
          arrayIndex: arrayIndex,
          errorClass: errClass,
          errorCode: errCode,
        ));
      } else {
        // Unexpected — skip ahead
        break;
      }
    }

    results.add(RpmObjectResult(
      objectType: objectId.type,
      objectInstance: objectId.instance,
      properties: propResults,
    ));
  }

  return results.isEmpty ? null : results;
}

// ---------------------------------------------------------------------------
// Error response decoding
// ---------------------------------------------------------------------------

/// Parsed BACnet error.
class BacnetErrorData {
  const BacnetErrorData({required this.errorClass, required this.errorCode});
  final int errorClass;
  final int errorCode;

  @override
  String toString() => 'BACnet error (class: $errorClass, code: $errorCode)';
}

/// Decode a BACnet error PDU payload (after APDU header).
BacnetErrorData? decodeBacnetError(Uint8List data) {
  if (data.length < 4) return null;
  var offset = 0;

  final classTag = decodeTag(data, offset);
  if (classTag == null) return null;
  offset = classTag.valueOffset;
  final errorClass = decodeUnsignedValue(data, offset, classTag.valueLength);
  offset += classTag.valueLength;

  final codeTag = decodeTag(data, offset);
  if (codeTag == null) return null;
  offset = codeTag.valueOffset;
  final errorCode = decodeUnsignedValue(data, offset, codeTag.valueLength);

  return BacnetErrorData(errorClass: errorClass, errorCode: errorCode);
}
