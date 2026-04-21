/// BACnet Network Protocol Data Unit (NPDU) layer.
///
/// NPDU sits between BVLC and APDU. For simple BACnet/IP without routing,
/// the NPDU header is typically 2 bytes:
///   [0] version    — always 0x01
///   [1] control    — bit flags for DNET/SNET/reply/priority
import 'dart:typed_data';

/// NPDU control byte bit masks.
abstract final class NpduControl {
  /// Bit 7: message is a network-layer message (1) or application (0).
  static const int networkLayerMessage = 0x80;

  /// Bit 5: destination specifier present.
  static const int destinationPresent = 0x20;

  /// Bit 3: source specifier present.
  static const int sourcePresent = 0x08;

  /// Bit 2: expecting reply.
  static const int expectingReply = 0x04;

  /// Bits 0-1: priority (0 = normal, 1 = urgent, 2 = critical, 3 = life safety).
  static const int priorityMask = 0x03;
}

/// Parsed NPDU header.
class NpduHeader {
  const NpduHeader({
    required this.version,
    required this.control,
    this.destNetwork,
    this.destAddress,
    this.srcNetwork,
    this.srcAddress,
    this.hopCount,
    required this.headerLength,
  });

  final int version;
  final int control;
  final int? destNetwork;
  final Uint8List? destAddress;
  final int? srcNetwork;
  final Uint8List? srcAddress;
  final int? hopCount;

  /// Total bytes consumed by this NPDU header.
  final int headerLength;

  bool get isNetworkLayerMessage =>
      (control & NpduControl.networkLayerMessage) != 0;

  bool get expectingReply => (control & NpduControl.expectingReply) != 0;

  static const int protocolVersion = 0x01;
}

/// Encode a simple NPDU header for a BACnet/IP application message.
///
/// For broadcast (Who-Is) set [expectingReply] to false.
/// For confirmed requests (ReadProperty) set [expectingReply] to true.
Uint8List encodeNpdu({bool expectingReply = false}) {
  final control = expectingReply ? NpduControl.expectingReply : 0;
  return Uint8List.fromList([NpduHeader.protocolVersion, control]);
}

/// Encode NPDU with broadcast destination (global broadcast).
Uint8List encodeNpduBroadcast() {
  // For global broadcast: DNET=0xFFFF, DLEN=0, hop count=255
  return Uint8List.fromList([
    NpduHeader.protocolVersion,
    NpduControl.destinationPresent, // no expecting reply for broadcast
    0xFF, 0xFF, // DNET = 65535 (global broadcast)
    0x00, // DLEN = 0
    0xFF, // hop count = 255
  ]);
}

/// Decode an NPDU header from raw bytes.
NpduHeader? decodeNpduHeader(Uint8List data) {
  if (data.length < 2) return null;

  final version = data[0];
  if (version != NpduHeader.protocolVersion) return null;

  final control = data[1];
  var offset = 2;

  int? destNetwork;
  Uint8List? destAddress;
  int? srcNetwork;
  Uint8List? srcAddress;
  int? hopCount;

  // Destination specifier
  if ((control & NpduControl.destinationPresent) != 0) {
    if (data.length < offset + 3) return null;
    destNetwork = (data[offset] << 8) | data[offset + 1];
    offset += 2;
    final dlen = data[offset];
    offset += 1;
    if (dlen > 0) {
      if (data.length < offset + dlen) return null;
      destAddress = Uint8List.sublistView(data, offset, offset + dlen);
      offset += dlen;
    }
  }

  // Source specifier
  if ((control & NpduControl.sourcePresent) != 0) {
    if (data.length < offset + 3) return null;
    srcNetwork = (data[offset] << 8) | data[offset + 1];
    offset += 2;
    final slen = data[offset];
    offset += 1;
    if (slen > 0) {
      if (data.length < offset + slen) return null;
      srcAddress = Uint8List.sublistView(data, offset, offset + slen);
      offset += slen;
    }
  }

  // Hop count (only present when destination is present)
  if ((control & NpduControl.destinationPresent) != 0) {
    if (data.length < offset + 1) return null;
    hopCount = data[offset];
    offset += 1;
  }

  return NpduHeader(
    version: version,
    control: control,
    destNetwork: destNetwork,
    destAddress: destAddress,
    srcNetwork: srcNetwork,
    srcAddress: srcAddress,
    hopCount: hopCount,
    headerLength: offset,
  );
}

/// Extract the APDU from an NPDU frame (bytes after the NPDU header).
Uint8List extractApdu(Uint8List npduData, NpduHeader header) {
  return Uint8List.sublistView(npduData, header.headerLength);
}
