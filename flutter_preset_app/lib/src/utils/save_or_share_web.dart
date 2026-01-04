import 'dart:typed_data';
import 'dart:html' as html;

Future<void> outputPngBytesImpl(Uint8List bytes) async {
  final blob = html.Blob([bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final a = html.AnchorElement(href: url)
    ..download = 'output.png'
    ..style.display = 'none';
  html.document.body?.children.add(a);
  a.click();
  a.remove();
  html.Url.revokeObjectUrl(url);
}

