/// BACnet ASN.1 tag encoding/decoding utilities.
///
/// BACnet uses a TLV (Tag-Length-Value) encoding defined in clause 20.
/// Tags can be application-level (type indicated by tag number) or
/// context-specific (meaning depends on position in the PDU).
import 'dart:convert';
import 'dart:typed_data';

// ---------------------------------------------------------------------------
// Application tag numbers
// ---------------------------------------------------------------------------

abstract final class AppTag {
  static const int null_ = 0;
  static const int boolean = 1;
  static const int unsigned = 2;
  static const int signed = 3;
  static const int real = 4;
  static const int double_ = 5;
  static const int octetString = 6;
  static const int characterString = 7;
  static const int bitString = 8;
  static const int enumerated = 9;
  static const int date = 10;
  static const int time = 11;
  static const int objectIdentifier = 12;
}

// ---------------------------------------------------------------------------
// Tag decoding
// ---------------------------------------------------------------------------

/// A parsed BACnet tag.
class BacnetTag {
  const BacnetTag({
    required this.tagNumber,
    required this.isContext,
    required this.isOpening,
    required this.isClosing,
    required this.valueLength,
    required this.valueOffset,
  });

  /// Tag number (0-254).
  final int tagNumber;

  /// True if context-specific, false if application.
  final bool isContext;

  /// True if this is an opening tag.
  final bool isOpening;

  /// True if this is a closing tag.
  final bool isClosing;

  /// Length of the value portion in bytes.
  final int valueLength;

  /// Byte offset where the value begins.
  final int valueOffset;
}

/// Decode a tag at [offset] in [data].
BacnetTag? decodeTag(Uint8List data, int offset) {
  if (offset >= data.length) return null;

  final byte0 = data[offset];
  var tagNumber = (byte0 >> 4) & 0x0F;
  final isContext = (byte0 & 0x08) != 0;
  final lvt = byte0 & 0x07;

  // Check for opening/closing tags (context class, LVT = 6 or 7)
  if (isContext && lvt == 6) {
    // Opening tag
    var actualTag = tagNumber;
    var off = offset + 1;
    if (tagNumber == 0x0F) {
      if (off >= data.length) return null;
      actualTag = data[off];
      off += 1;
    }
    return BacnetTag(
      tagNumber: actualTag,
      isContext: true,
      isOpening: true,
      isClosing: false,
      valueLength: 0,
      valueOffset: off,
    );
  }
  if (isContext && lvt == 7) {
    // Closing tag
    var actualTag = tagNumber;
    var off = offset + 1;
    if (tagNumber == 0x0F) {
      if (off >= data.length) return null;
      actualTag = data[off];
      off += 1;
    }
    return BacnetTag(
      tagNumber: actualTag,
      isContext: true,
      isOpening: false,
      isClosing: true,
      valueLength: 0,
      valueOffset: off,
    );
  }

  // Extended tag number
  var headerSize = 1;
  if (tagNumber == 0x0F) {
    if (offset + 1 >= data.length) return null;
    tagNumber = data[offset + 1];
    headerSize = 2;
  }

  // Value length
  int valueLength;
  if (lvt < 5) {
    valueLength = lvt;
  } else if (lvt == 5) {
    // Extended length
    if (offset + headerSize >= data.length) return null;
    final extLen = data[offset + headerSize];
    headerSize += 1;
    if (extLen < 254) {
      valueLength = extLen;
    } else if (extLen == 254) {
      // 16-bit length
      if (offset + headerSize + 1 >= data.length) return null;
      valueLength = (data[offset + headerSize] << 8) |
          data[offset + headerSize + 1];
      headerSize += 2;
    } else {
      // 32-bit length
      if (offset + headerSize + 3 >= data.length) return null;
      valueLength = (data[offset + headerSize] << 24) |
          (data[offset + headerSize + 1] << 16) |
          (data[offset + headerSize + 2] << 8) |
          data[offset + headerSize + 3];
      headerSize += 4;
    }
  } else {
    valueLength = 0;
  }

  return BacnetTag(
    tagNumber: tagNumber,
    isContext: isContext,
    isOpening: false,
    isClosing: false,
    valueLength: valueLength,
    valueOffset: offset + headerSize,
  );
}

// ---------------------------------------------------------------------------
// Value decoding
// ---------------------------------------------------------------------------

/// Decode an unsigned integer from [length] bytes at [offset].
int decodeUnsignedValue(Uint8List data, int offset, int length) {
  var value = 0;
  for (var i = 0; i < length; i++) {
    value = (value << 8) | data[offset + i];
  }
  return value;
}

/// Decode a signed integer from [length] bytes at [offset].
int decodeSignedValue(Uint8List data, int offset, int length) {
  if (length == 0) return 0;
  var value = data[offset];
  // Sign extend
  if (value & 0x80 != 0) {
    value = value - 256;
  }
  for (var i = 1; i < length; i++) {
    value = (value << 8) | data[offset + i];
  }
  return value;
}

/// Decode a 32-bit IEEE 754 float.
double decodeRealValue(Uint8List data, int offset) {
  final bd = ByteData.sublistView(data, offset, offset + 4);
  return bd.getFloat32(0, Endian.big);
}

/// Decode a 64-bit IEEE 754 double.
double decodeDoubleValue(Uint8List data, int offset) {
  final bd = ByteData.sublistView(data, offset, offset + 8);
  return bd.getFloat64(0, Endian.big);
}

/// Decoded BACnet object identifier.
class ObjectId {
  const ObjectId({required this.type, required this.instance});
  final int type;
  final int instance;

  @override
  String toString() => 'ObjectId(type: $type, instance: $instance)';
}

/// Decode a 4-byte BACnet Object Identifier.
ObjectId decodeObjectId(Uint8List data, int offset) {
  final raw = (data[offset] << 24) |
      (data[offset + 1] << 16) |
      (data[offset + 2] << 8) |
      data[offset + 3];
  return ObjectId(
    type: (raw >> 22) & 0x3FF,
    instance: raw & 0x3FFFFF,
  );
}

/// Decode an application-tagged value. Returns a Dart-native type.
///
/// For values inside constructed context tags (e.g. property-value),
/// this reads the first application tag and returns its value.
dynamic decodeApplicationValue(Uint8List data) {
  if (data.isEmpty) return null;

  final tag = decodeTag(data, 0);
  if (tag == null) return null;

  // If this is a context tag, try to extract values inside it
  if (tag.isContext && !tag.isOpening && !tag.isClosing) {
    // Primitive context tag — treat as unsigned
    return decodeUnsignedValue(data, tag.valueOffset, tag.valueLength);
  }

  // Check if there are multiple values (e.g. object list)
  // Try to parse all values and return a list if multiple exist
  final values = <dynamic>[];
  var offset = 0;
  while (offset < data.length) {
    final t = decodeTag(data, offset);
    if (t == null || t.isClosing) break;

    if (t.isOpening) {
      // Skip constructed values for now
      offset = t.valueOffset;
      continue;
    }

    final v = _decodeSingleValue(data, t);
    values.add(v);
    offset = t.valueOffset + t.valueLength;
  }

  if (values.isEmpty) return null;
  if (values.length == 1) return values.first;
  return values;
}

dynamic _decodeSingleValue(Uint8List data, BacnetTag tag) {
  if (tag.isContext) {
    return decodeUnsignedValue(data, tag.valueOffset, tag.valueLength);
  }

  switch (tag.tagNumber) {
    case AppTag.null_:
      return null;
    case AppTag.boolean:
      return tag.valueLength > 0
          ? data[tag.valueOffset] != 0
          : (tag.valueLength == 1);
    case AppTag.unsigned:
      return decodeUnsignedValue(data, tag.valueOffset, tag.valueLength);
    case AppTag.signed:
      return decodeSignedValue(data, tag.valueOffset, tag.valueLength);
    case AppTag.real:
      if (tag.valueLength >= 4) {
        return decodeRealValue(data, tag.valueOffset);
      }
      return 0.0;
    case AppTag.double_:
      if (tag.valueLength >= 8) {
        return decodeDoubleValue(data, tag.valueOffset);
      }
      return 0.0;
    case AppTag.octetString:
      return Uint8List.sublistView(
          data, tag.valueOffset, tag.valueOffset + tag.valueLength);
    case AppTag.characterString:
      if (tag.valueLength < 1) return '';
      final encoding = data[tag.valueOffset]; // 0 = UTF-8
      if (encoding == 0) {
        return utf8.decode(data.sublist(
            tag.valueOffset + 1, tag.valueOffset + tag.valueLength),
            allowMalformed: true);
      }
      // Fallback: try UTF-8
      return utf8.decode(data.sublist(
          tag.valueOffset + 1, tag.valueOffset + tag.valueLength),
          allowMalformed: true);
    case AppTag.enumerated:
      return decodeUnsignedValue(data, tag.valueOffset, tag.valueLength);
    case AppTag.objectIdentifier:
      if (tag.valueLength >= 4) {
        return decodeObjectId(data, tag.valueOffset);
      }
      return null;
    case AppTag.bitString:
    case AppTag.date:
    case AppTag.time:
      // Return raw bytes for these types
      return Uint8List.sublistView(
          data, tag.valueOffset, tag.valueOffset + tag.valueLength);
    default:
      return Uint8List.sublistView(
          data, tag.valueOffset, tag.valueOffset + tag.valueLength);
  }
}

// ---------------------------------------------------------------------------
// Value encoding
// ---------------------------------------------------------------------------

/// Encode a context-tagged unsigned integer.
Uint8List encodeContextUnsigned(int tagNumber, int value) {
  final valueBytes = _encodeUnsignedBytes(value);
  return _encodeTag(tagNumber, true, valueBytes);
}

/// Encode a context-tagged signed integer.
Uint8List encodeContextSigned(int tagNumber, int value) {
  final valueBytes = _encodeSignedBytes(value);
  return _encodeTag(tagNumber, true, valueBytes);
}

/// Encode an application-tagged object identifier.
Uint8List encodeApplicationObjectId(int objectType, int instance) {
  final raw = ((objectType & 0x3FF) << 22) | (instance & 0x3FFFFF);
  final valueBytes = Uint8List(4);
  valueBytes[0] = (raw >> 24) & 0xFF;
  valueBytes[1] = (raw >> 16) & 0xFF;
  valueBytes[2] = (raw >> 8) & 0xFF;
  valueBytes[3] = raw & 0xFF;
  return _encodeTag(AppTag.objectIdentifier, false, valueBytes);
}

/// Encode an application-tagged signed integer.
Uint8List encodeApplicationSigned(int value) {
  return _encodeTag(AppTag.signed, false, _encodeSignedBytes(value));
}

/// Encode an application-tagged unsigned integer.
Uint8List encodeApplicationUnsigned(int value) {
  return _encodeTag(AppTag.unsigned, false, _encodeUnsignedBytes(value));
}

/// Encode an application-tagged boolean.
Uint8List encodeApplicationBoolean(bool value) {
  return Uint8List.fromList([(AppTag.boolean << 4) | (value ? 1 : 0)]);
}

/// Encode an application-tagged octet string.
Uint8List encodeApplicationOctetString(Uint8List data) {
  return _encodeTag(AppTag.octetString, false, data);
}

/// Encode an opening tag for the given context tag number.
Uint8List encodeOpeningTag(int tagNumber) {
  if (tagNumber < 15) {
    return Uint8List.fromList([(tagNumber << 4) | 0x0E]); // class=1, lvt=6
  }
  return Uint8List.fromList([0xFE, tagNumber]);
}

/// Encode a closing tag for the given context tag number.
Uint8List encodeClosingTag(int tagNumber) {
  if (tagNumber < 15) {
    return Uint8List.fromList([(tagNumber << 4) | 0x0F]); // class=1, lvt=7
  }
  return Uint8List.fromList([0xFF, tagNumber]);
}

/// Encode a context-tagged object identifier.
Uint8List encodeContextObjectId(int tagNumber, int objectType, int instance) {
  final raw = ((objectType & 0x3FF) << 22) | (instance & 0x3FFFFF);
  final valueBytes = Uint8List(4);
  valueBytes[0] = (raw >> 24) & 0xFF;
  valueBytes[1] = (raw >> 16) & 0xFF;
  valueBytes[2] = (raw >> 8) & 0xFF;
  valueBytes[3] = raw & 0xFF;
  return _encodeTag(tagNumber, true, valueBytes);
}

/// Encode an application-tagged value.
Uint8List encodeApplicationValue(dynamic value, int appTagHint) {
  if (value == null) {
    return _encodeTag(AppTag.null_, false, Uint8List(0));
  }

  if (value is bool) {
    return Uint8List.fromList([
      (AppTag.boolean << 4) | (value ? 1 : 0),
    ]);
  }

  if (value is int) {
    // When the caller says "this should be a REAL", encode as float even
    // though Dart sees an int.  Without this, writing 99 to an Analog Output
    // sends an unsigned-int tag and the device rejects it with
    // "inconsistent-parameters".
    if (appTagHint == AppTag.real) {
      return _encodeTag(
          AppTag.real, false, _encodeRealBytes(value.toDouble()));
    }
    if (appTagHint == AppTag.double_) {
      final bd = ByteData(8);
      bd.setFloat64(0, value.toDouble(), Endian.big);
      return _encodeTag(AppTag.double_, false, bd.buffer.asUint8List());
    }
    if (appTagHint == AppTag.enumerated) {
      return _encodeTag(AppTag.enumerated, false, _encodeUnsignedBytes(value));
    }
    if (value < 0) {
      return _encodeTag(AppTag.signed, false, _encodeSignedBytes(value));
    }
    return _encodeTag(AppTag.unsigned, false, _encodeUnsignedBytes(value));
  }

  if (value is double) {
    final bd = ByteData(4);
    bd.setFloat32(0, value, Endian.big);
    return _encodeTag(AppTag.real, false,
        Uint8List.sublistView(bd.buffer.asUint8List()));
  }

  if (value is String) {
    final strBytes = utf8.encode(value);
    final payload = Uint8List(1 + strBytes.length);
    payload[0] = 0; // UTF-8 encoding
    payload.setRange(1, payload.length, strBytes);
    return _encodeTag(AppTag.characterString, false, payload);
  }

  // Fallback: treat as unsigned
  if (value is num) {
    return _encodeTag(
        AppTag.real, false, _encodeRealBytes(value.toDouble()));
  }

  return Uint8List(0);
}

Uint8List _encodeUnsignedBytes(int value) {
  if (value < 0x100) return Uint8List.fromList([value & 0xFF]);
  if (value < 0x10000) {
    return Uint8List.fromList([(value >> 8) & 0xFF, value & 0xFF]);
  }
  if (value < 0x1000000) {
    return Uint8List.fromList([
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ]);
  }
  return Uint8List.fromList([
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ]);
}

Uint8List _encodeSignedBytes(int value) {
  if (value >= -128 && value < 128) {
    return Uint8List.fromList([value & 0xFF]);
  }
  if (value >= -32768 && value < 32768) {
    return Uint8List.fromList([(value >> 8) & 0xFF, value & 0xFF]);
  }
  return Uint8List.fromList([
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ]);
}

Uint8List _encodeRealBytes(double value) {
  final bd = ByteData(4);
  bd.setFloat32(0, value, Endian.big);
  return bd.buffer.asUint8List();
}

Uint8List _encodeTag(int tagNumber, bool isContext, Uint8List value) {
  final buf = BytesBuilder();
  final classFlag = isContext ? 0x08 : 0x00;

  if (tagNumber < 15) {
    if (value.length < 5) {
      buf.addByte((tagNumber << 4) | classFlag | value.length);
    } else {
      buf.addByte((tagNumber << 4) | classFlag | 5);
      if (value.length < 254) {
        buf.addByte(value.length);
      } else if (value.length < 65536) {
        buf.addByte(254);
        buf.addByte((value.length >> 8) & 0xFF);
        buf.addByte(value.length & 0xFF);
      } else {
        buf.addByte(255);
        buf.addByte((value.length >> 24) & 0xFF);
        buf.addByte((value.length >> 16) & 0xFF);
        buf.addByte((value.length >> 8) & 0xFF);
        buf.addByte(value.length & 0xFF);
      }
    }
  } else {
    if (value.length < 5) {
      buf.addByte(0xF0 | classFlag | value.length);
    } else {
      buf.addByte(0xF0 | classFlag | 5);
      if (value.length < 254) {
        buf.addByte(value.length);
      } else {
        buf.addByte(254);
        buf.addByte((value.length >> 8) & 0xFF);
        buf.addByte(value.length & 0xFF);
      }
    }
    buf.addByte(tagNumber);
  }

  buf.add(value);
  return buf.toBytes();
}
