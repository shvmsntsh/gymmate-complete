import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gymmate_mobile/api/api_config.dart';
import 'package:gymmate_mobile/providers/auth_provider.dart';
import 'package:gymmate_mobile/utils/branding_utils.dart';
import 'package:gymmate_mobile/utils/logo_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

class BrandingSettingsPage extends StatefulWidget {
  final bool isRequiredSetup;

  const BrandingSettingsPage({Key? key, this.isRequiredSetup = false})
    : super(key: key);

  @override
  State<BrandingSettingsPage> createState() => _BrandingSettingsPageState();
}

class _BrandingSettingsPageState extends State<BrandingSettingsPage> {
  static const int _maxLogoBytes = 5 * 1024 * 1024;
  static const List<String> _allowedExtensions = [
    'png',
    'jpg',
    'jpeg',
    'jfif',
    'pjpeg',
    'pjp',
    'webp',
  ];

  late TextEditingController _gymNameController;
  bool _isSaving = false;
  bool _isPickingLogo = false;

  String? _logoSource;
  static const String _primaryColor = '#B59F5B';
  static const String _secondaryColor = '#F8D84B';

  @override
  void initState() {
    super.initState();
    final branding = Provider.of<AuthProvider>(context, listen: false).branding;
    _gymNameController = TextEditingController(
      text: branding['gymName']?.toString() ?? '',
    );
    _logoSource = branding['logoUrl']?.toString();
  }

  @override
  void dispose() {
    _gymNameController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    setState(() {
      _isPickingLogo = true;
    });

    try {
      final file = await pickLogoFile(_allowedExtensions);
      if (file == null) {
        return;
      }

      final extension = file.extension.toLowerCase();
      final bytes = file.bytes;
      final mimeType = (file.mimeType ?? '').toLowerCase();

      if (bytes.length > _maxLogoBytes) {
        throw Exception('Please keep the logo under 5 MB.');
      }

      final isAllowedExtension =
          extension.isNotEmpty && _allowedExtensions.contains(extension);
      final isAllowedMimeType = mimeType.startsWith('image/');

      if (!isAllowedExtension && !isAllowedMimeType) {
        throw Exception(
          'Please choose an image file like PNG, JPG, JPEG, JFIF, or WebP.',
        );
      }

      final normalizedMimeType = mimeType.isNotEmpty
          ? mimeType
          : extension == 'jpg'
          ? 'image/jpeg'
          : extension == 'jfif'
          ? 'image/jpeg'
          : 'image/$extension';
      final source = 'data:$normalizedMimeType;base64,${base64Encode(bytes)}';

      setState(() {
        _logoSource = source;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPickingLogo = false;
        });
      }
    }
  }

  Future<void> _saveBranding() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    if (token == null) return;

    final gymName = _gymNameController.text.trim();
    if (gymName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gym name is required')));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/gym/branding'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'gymName': gymName,
          'logoUrl': _logoSource ?? '',
          'primaryColor': _primaryColor,
          'secondaryColor': _secondaryColor,
          'logoScale': 1,
          'logoOffsetX': 0,
          'logoOffsetY': 0,
        }),
      );

      final payload = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        throw Exception(payload['message'] ?? 'Failed to update branding');
      }

      await authProvider.refreshBranding();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Branding updated successfully')),
      );
      if (!widget.isRequiredSetup) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _removeLogo() {
    setState(() {
      _logoSource = null;
    });
  }

  List<String> _initialsOptions(String gymName) {
    return List.generate(
      3,
      (index) => buildInitialsLogoDataUri(gymName, index),
    );
  }

  Color _panelColor(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? const Color(0xFF2E2818)
        : Colors.white;
  }

  Color _panelBorderColor(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? const Color(0xFF5B4C26)
        : const Color(0xFFE7D6A7);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final panelColor = _panelColor(theme);
    final borderColor = _panelBorderColor(theme);
    final gymName = _gymNameController.text.trim().isEmpty
        ? 'GymMate'
        : _gymNameController.text.trim();
    final initialsOptions = _initialsOptions(gymName);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isRequiredSetup,
        title: Text(
          widget.isRequiredSetup ? 'Set Up Your Gym Brand' : 'Branding',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                colors: theme.brightness == Brightness.dark
                    ? const [Color(0xFF352C18), Color(0xFF241F13)]
                    : const [Color(0xFFFFFCF2), Color(0xFFF8F1DE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isRequiredSetup
                      ? 'Make your gym recognizable from the first screen'
                      : 'Refresh how your gym looks in the app',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.isRequiredSetup
                      ? 'Upload your logo before continuing. Members and trainers will see this across the app.'
                      : 'Upload a logo or choose a simple initials mark. GymMate colors stay fixed so everything remains polished and readable.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.82),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: panelColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: borderColor.withValues(alpha: 0.95),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gym name',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _gymNameController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Enter your gym name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Gym logo',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Allowed formats: PNG, JPG, JPEG, JFIF, WebP. Maximum size: 5 MB. Landscape, portrait, and square logos are all supported.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.75,
                          ),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: Container(
                          width: 200,
                          height: 200,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.brightness == Brightness.dark
                                ? const Color(0xFF1D1A12)
                                : const Color(0xFFFFFCF7),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: borderColor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: theme.brightness == Brightness.dark
                                      ? 0.16
                                      : 0.06,
                                ),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: BrandingLogoFrame(
                            source: _logoSource,
                            size: 172,
                            scale: 1,
                            offsetX: 0,
                            offsetY: 0,
                            borderRadius: BorderRadius.circular(20),
                            fallback: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFB59F5B),
                                    Color(0xFFF8D84B),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.image_outlined,
                                  size: 46,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isPickingLogo ? null : _pickLogo,
                              icon: _isPickingLogo
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.upload_file),
                              label: Text(
                                _logoSource == null
                                    ? 'Choose Logo'
                                    : 'Replace Logo',
                              ),
                            ),
                          ),
                          if (_logoSource != null) ...[
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: _removeLogo,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(112, 52),
                                side: BorderSide(color: borderColor),
                                foregroundColor: theme.colorScheme.onSurface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('Remove'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: panelColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: borderColor.withValues(alpha: 0.95),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No logo handy?',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pick one of these simple initials marks based on $gymName.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.75,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: initialsOptions
                            .map(
                              (option) => Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: option == initialsOptions.last
                                        ? 0
                                        : 12,
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {
                                      setState(() {
                                        _logoSource = option;
                                      });
                                    },
                                    child: Container(
                                      height: 124,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color:
                                            theme.brightness == Brightness.dark
                                            ? const Color(0xFF1D1A12)
                                            : const Color(0xFFFFFCF7),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: _logoSource == option
                                              ? const Color(0xFFF8D84B)
                                              : borderColor,
                                          width: _logoSource == option
                                              ? 2.4
                                              : 1.4,
                                        ),
                                      ),
                                      child: BrandingLogoFrame(
                                        source: option,
                                        size: 92,
                                        scale: 1,
                                        offsetX: 0,
                                        offsetY: 0,
                                        borderRadius: BorderRadius.circular(14),
                                        fallback: const SizedBox.shrink(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: panelColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFB59F5B), Color(0xFFF8D84B)],
                    ),
                  ),
                  child: const Icon(
                    Icons.palette_outlined,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your gym name and logo already shape the experience across the app. Color styling will expand in a future update.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.82,
                      ),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSaving ? null : _saveBranding,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Branding'),
          ),
          const SizedBox(height: 12),
          Text(
            'Powered by GymMate will always remain visible in the app footer.',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.86),
            ),
          ),
        ],
      ),
    );
  }
}
