/// Pure Dart BACnet/IP protocol stack.
///
/// No FFI, no native code — works on all platforms via `dart:io` UDP.
library;

// Client
export 'src/client/bacnet_client.dart';

// Constants
export 'src/constants/error_codes.dart';
export 'src/constants/object_types.dart';
export 'src/constants/property_ids.dart';

// Models
export 'src/models/bacnet_object.dart';
export 'src/models/events.dart';

// Codec (for advanced use / testing)
export 'src/codec/apdu.dart'
    show
        AtomicReadFileAck,
        AtomicWriteFileAck,
        FileAccessMethod,
        RpmReadAccessSpec,
        RpmPropertyRef,
        RpmObjectResult,
        RpmPropertyResult;
export 'src/codec/tag.dart' show ObjectId, AppTag;
