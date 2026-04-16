import 'gallery_picker_stub.dart'
    if (dart.library.html) 'gallery_picker_web.dart'
    if (dart.library.io) 'gallery_picker_io.dart'
    as impl;

Future<String?> pickGalleryImage() {
  return impl.pickGalleryImageImpl();
}
