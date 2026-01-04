import 'package:image_picker/image_picker.dart';

class PickedImage {
  PickedImage({required this.bytes, required this.filename});

  final List<int> bytes;
  final String filename;
}

class ImagePickerUtils {
  static final ImagePicker _picker = ImagePicker();

  static Future<PickedImage?> pickFromGallery() async {
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    final filename = x.name.isNotEmpty ? x.name : 'image.jpg';
    return PickedImage(bytes: bytes, filename: filename);
  }
}

