import 'logo_picker_stub.dart';
import 'logo_picker_stub.dart'
    if (dart.library.html) 'logo_picker_web.dart'
    if (dart.library.io) 'logo_picker_io.dart' as impl;

Future<PickedLogoFile?> pickLogoFile(List<String> allowedExtensions) {
  return impl.pickLogoFileImpl(allowedExtensions);
}
