import 'dart:typed_data';

import 'package:bacnet_dart/src/codec/npdu.dart';
import 'package:test/test.dart';

void main() {
  group('encodeNpdu', () {
    test('a local request carries no destination specifier', () {
      expect(encodeNpdu(expectingReply: true), [0x01, 0x04]);
    });

    test('a routed request carries DNET, DADR and a hop count', () {
      final npdu = encodeNpdu(
        expectingReply: true,
        destNetwork: 2,
        destAddress: Uint8List.fromList([0x04]),
      );
      expect(npdu, [0x01, 0x24, 0x00, 0x02, 0x01, 0x04, 0xFF]);
      final header = decodeNpduHeader(npdu)!;
      expect(header.destNetwork, 2);
      expect(header.destAddress, [0x04]);
      expect(header.expectingReply, isTrue);
      expect(header.headerLength, npdu.length);
    });
  });

  test('a routed I-Am decodes its source network and MAC', () {
    // Captured from an MS/TP device answering through a BACnet/IP router:
    // global-broadcast destination, SNET 2, SADR 04.
    final npdu = Uint8List.fromList(
        [0x01, 0x28, 0xFF, 0xFF, 0x00, 0x00, 0x02, 0x01, 0x04, 0xFE, 0x10, 0x00]);
    final header = decodeNpduHeader(npdu)!;
    expect(header.srcNetwork, 2);
    expect(header.srcAddress, [0x04]);
    expect(header.headerLength, 10);
  });
}
