import 'package:flutter/material.dart';

enum AuthBannerType {
  info,
  success,
  warning,
  error,
}

class AuthMessageBanner extends StatelessWidget {
  const AuthMessageBanner({
    required this.message,
    required this.type,
    super.key,
  });

  final String message;
  final AuthBannerType type;

  @override
  Widget build(BuildContext context) {
    final scheme = _scheme(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.border),
      ),
      child: Row(
        children: [
          Icon(scheme.icon, size: 18, color: scheme.foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.foreground),
            ),
          ),
        ],
      ),
    );
  }

  _BannerScheme _scheme(AuthBannerType value) {
    switch (value) {
      case AuthBannerType.success:
        return const _BannerScheme(
          background: Color(0xFFECFDF3),
          border: Color(0xFFA6F4C5),
          foreground: Color(0xFF067647),
          icon: Icons.check_circle_outline,
        );
      case AuthBannerType.warning:
        return const _BannerScheme(
          background: Color(0xFFFFFAEB),
          border: Color(0xFFFEC84B),
          foreground: Color(0xFFB54708),
          icon: Icons.warning_amber_rounded,
        );
      case AuthBannerType.error:
        return const _BannerScheme(
          background: Color(0xFFFEE2E2),
          border: Color(0xFFFCA5A5),
          foreground: Color(0xFF991B1B),
          icon: Icons.error_outline,
        );
      case AuthBannerType.info:
        return const _BannerScheme(
          background: Color(0xFFE0F2FE),
          border: Color(0xFF7DD3FC),
          foreground: Color(0xFF075985),
          icon: Icons.info_outline,
        );
    }
  }
}

class _BannerScheme {
  const _BannerScheme({
    required this.background,
    required this.border,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color foreground;
  final IconData icon;
}
