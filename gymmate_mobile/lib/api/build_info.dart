class BuildInfo {
  static const String buildTime = String.fromEnvironment(
    'BUILD_TIME',
    defaultValue: '',
  );

  static String get versionLabel {
    if (buildTime.isEmpty) return 'dev build';
    final parsed = DateTime.tryParse(buildTime);
    if (parsed == null) return 'dev build';
    final local = parsed.toLocal();
    String pad(int n) => n.toString().padLeft(2, '0');
    return 'v${local.year}-${pad(local.month)}-${pad(local.day)} ${pad(local.hour)}:${pad(local.minute)}';
  }
}
