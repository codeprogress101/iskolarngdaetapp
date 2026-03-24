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
    return _PressScale(
      enabled: onPressed != null,
      child: FilledButton(onPressed: onPressed, child: Text(text)),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({required this.text, this.onPressed, super.key});

  final String text;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      enabled: onPressed != null,
      child: OutlinedButton(onPressed: onPressed, child: Text(text)),
    );
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
      children: List<Widget>.generate(items.length, (index) {
        final row = items[index];
        return _TimelineAnimatedItem(
          index: index,
          child: Row(
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
                      Text(
                        row.label,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        row.when,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
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

class SectionGap extends StatelessWidget {
  const SectionGap({this.size = AppSpacing.md, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: size);
  }
}

class AnimatedPageState extends StatelessWidget {
  const AnimatedPageState({required this.child, required this.stateKey, super.key});

  final Widget child;
  final String stateKey;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offsetAnimation, child: child),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<String>(stateKey),
        child: child,
      ),
    );
  }
}

class PulseSkeleton extends StatefulWidget {
  const PulseSkeleton({
    this.height = 14,
    this.width = double.infinity,
    this.radius = AppRadius.md,
    this.margin,
    super.key,
  });

  final double height;
  final double width;
  final double radius;
  final EdgeInsetsGeometry? margin;

  @override
  State<PulseSkeleton> createState() => _PulseSkeletonState();
}

class _PulseSkeletonState extends State<PulseSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 0.95).animate(_controller),
      child: Container(
        margin: widget.margin,
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            PulseSkeleton(height: 16, width: 180),
            SectionGap(size: AppSpacing.sm),
            PulseSkeleton(height: 14, width: double.infinity),
            SectionGap(size: AppSpacing.xs),
            PulseSkeleton(height: 14, width: 220),
            SectionGap(size: AppSpacing.md),
            PulseSkeleton(height: 44, width: double.infinity, radius: AppRadius.lg),
          ],
        ),
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({
    this.count = 3,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    super.key,
  });

  final int count;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      itemCount: count,
      separatorBuilder: (_, index) => const SectionGap(),
      itemBuilder: (_, index) => const SkeletonCard(),
    );
  }
}

class RevealOnMount extends StatefulWidget {
  const RevealOnMount({
    required this.child,
    this.delayMs = 0,
    this.offsetY = 0.03,
    super.key,
  });

  final Widget child;
  final int delayMs;
  final double offsetY;

  @override
  State<RevealOnMount> createState() => _RevealOnMountState();
}

class _RevealOnMountState extends State<RevealOnMount> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(milliseconds: widget.delayMs), () {
      if (!mounted) return;
      setState(() {
        _visible = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      opacity: _visible ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        offset: _visible ? Offset.zero : Offset(0, widget.offsetY),
        child: widget.child,
      ),
    );
  }
}

class _TimelineAnimatedItem extends StatefulWidget {
  const _TimelineAnimatedItem({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_TimelineAnimatedItem> createState() => _TimelineAnimatedItemState();
}

class _TimelineAnimatedItemState extends State<_TimelineAnimatedItem> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(milliseconds: 55 * widget.index), () {
      if (!mounted) return;
      setState(() {
        _visible = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      opacity: _visible ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        offset: _visible ? Offset.zero : const Offset(0, 0.035),
        child: widget.child,
      ),
    );
  }
}

class _PressScale extends StatefulWidget {
  const _PressScale({required this.child, required this.enabled});

  final Widget child;
  final bool enabled;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  double _scale = 1.0;

  void _setPressed(bool pressed) {
    if (!widget.enabled) return;
    setState(() {
      _scale = pressed ? 0.985 : 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
