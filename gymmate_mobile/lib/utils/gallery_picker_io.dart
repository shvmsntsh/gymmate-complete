import 'package:flutter/services.dart';

Future<String?> pickGalleryImageImpl() async {
  try {
    const channel = MethodChannel('com.gymmate/gallery_picker');
    final result = await channel.invokeMethod<String>('pickGalleryImage');
    return result;
  } on PlatformException {
    return null;
  }
}
