/// BACnet Virtual Link Control (BVLC) layer for BACnet/IP.
///
/// BVLC wraps every BACnet/IP packet sent over UDP. The header is 4 bytes:
///   [0] type       — always 0x81 for BACnet/IP
///   [1] function   — e.g. 0x0A = Original-Unicast-NPDU, 0x0B = Original-Broadcast-NPDU
///   [2-3] length   — total packet length including this header (big-endian)
import 'dart:typed_data';

/// BVLC function codes used for BACnet/IP.
abstract final class BvlcFunction {
  static const int result = 0x00;
  static const int writeBroadcastDistributionTable = 0x01;
  static const int readBroadcastDistributionTable = 0x02;
  static const int readBroadcastDistributionTableAck = 0x03;
  static const int forwardedNpdu = 0x04;
  static const int registerForeignDevice = 0x05;
  static const int readForeignDeviceTable = 0x06;
  static const int readForeignDeviceTableAck = 0x07;
  static const int deleteForeignDeviceTableEntry = 0x08;
  static const int distributeBroadcastToNetwork = 0x09;
  static const int originalUnicastNpdu = 0x0A;
  static const int originalBroadcastNpdu = 0x0B;
}

/// Parsed BVLC header.
class BvlcHeader {
  const BvlcHeader({
    required this.function_,
    required this.length,
  });

  final int function_;
  final int length;

  static const int headerSize = 4;
  static const int bvlcType = 0x81;
}

/// Encode a BVLC frame around an NPDU payload.
Uint8List encodeBvlc(int function, Uint8List npdu) {
  final length = BvlcHeader.headerSize + npdu.length;
  final frame = Uint8List(length);
  frame[0] = BvlcHeader.bvlcType;
  frame[1] = function;
  frame[2] = (length >> 8) & 0xFF;
  frame[3] = length & 0xFF;
  frame.setRange(BvlcHeader.headerSize, length, npdu);
  return frame;
}

/// Decode a BVLC header from raw bytes. Returns null if invalid.
BvlcHeader? decodeBvlcHeader(Uint8List data) {
  if (data.length < BvlcHeader.headerSize) return null;
  if (data[0] != BvlcHeader.bvlcType) return null;
  final length = (data[2] << 8) | data[3];
  return BvlcHeader(function_: data[1], length: length);
}

/// Extract the NPDU portion from a BVLC frame.
/// For forwarded-NPDU (0x04), skip the 6-byte originating address.
Uint8List extractNpdu(Uint8List frame, BvlcHeader header) {
  var offset = BvlcHeader.headerSize;
  if (header.function_ == BvlcFunction.forwardedNpdu) {
    offset += 6; // 4 bytes IP + 2 bytes port
  }
  return Uint8List.sublistView(frame, offset);
}
