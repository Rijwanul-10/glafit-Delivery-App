import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/twobee_theme.dart';

enum AppUserRole { client, rider, merchant }

class AppNavTabSpec {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const AppNavTabSpec(this.label, this.icon, this.activeIcon);
}

/// Floating Scooped Dock Bottom Navigation Bar (Neo-Tactile Architecture)
/// - Floats 12px above bottom safe area with 16px horizontal margins
/// - Deep Forest Obsidian backdrop (#0E1310) with multi-stop diffuse shadow
/// - Center elevated Floating Action Button (FAB) with Eco Emerald glow
/// - Retains 4-tab index compatibility (0, 1, 2, 3) for all roles
class AppBottomNav extends StatelessWidget {
  final AppUserRole role;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int badgeCount;
  final VoidCallback? onCenterAction;

  const AppBottomNav({
    super.key,
    required this.role,
    required this.currentIndex,
    required this.onTap,
    this.badgeCount = 0,
    this.onCenterAction,
  });

  static List<AppNavTabSpec> tabsForRole(AppUserRole role) {
    switch (role) {
      case AppUserRole.client:
        return const [
          AppNavTabSpec('Home', Icons.home_outlined, Icons.home_rounded),
          AppNavTabSpec('Activity', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
          AppNavTabSpec('Wallet', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded),
          AppNavTabSpec('Profile', Icons.person_outline_rounded, Icons.person_rounded),
        ];
      case AppUserRole.rider:
        return const [
          AppNavTabSpec('Home', Icons.two_wheeler_outlined, Icons.two_wheeler_rounded),
          AppNavTabSpec('Jobs', Icons.assignment_outlined, Icons.assignment_rounded),
          AppNavTabSpec('Wallet', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded),
          AppNavTabSpec('Profile', Icons.person_outline_rounded, Icons.person_rounded),
        ];
      case AppUserRole.merchant:
        return const [
          AppNavTabSpec('Home', Icons.storefront_outlined, Icons.storefront_rounded),
          AppNavTabSpec('Orders', Icons.list_alt_outlined, Icons.list_alt_rounded),
          AppNavTabSpec('Wallet', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded),
          AppNavTabSpec('Store', Icons.settings_outlined, Icons.settings_rounded),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final specs = tabsForRole(role);

    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        height: 74,
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        decoration: BoxDecoration(
          color: TwoBeeColors.obsidian,
          borderRadius: BorderRadius.circular(38),
          boxShadow: TwoBeeShadows.dockNav,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Tab 0 (Home)
            _buildNavItem(specs[0], 0, isBadge: false),

            // Tab 1 (Activity / Jobs / Orders)
            _buildNavItem(specs[1], 1, isBadge: badgeCount > 0),

            // Center Elevated FAB (Eco Emerald Action)
            _buildCenterFab(context),

            // Tab 2 (Wallet)
            _buildNavItem(specs[2], 2, isBadge: false),

            // Tab 3 (Profile / Store)
            _buildNavItem(specs[3], 3, isBadge: false),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(AppNavTabSpec spec, int index, {required bool isBadge}) {
    final isSelected = currentIndex == index;

    Widget iconWidget = Icon(
      isSelected ? spec.activeIcon : spec.icon,
      size: 22,
      color: isSelected ? TwoBeeColors.primary : Colors.white.withValues(alpha: 0.6),
    );

    if (isBadge) {
      iconWidget = Badge.count(
        count: badgeCount,
        backgroundColor: TwoBeeColors.primary,
        textColor: TwoBeeColors.textPrimary,
        child: iconWidget,
      );
    }

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap(index);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? TwoBeeColors.primary.withValues(alpha: 0.16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: iconWidget,
              ),
              const SizedBox(height: 2),
              Text(
                spec.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected
                      ? TwoBeeColors.primary
                      : Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterFab(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (onCenterAction != null) {
          onCenterAction!();
        } else {
          // Default context action
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('Quick Action Menu'),
              duration: Duration(milliseconds: 1200),
            ),
          );
        }
      },
      child: Container(
        width: 48,
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: TwoBeeColors.primary,
          shape: BoxShape.circle,
          boxShadow: TwoBeeShadows.emeraldGlow,
          border: Border.all(color: TwoBeeColors.obsidian, width: 2),
        ),
        child: const Icon(
          Icons.add_rounded,
          color: TwoBeeColors.textPrimary,
          size: 28,
        ),
      ),
    );
  }
}
