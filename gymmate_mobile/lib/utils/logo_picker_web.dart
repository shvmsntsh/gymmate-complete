import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'logo_picker_stub.dart';

Future<PickedLogoFile?> pickLogoFileImpl(List<String> allowedExtensions) async {
  final acceptedTypes = [
    ...allowedExtensions.map((extension) => '.${extension.toLowerCase()}'),
    'image/jpeg',
    'image/jpg',
    'image/pjpeg',
    'image/png',
    'image/webp',
    'image/*',
  ].join(',');
  final completer = Completer<PickedLogoFile?>();
  final input = html.FileUploadInputElement()
    ..accept = acceptedTypes
    ..multiple = false;

  input.onChange.listen((_) {
    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final extension = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : '';

    final reader = html.FileReader();
    reader.onLoad.listen((_) {
      final result = reader.result;
      if (result is ByteBuffer) {
        if (!completer.isCompleted) {
          completer.complete(
            PickedLogoFile(
              bytes: Uint8List.view(result),
              extension: extension,
              mimeType: file.type,
            ),
          );
        }
      } else if (result is Uint8List) {
        if (!completer.isCompleted) {
          completer.complete(
            PickedLogoFile(
              bytes: result,
              extension: extension,
              mimeType: file.type,
            ),
          );
        }
      } else {
        if (!completer.isCompleted) completer.complete(null);
      }
    });
    reader.onError.listen((_) {
      if (!completer.isCompleted) completer.completeError(Exception('Failed to read selected file.'));
    });
    reader.readAsArrayBuffer(file);
  });

  input.click();
  return completer.future;
}
