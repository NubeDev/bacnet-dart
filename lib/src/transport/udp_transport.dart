/// UDP transport layer for BACnet/IP.
///
/// Uses `dart:io` [RawDatagramSocket] — works on Android, iOS, macOS,
/// Linux, and Windows with zero native code.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../codec/bvlc.dart';

/// A received BACnet/IP datagram.
class BacnetDatagram {
  const BacnetDatagram({
    required this.data,
    required this.sourceAddress,
    required this.sourcePort,
  });

  /// Raw NPDU bytes (BVLC header already stripped).
  final Uint8List data;
  final InternetAddress sourceAddress;
  final int sourcePort;
}

/// Low-level UDP transport for sending/receiving BACnet/IP frames.
class UdpTransport {
  RawDatagramSocket? _socket;
  final _controller = StreamController<BacnetDatagram>.broadcast();
  bool _closed = false;

  /// Stream of received BACnet datagrams (BVLC stripped).
  Stream<BacnetDatagram> get datagrams => _controller.stream;

  /// Whether the transport is currently bound.
  bool get isBound => _socket != null && !_closed;

  /// Bind to a network interface for BACnet/IP communication.
  ///
  /// [address] — bind address (use `InternetAddress.anyIPv4` for all interfaces).
  /// [port] — BACnet/IP port, default 47808 (0xBAC0).
  Future<void> bind({
    InternetAddress? address,
    int port = 47808,
  }) async {
    if (_socket != null) {
      throw StateError('Transport already bound');
    }

    final bindAddress = address ?? InternetAddress.anyIPv4;
    _socket = await RawDatagramSocket.bind(bindAddress, port, reuseAddress: true);
    _socket!.broadcastEnabled = true;
    _socket!.readEventsEnabled = true;

    _socket!.listen(
      (event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            _handleDatagram(datagram);
          }
        }
      },
      onError: (Object error) {
        if (!_closed) {
          _controller.addError(error);
        }
      },
      onDone: () {
        if (!_closed) {
          close();
        }
      },
    );
  }

  void _handleDatagram(Datagram datagram) {
    final data = Uint8List.fromList(datagram.data);
    final header = decodeBvlcHeader(data);
    if (header == null) return; // Not a valid BVLC frame

    final npdu = extractNpdu(data, header);
    _controller.add(BacnetDatagram(
      data: npdu,
      sourceAddress: datagram.address,
      sourcePort: datagram.port,
    ));
  }

  /// Send a raw NPDU wrapped in a BVLC unicast frame to a specific host.
  void sendUnicast(InternetAddress address, int port, Uint8List npdu) {
    _ensureBound();
    final frame = encodeBvlc(BvlcFunction.originalUnicastNpdu, npdu);
    _socket!.send(frame, address, port);
  }

  /// Send a raw NPDU wrapped in a BVLC broadcast frame.
  void sendBroadcast(int port, Uint8List npdu) {
    _ensureBound();
    final frame = encodeBvlc(BvlcFunction.originalBroadcastNpdu, npdu);
    final broadcastAddr = InternetAddress('255.255.255.255');
    _socket!.send(frame, broadcastAddr, port);
  }

  /// Close the transport and release the UDP socket.
  void close() {
    _closed = true;
    _socket?.close();
    _socket = null;
    _controller.close();
  }

  void _ensureBound() {
    if (_socket == null || _closed) {
      throw StateError('Transport not bound — call bind() first');
    }
  }
}
