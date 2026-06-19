String formatDateIN(dynamic raw) {
  if (raw == null) return 'N/A';

  final value = raw.toString().trim();
  if (value.isEmpty) return 'N/A';

  final dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  DateTime? parsed;

  if (dateOnly != null) {
    parsed = DateTime(
      int.parse(dateOnly.group(1)!),
      int.parse(dateOnly.group(2)!),
      int.parse(dateOnly.group(3)!),
      12,
    );
  } else {
    parsed = DateTime.tryParse(value)?.toLocal();
  }

  if (parsed == null) return 'N/A';

  final month = parsed.month.toString().padLeft(2, '0');
  final day = parsed.day.toString().padLeft(2, '0');
  return '$day/$month/${parsed.year}';
}
