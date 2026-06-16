import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// ADNORA brand logo widget
class AdnoraLogo extends StatelessWidget {
  const AdnoraLogo({
    super.key,
    this.size = AdnoraLogoSize.medium,
    this.showTagline = false,
    this.showText = true,
  });

  final AdnoraLogoSize size;
  final bool showTagline;
  final bool showText;

  double get _fontSize {
    return switch (size) {
      AdnoraLogoSize.small => 18,
      AdnoraLogoSize.medium => 24,
      AdnoraLogoSize.large => 36,
      AdnoraLogoSize.hero => 56,
    };
  }

  double get _iconSize {
    return switch (size) {
      AdnoraLogoSize.small => 28,
      AdnoraLogoSize.medium => 36,
      AdnoraLogoSize.large => 48,
      AdnoraLogoSize.hero => 72,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo mark
        SvgPicture.asset(
          'assets/icons/logo.svg',
          width: _iconSize,
          height: _iconSize,
        ),
        if (showText) ...[
          SizedBox(height: _fontSize * 0.4),
          // Wordmark
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [context.colors.textPrimary, context.colors.brandLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              'ADNORA',
              style: TextStyle(
                fontSize: _fontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: _fontSize * 0.15,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

enum AdnoraLogoSize { small, medium, large, hero }
