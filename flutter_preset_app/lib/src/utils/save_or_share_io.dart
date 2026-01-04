import 'dart:io' show File;
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> outputPngBytesImpl(Uint8List bytes) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/output.png');
  await file.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles([XFile(file.path)], mimeTypes: ['image/png']);
}

