import 'dart:typed_data';

import 'save_or_share_impl.dart';

class SaveOrShare {
  static Future<void> outputPngBytes(Uint8List bytes) =>
      SaveOrShareImpl.outputPngBytes(bytes);
}

