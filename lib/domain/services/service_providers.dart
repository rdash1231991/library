import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_service.dart';
import 'share_image_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.singleton();
});

final shareImageServiceProvider = Provider<ShareImageService>((ref) {
  return const ShareImageService();
});

