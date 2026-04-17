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

      final branding = payload['branding'];
      if (branding is Map<String, dynamic>) {
        await authProvider.applyBrandingUpdate(branding);
      } else {
        await authProvider.refreshBranding();
      }

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

  InputDecoration _fieldDecoration(ThemeData theme, String hintText) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: theme.brightness == Brightness.dark
          ? const Color(0xFF1B1712)
          : const Color(0xFFFFFCF7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: _panelBorderColor(theme).withValues(alpha: 0.9),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: _panelBorderColor(theme).withValues(alpha: 0.9),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.6),
      ),
    );
  }

  Widget _sectionCard({required ThemeData theme, required Widget child}) {
    final panelColor = _panelColor(theme);
    final borderColor = _panelBorderColor(theme);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor.withValues(alpha: 0.95)),
      ),
      child: child,
    );
  }

  Widget _previewFallback(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFFB59F5B), Color(0xFFF8D84B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              size: 34,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your gym mark will show here',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.black87,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Upload a logo or choose a quick initials mark.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.black.withValues(alpha: 0.72),
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = _panelBorderColor(theme);
    final primary = theme.colorScheme.primary;
    final gymName = _gymNameController.text.trim().isEmpty
        ? 'GymMate'
        : _gymNameController.text.trim();
    final initialsOptions = _initialsOptions(gymName);
    final hasLogo = _logoSource != null && _logoSource!.isNotEmpty;

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
                  'BRAND STUDIO',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.isRequiredSetup
                      ? 'Set the look members will recognize.'
                      : 'Refresh how your gym shows up.',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.isRequiredSetup
                      ? 'Add a gym name and logo so your space feels consistent from the first screen onward.'
                      : 'Update your gym name and logo so every member touchpoint feels clean and familiar.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.82),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                _sectionCard(
                  theme: theme,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gym identity',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This is the name members will see across your gym experience.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.74,
                          ),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _gymNameController,
                        onChanged: (_) => setState(() {}),
                        decoration: _fieldDecoration(
                          theme,
                          'Enter your gym name',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _sectionCard(
                  theme: theme,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Logo preview',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'PNG, JPG, JPEG, JFIF, or WebP up to 5 MB. Square, portrait, and landscape logos all work.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.75,
                          ),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? const Color(0xFF17130F)
                              : const Color(0xFFFFFCF7),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: theme.brightness == Brightness.dark
                                    ? 0.18
                                    : 0.06,
                              ),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: AspectRatio(
                          aspectRatio: 1.1,
                          child: BrandingLogoFrame(
                            source: _logoSource,
                            size: 220,
                            scale: 1,
                            offsetX: 0,
                            offsetY: 0,
                            borderRadius: BorderRadius.circular(24),
                            fallback: _previewFallback(theme),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: hasLogo ? 172 : double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isPickingLogo ? null : _pickLogo,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 56),
                                backgroundColor: primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              icon: _isPickingLogo
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: theme.colorScheme.onPrimary,
                                      ),
                                    )
                                  : const Icon(Icons.upload_rounded),
                              label: Text(
                                hasLogo ? 'Replace Logo' : 'Upload Logo',
                              ),
                            ),
                          ),
                          if (hasLogo)
                            OutlinedButton(
                              onPressed: _removeLogo,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(140, 56),
                                side: BorderSide(color: borderColor),
                                foregroundColor: theme.colorScheme.onSurface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: const Text('Remove Logo'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _sectionCard(
                  theme: theme,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick marks',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choose a clean initials logo while your full logo is getting ready.',
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
                                        boxShadow: _logoSource == option
                                            ? [
                                                BoxShadow(
                                                  color: primary.withValues(
                                                    alpha: 0.18,
                                                  ),
                                                  blurRadius: 16,
                                                  offset: const Offset(0, 8),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Stack(
                                        children: [
                                          Center(
                                            child: BrandingLogoFrame(
                                              source: option,
                                              size: 92,
                                              scale: 1,
                                              offsetX: 0,
                                              offsetY: 0,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              fallback: Center(
                                                child: Text(
                                                  gymName.isEmpty
                                                      ? 'GM'
                                                      : gymName
                                                            .substring(
                                                              0,
                                                              gymName.length >=
                                                                      2
                                                                  ? 2
                                                                  : 1,
                                                            )
                                                            .toUpperCase(),
                                                  style: theme
                                                      .textTheme
                                                      .headlineSmall,
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (_logoSource == option)
                                            Positioned(
                                              top: 6,
                                              right: 6,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: primary,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                                child: Text(
                                                  'Selected',
                                                  style: theme
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: theme
                                                            .colorScheme
                                                            .onPrimary,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                ),
                                              ),
                                            ),
                                        ],
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
          _sectionCard(
            theme: theme,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Save and apply',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your updated branding will appear across your gym’s app surfaces.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _saveBranding,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      backgroundColor: primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _isSaving
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : const Text('Save Branding'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
