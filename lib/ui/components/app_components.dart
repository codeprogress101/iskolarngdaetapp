import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.logoAssetPath,
    this.logoSize = 30,
    this.titleStyle,
    this.subtitleStyle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final String? logoAssetPath;
  final double logoSize;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...<Widget?>[
          leading,
          if (leading != null) const SizedBox(width: AppSpacing.sm),
        ].whereType<Widget>(),
        if ((logoAssetPath ?? '').trim().isNotEmpty) ...[
          Image.asset(
            logoAssetPath!,
            width: logoSize,
            height: logoSize,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.shield_outlined, size: 24),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: titleStyle ?? Theme.of(context).textTheme.headlineSmall,
              ),
              if ((subtitle ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: subtitleStyle ?? Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
        ...<Widget?>[trailing].whereType<Widget>(),
      ],
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.child,
    this.title,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    super.key,
  });

  final Widget child;
  final String? title;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((title ?? '').trim().isNotEmpty) ...[
              Text(
                title!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final status = text.trim().toLowerCase();
    Color fg = AppColors.textPrimary;
    Color bg = AppColors.surfaceSoft;
    if (status.contains('approved') || status.contains('verified')) {
      fg = AppColors.success;
      bg = const Color(0xFFE5F6EC);
    } else if (status.contains('returned') ||
        status.contains('rejected') ||
        status.contains('failed')) {
      fg = AppColors.danger;
      bg = const Color(0xFFFCEAEA);
    } else if (status.contains('pending') || status.contains('for review')) {
      fg = AppColors.warning;
      bg = const Color(0xFFFFF4E4);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({required this.label, required this.value, this.emphasize = false, super.key});

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: (emphasize
                      ? Theme.of(context).textTheme.titleMedium
                      : Theme.of(context).textTheme.bodyLarge)
                  ?.copyWith(fontSize: emphasize ? 15 : 14),
            ),
          ),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({required this.text, this.onPressed, super.key});

  final String text;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(onPressed: onPressed, child: Text(text));
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({required this.text, this.onPressed, super.key});

  final String text;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(onPressed: onPressed, child: Text(text));
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        children: [
          const Icon(Icons.inbox_rounded, size: 38, color: AppColors.textSecondary),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(message, textAlign: TextAlign.center),
          if ((actionLabel ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(text: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

class TimelineList extends StatelessWidget {
  const TimelineList({required this.items, super.key});

  final List<({String label, String when})> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text('No timeline yet.');
    }
    return Column(
      children: items.map((row) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(width: 2, height: 40, color: AppColors.border),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.label, style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 2),
                    Text(row.when, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class RequirementItem extends StatelessWidget {
  const RequirementItem({required this.label, required this.status, super.key});

  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
          StatusBadge(text: status),
        ],
      ),
    );
  }
}

class ProgressCard extends StatelessWidget {
  const ProgressCard({
    required this.title,
    required this.value,
    required this.caption,
    super.key,
  });

  final String title;
  final double value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final percent = value.clamp(0.0, 1.0).toDouble();
    return SectionCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: percent,
            minHeight: 10,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(caption),
        ],
      ),
    );
  }
}

class FormSection extends StatelessWidget {
  const FormSection({
    required this.title,
    required this.children,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((subtitle ?? '').trim().isNotEmpty) ...[
            Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
          ],
          ...children,
        ],
      ),
    );
  }
}

class StepIndicator extends StatelessWidget {
  const StepIndicator({
    required this.currentStep,
    required this.labels,
    this.onStepTap,
    super.key,
  });

  final int currentStep;
  final List<String> labels;
  final ValueChanged<int>? onStepTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final active = index <= currentStep;
          return InkWell(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            onTap: onStepTap == null ? null : () => onStepTap!(index),
            child: Chip(
              label: Text('${index + 1}. ${labels[index]}'),
              backgroundColor: active ? const Color(0xFFDCEBFF) : AppColors.surfaceSoft,
              labelStyle: TextStyle(
                color: active ? AppColors.primaryDark : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        },
        separatorBuilder: (_, index) => const SizedBox(width: AppSpacing.sm),
        itemCount: labels.length,
      ),
    );
  }
}

class UploadField extends StatelessWidget {
  const UploadField({
    required this.title,
    required this.fileName,
    required this.onTap,
    this.preview,
    this.enabled = true,
    super.key,
  });

  final String title;
  final String? fileName;
  final VoidCallback? onTap;
  final Widget? preview;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (preview != null) ...[
            preview!,
            const SizedBox(height: AppSpacing.md),
          ],
          SecondaryButton(
            text: 'Choose File',
            onPressed: enabled ? onTap : null,
          ),
          if ((fileName ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(fileName!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
