import 'dart:typed_data';

class PickedLogoFile {
  final Uint8List bytes;
  final String extension;
  final String? mimeType;

  const PickedLogoFile({
    required this.bytes,
    required this.extension,
    this.mimeType,
  });
}

Future<PickedLogoFile?> pickLogoFileImpl(List<String> allowedExtensions) async {
  throw UnsupportedError('Logo picking is not supported on this platform.');
}
