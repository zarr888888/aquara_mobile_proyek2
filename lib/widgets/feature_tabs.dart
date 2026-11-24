import 'package:flutter/material.dart';
import 'samudera_theme.dart';

/// Explicit surfaces avoid primary-coloured labels on a primary AppBar.
class FeatureTabs extends StatelessWidget implements PreferredSizeWidget {
  const FeatureTabs({
    super.key,
    required this.controller,
    required this.labels,
  });
  final TabController controller;
  final List<String> labels;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: TabBar(
      controller: controller,
      isScrollable: true,
      tabAlignment: TabAlignment.center,
      labelColor: Colors.black,
      unselectedLabelColor: Theme.of(context).colorScheme.onSurface,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: BoxDecoration(
        color: SamuderaColors.blue,
        borderRadius: BorderRadius.circular(8),
      ),
      indicatorPadding: const EdgeInsets.symmetric(vertical: 4),
      dividerColor: Colors.transparent,
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return SamuderaColors.orange.withValues(alpha: .3);
        }
        if (states.contains(WidgetState.pressed)) {
          return Colors.black.withValues(alpha: .12);
        }
        return Colors.transparent;
      }),
      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
      tabs: [for (final label in labels) Tab(height: 56, text: label)],
    ),
  );
}
