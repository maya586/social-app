import 'package:flutter/material.dart';
import '../../core/theme/admin_theme.dart';
import 'glass_container.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isLoading;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.subtitle,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AdminTheme.primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: effectiveColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AdminTheme.borderRadiusMedium),
                  ),
                  child: Icon(
                    icon,
                    color: effectiveColor,
                    size: 24,
                  ),
                ),
                const Spacer(),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: effectiveColor,
                        ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (isLoading)
              Container(
                width: 80,
                height: 28,
                decoration: BoxDecoration(
                  color: AdminTheme.glassBackground,
                  borderRadius: BorderRadius.circular(AdminTheme.borderRadiusSmall),
                ),
              )
            else
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AdminTheme.textPrimary,
                    ),
              ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AdminTheme.textTertiary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatCardGrid extends StatelessWidget {
  final List<StatCard> cards;
  final int crossAxisCount;
  final double spacing;

  const StatCardGrid({
    super.key,
    required this.cards,
    this.crossAxisCount = 4,
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards.map((card) {
            return SizedBox(
              width: cardWidth,
              child: card,
            );
          }).toList(),
        );
      },
    );
  }
}