import 'dart:typed_data';

// Conditional import:
// - Web uses dart:html to download
// - Other platforms write temp file and share
import 'save_or_share_io.dart'
    if (dart.library.html) 'save_or_share_web.dart';

abstract class SaveOrShareImpl {
  static Future<void> outputPngBytes(Uint8List bytes) =>
      outputPngBytesImpl(bytes);
}

