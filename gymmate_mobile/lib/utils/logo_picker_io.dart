import 'package:file_picker/file_picker.dart';

import 'logo_picker_stub.dart';

Future<PickedLogoFile?> pickLogoFileImpl(List<String> allowedExtensions) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
    withData: true,
  );

  if (result == null || result.files.isEmpty) {
    return null;
  }

  final file = result.files.first;
  final extension = (file.extension ?? '').toLowerCase();
  final bytes = file.bytes;

  if (bytes == null) {
    return null;
  }

  return PickedLogoFile(bytes: bytes, extension: extension);
}
