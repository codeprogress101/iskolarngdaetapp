import 'package:flutter/material.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader({
    required this.title,
    required this.subtitle,
    this.note,
    this.logoAssetPath = 'assets/reference/img/daet-lgu.png',
    super.key,
  });

  final String title;
  final String subtitle;
  final String? note;
  final String logoAssetPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Image.asset(
          logoAssetPath,
          width: 76,
          height: 76,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const CircleAvatar(
              radius: 38,
              child: Icon(Icons.account_balance_rounded),
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        if ((note ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            note!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
