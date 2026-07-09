import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../training/presentation/widgets/active_session_banner.dart';

class MainShellPage extends ConsumerWidget {
  final Widget child;
  const MainShellPage({super.key, required this.child});

  static const _tabs = [
    (route: AppRoutes.home,      icon: Icons.grid_view_rounded,       label: 'Inicio'),
    (route: AppRoutes.nutrition, icon: Icons.restaurant_menu_rounded,  label: 'Nutrición'),
    (route: AppRoutes.training,  icon: Icons.fitness_center_rounded,   label: 'Entreno'),
    (route: AppRoutes.progress,  icon: Icons.trending_up_rounded,      label: 'Progreso'),
    (route: AppRoutes.profile,   icon: Icons.person_rounded,           label: 'Perfil'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final idx = _tabs.indexWhere((t) => location.startsWith(t.route));
    return idx < 0 ? 0 : idx;
  }

  /// Horizontal swipe over the body → switches to the adjacent tab.
  /// Velocity threshold to avoid accidental triggers; inner horizontal scrolls
  /// (carousels, Dismissible) win the gesture in their own area.
  void _onHorizontalSwipe(BuildContext context, double velocity) {
    if (velocity.abs() < 280) return;
    final current = _currentIndex(context);
    final next = velocity < 0 ? current + 1 : current - 1;
    if (next >= 0 && next < _tabs.length) {
      context.go(_tabs[next].route);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the theme mode so the bar recolors instantly on light/dark switch
    // (it reads the already-updated BrioColors tokens).
    ref.watch(themeModeProvider);
    final idx = _currentIndex(context);

    return Scaffold(
      extendBody: true,
      // BrioColors uses static fields (not an InheritedWidget), so tab pages
      // don't rebuild on their own when the theme changes. We re-key the content
      // with the current brightness: on toggle, the subtree rebuilds and picks
      // up the new colors instantly (without having to switch tabs).
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (d) => _onHorizontalSwipe(context, d.primaryVelocity ?? 0),
        child: KeyedSubtree(key: ValueKey(BrioColors.brightness), child: child),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ActiveSessionBanner(),
          SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: BrioColors.bgElevated,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    _NavItem(
                      icon:     _tabs[i].icon,
                      label:    _tabs[i].label,
                      selected: i == idx,
                      onTap:    () => context.go(_tabs[i].route),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon, required this.label, required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: selected ? 14 : 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? BrioColors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22,
                color: selected ? BrioColors.textInverse : BrioColors.textTertiary),
            if (selected) ...[
              const SizedBox(width: 7),
              Text(label,
                  style: const TextStyle(
                    color: BrioColors.textInverse,
                    fontSize: 12, fontWeight: FontWeight.w700,
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
