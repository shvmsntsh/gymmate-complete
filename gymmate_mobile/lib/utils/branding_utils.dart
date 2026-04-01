import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

const Map<String, dynamic> kDefaultBranding = {
  'gymName': 'GymMate',
  'logoUrl': null,
  'primaryColor': '#B59F5B',
  'secondaryColor': '#F8D84B',
  'logoScale': 1.0,
  'logoOffsetX': 0.0,
  'logoOffsetY': 0.0,
};

Color colorFromHex(String? hex, {required Color fallback}) {
  if (hex == null || hex.isEmpty) return fallback;
  final normalized = hex.replaceAll('#', '').trim();
  if (normalized.length != 6 && normalized.length != 8) return fallback;

  final buffer = StringBuffer();
  if (normalized.length == 6) {
    buffer.write('FF');
  }
  buffer.write(normalized);

  try {
    return Color(int.parse(buffer.toString(), radix: 16));
  } catch (_) {
    return fallback;
  }
}

Map<String, dynamic> normalizeBranding(Map<String, dynamic>? branding) {
  return {
    'gymName':
        branding?['gymName'] ??
        branding?['name'] ??
        kDefaultBranding['gymName'],
    'logoUrl': branding?['logoUrl'] ?? kDefaultBranding['logoUrl'],
    'primaryColor':
        branding?['primaryColor'] ?? kDefaultBranding['primaryColor'],
    'secondaryColor':
        branding?['secondaryColor'] ?? kDefaultBranding['secondaryColor'],
    'logoScale': (branding?['logoScale'] as num?)?.toDouble() ?? kDefaultBranding['logoScale'],
    'logoOffsetX': (branding?['logoOffsetX'] as num?)?.toDouble() ?? kDefaultBranding['logoOffsetX'],
    'logoOffsetY': (branding?['logoOffsetY'] as num?)?.toDouble() ?? kDefaultBranding['logoOffsetY'],
  };
}

bool isBrandingComplete(Map<String, dynamic>? branding) {
  final normalized = normalizeBranding(branding);
  final logoUrl = normalized['logoUrl']?.toString();
  return logoUrl != null && logoUrl.isNotEmpty;
}

String gymInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.isEmpty) return 'GM';
  if (parts.length == 1) {
    return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  }

  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

String buildInitialsLogoDataUri(String gymName, int variant) {
  final initials = gymInitials(gymName);
  const variants = [
    {
      'bg': '#B59F5B',
      'accent': '#232112',
      'stroke': '#F8D84B',
    },
    {
      'bg': '#232112',
      'accent': '#F8D84B',
      'stroke': '#B59F5B',
    },
    {
      'bg': '#F8D84B',
      'accent': '#232112',
      'stroke': '#B59F5B',
    },
  ];

  final style = variants[variant % variants.length];
  final svg = '''
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <rect width="512" height="512" rx="120" fill="${style['bg']}" />
  <rect x="32" y="32" width="448" height="448" rx="104" fill="none" stroke="${style['stroke']}" stroke-width="14" />
  <text x="50%" y="54%" text-anchor="middle" dominant-baseline="middle"
    font-family="Arial, Helvetica, sans-serif" font-size="190" font-weight="700" fill="${style['accent']}">$initials</text>
</svg>
''';

  return 'data:image/svg+xml;base64,${base64Encode(utf8.encode(svg))}';
}

Uint8List? bytesFromLogoSource(String? source) {
  if (source == null || source.isEmpty || !source.startsWith('data:image/')) {
    return null;
  }

  final marker = source.indexOf('base64,');
  if (marker == -1) return null;

  try {
    return base64Decode(source.substring(marker + 7));
  } catch (_) {
    return null;
  }
}

ImageProvider? imageProviderFromLogoSource(String? source) {
  final bytes = bytesFromLogoSource(source);
  if (bytes != null) {
    return MemoryImage(bytes);
  }
  if (source != null && source.isNotEmpty) {
    return NetworkImage(source);
  }
  return null;
}

class BrandingLogoFrame extends StatelessWidget {
  final String? source;
  final double size;
  final double scale;
  final double offsetX;
  final double offsetY;
  final BorderRadius borderRadius;
  final Widget fallback;

  const BrandingLogoFrame({
    super.key,
    required this.source,
    required this.size,
    required this.scale,
    required this.offsetX,
    required this.offsetY,
    required this.borderRadius,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final provider = imageProviderFromLogoSource(source);
    if (provider == null) {
      return fallback;
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: size,
        height: size,
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.all(6),
          alignment: Alignment(offsetX, offsetY),
          child: Transform.scale(
            scale: scale,
            child: Image(
              image: provider,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => fallback,
            ),
          ),
        ),
      ),
    );
  }
}
