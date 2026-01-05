import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' show XFile;

class ShareImageService {
  const ShareImageService();

  Future<XFile> capturePng({
    required GlobalKey repaintBoundaryKey,
    required int targetWidthPx,
    required int targetHeightPx,
    required String fileBaseName,
  }) async {
    final boundary =
        repaintBoundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

    final logicalSize = boundary.size;
    final pixelRatio = targetWidthPx / logicalSize.width;

    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List pngBytes = byteData!.buffer.asUint8List();

    final dir = await getTemporaryDirectory();
    final filePath = p.join(dir.path, '$fileBaseName.png');
    await File(filePath).writeAsBytes(pngBytes);
    return XFile(filePath, mimeType: 'image/png', name: '$fileBaseName.png');
  }
}

