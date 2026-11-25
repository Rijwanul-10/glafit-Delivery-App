import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/twobee_theme.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/common_widgets.dart';
import '../common/shared_screens.dart';
import 'client_food_screens.dart';
import 'client_parcel_screens.dart';
import 'client_ride_screens.dart';

class ClientShell extends ConsumerStatefulWidget {
  const ClientShell({super.key});

  @override
  ConsumerState<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends ConsumerState<ClientShell> {
  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(clientTabIndexProvider);
    final pages = [
      _ClientHomeTab(onOpenActivity: () => ref.read(clientTabIndexProvider.notifier).state = 1),
      const _ClientActivityTab(),
      const _ClientWalletTab(),
      const _ClientProfileTab(),
    ];

    return Scaffold(
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: AppBottomNav(
        role: AppUserRole.client,
        currentIndex: tab,
        onTap: (i) => ref.read(clientTabIndexProvider.notifier).state = i,
      ),
    );
  }
}

class _ClientHomeTab extends ConsumerStatefulWidget {
  final VoidCallback onOpenActivity;
  const _ClientHomeTab({required this.onOpenActivity});

  @override
  ConsumerState<_ClientHomeTab> createState() => _ClientHomeTabState();
}

class _ClientHomeTabState extends ConsumerState<_ClientHomeTab> {
  Map<String, dynamic>? _home;
  String _selectedZone = 'Banani, Dhaka';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/client/home');
      setState(() => _home = res);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _home?['greetingName'] ?? 'Customer';
    final activeCount = (_home?['activeSummary']?['totalActive'] as int?) ?? 0;
    final trending = (_home?['trendingMerchants'] as List?) ?? [];

    return Scaffold(
      backgroundColor: TwoBeeColors.scaffoldBg,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Top Deep Forest Obsidian Header Card (Pathao & Neo-Tactile Inspired)
            Container(
              decoration: const BoxDecoration(
                color: TwoBeeColors.obsidian,
                borderRadius: TwoBeeRadii.headerBottom,
                boxShadow: TwoBeeShadows.dockNav,
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: 2Bee Logo + EcoPoints Pill + Bell + Avatar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 2Bee Logo + City Zone Dropdown (Wrapped in Expanded to prevent overflow on mobile)
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                final zones = (_home?['zones'] as List?) ?? [];
                                showModalBottomSheet(
                                  context: context,
                                  shape: const RoundedRectangleBorder(borderRadius: TwoBeeRadii.sheetTop),
                                  builder: (ctx) => ListView(
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    children: zones.map((z) {
                                      return ListTile(
                                        leading: const Icon(Icons.location_on_rounded, color: TwoBeeColors.primary),
                                        title: Text('${z['name']}, Dhaka', style: const TextStyle(fontWeight: FontWeight.w700)),
                                        onTap: () {
                                          setState(() => _selectedZone = '${z['name']}, Dhaka');
                                          Navigator.pop(ctx);
                                        },
                                      );
                                    }).toList(),
                                  ),
                                );
                              },
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: TwoBeeColors.primary,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: TwoBeeShadows.emeraldGlow,
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.electric_bolt_rounded, color: TwoBeeColors.obsidian, size: 20),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Hello, $greeting 👋',
                                          style: const TextStyle(
                                            color: TwoBeeColors.primarySoft,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.4,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                _selectedZone,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 12,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 2),
                                            const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Colors.white70),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Right Side: EcoPoints Pill + Bell + Avatar
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // EcoPoints Badge (Pathao Points Inspired)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: TwoBeeColors.obsidianCard,
                                  borderRadius: TwoBeeRadii.pill,
                                  border: Border.all(color: TwoBeeColors.primary.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.stars_rounded, color: TwoBeeColors.primary, size: 14),
                                    SizedBox(width: 3),
                                    Text(
                                      '120 pts',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 10,
                                      ),
                                    ),
                                    SizedBox(width: 2),
                                    Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 12),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),

                              // Notification Bell with Pulse Dot
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const NotificationsScreen(roleFilter: 'CLIENT')),
                                ),
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: TwoBeeColors.obsidianCard,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 16),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: TwoBeeColors.primary,
                                            shape: BoxShape.circle,
                                            boxShadow: TwoBeeShadows.emeraldGlow,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),

                              // Profile Avatar
                              GestureDetector(
                                onTap: () => ref.read(clientTabIndexProvider.notifier).state = 3,
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: TwoBeeColors.obsidianCard,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: TwoBeeColors.primary.withValues(alpha: 0.5),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.person_rounded, color: Colors.white, size: 18),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 2Bee Pay / Wallet Banner (Pathao Pay Inspired)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF0C2B1D),
                              TwoBeeColors.obsidianCard,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: TwoBeeColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: TwoBeeColors.primary.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.account_balance_wallet_rounded, color: TwoBeeColors.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Row(
                                    children: [
                                      Text(
                                        '2Bee Pay',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        '• Balance ৳520',
                                        style: TextStyle(
                                          color: TwoBeeColors.primarySoft,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Get exclusive 15% discount on EV rides & food!',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () => ref.read(clientTabIndexProvider.notifier).state = 2,
                              borderRadius: TwoBeeRadii.pill,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: TwoBeeColors.primary,
                                  borderRadius: TwoBeeRadii.pill,
                                  boxShadow: TwoBeeShadows.emeraldGlow,
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Connect',
                                      style: TextStyle(
                                        color: TwoBeeColors.obsidian,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11,
                                      ),
                                    ),
                                    SizedBox(width: 2),
                                    Icon(Icons.chevron_right_rounded, color: TwoBeeColors.obsidian, size: 14),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Content Body (Pathao Structure with Neo-Tactile 2Bee Theme)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. SERVICES GRID IN MIDDLE (2Bee Core 3 Services: Bike, Food, Parcel)
                  Row(
                    children: [
                      // Bike Service Card (2Bee EV Solo & Express Ride)
                      Expanded(
                        child: _PathaoServiceCard(
                          title: 'Bike',
                          subtitle: 'Fast 100% EV solo commute',
                          badgeText: 'EV SOLO',
                          badgeColor: TwoBeeColors.primary,
                          icon: Icons.two_wheeler_rounded,
                          accentColor: const Color(0xFFE8F5E9),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RideLocationScreen())),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Food Service Card (Kitchens & Fresh Delivery)
                      Expanded(
                        child: _PathaoServiceCard(
                          title: 'Food',
                          subtitle: 'Delivered fresh from kitchens',
                          badgeText: 'FREE DELIVERY',
                          badgeColor: TwoBeeColors.primary,
                          icon: Icons.fastfood_rounded,
                          accentColor: const Color(0xFFFFF3E0),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodHomeScreen())),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Parcel Service Card (P2P Express Door-to-Door Courier)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ParcelHubScreen())),
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: TwoBeeColors.surfaceCard,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: TwoBeeShadows.softCard,
                          border: Border.all(color: TwoBeeColors.borderSoft),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFF8E1),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Icon(Icons.inventory_2_rounded, color: TwoBeeColors.obsidian, size: 28),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Parcel',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFF9100).withValues(alpha: 0.12),
                                          borderRadius: TwoBeeRadii.pill,
                                        ),
                                        child: const Text(
                                          'P2P EXPRESS',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFFFF9100),
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Direct 1-on-1 door-to-door courier · No hub delay',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: TwoBeeColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: TwoBeeColors.surfaceTonal,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_forward_rounded, color: TwoBeeColors.primary, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. ACTIVE DELIVERY CARD (Positioned DIRECTLY AFTER Services Grid)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: TwoBeeColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: TwoBeeShadows.emeraldGlow,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Active delivery',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: widget.onOpenActivity,
                        child: Text(
                          activeCount > 0 ? 'View All ($activeCount)' : 'Activity',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: TwoBeeColors.primaryAccent),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // High-Contrast Waypoint Card (Matching Pathao + Ref 1 & 2)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: TwoBeeColors.surfaceCard,
                      borderRadius: TwoBeeRadii.card,
                      boxShadow: TwoBeeShadows.softCard,
                      border: Border.all(color: TwoBeeColors.borderSoft),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: TwoBeeColors.surfaceTonal,
                                    borderRadius: TwoBeeRadii.inner,
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.inventory_2_rounded, color: TwoBeeColors.primary, size: 24),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('ID: #70D2000B', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: TwoBeeColors.textSecondary, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text(
                                      activeCount > 0 ? '$activeCount Active Shipment(s)' : 'Mac Mini M4 Pro',
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: TwoBeeColors.primary.withValues(alpha: 0.15),
                                borderRadius: TwoBeeRadii.pill,
                              ),
                              child: const Text(
                                'In Transit',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: TwoBeeColors.primaryAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Route Waypoint Timeline
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text('📍 Banani Hub', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: TwoBeeColors.textSecondary)),
                            Text('18 mins away', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: TwoBeeColors.primaryAccent)),
                            Text('🏠 Gulshan-2', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: TwoBeeColors.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Dotted / Progress track
                        Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: TwoBeeColors.surfaceTonal,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: 0.65,
                              child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: TwoBeeColors.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: TwoBeeColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            // In-transit pulsing node
                            Positioned(
                              left: 170,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: TwoBeeColors.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: TwoBeeShadows.emeraldGlow,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Rider: Richard Dheo (EV-04)',
                              style: TextStyle(fontSize: 12, color: TwoBeeColors.textSecondary, fontWeight: FontWeight.w600),
                            ),
                            InkWell(
                              onTap: () {
                                final activeItems = (_home?['activeSummary']?['recentActive'] as List?) ?? [];
                                if (activeItems.isNotEmpty) {
                                  widget.onOpenActivity();
                                } else {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceiverParcelTrackingScreen(parcelId: 'mock-sample-active')));
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: TwoBeeColors.primary,
                                  borderRadius: TwoBeeRadii.pill,
                                  boxShadow: TwoBeeShadows.emeraldGlow,
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Live Track', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: TwoBeeColors.obsidian)),
                                    SizedBox(width: 4),
                                    Icon(Icons.arrow_forward_rounded, size: 14, color: TwoBeeColors.obsidian),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. "TAKE A RIDE TO" DESTINATION MODULE (Pathao Benchmark)
                  const Text('Take an EV Ride to', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                  const SizedBox(height: 10),
                  // Destination Search Bar
                  InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RideLocationScreen())),
                    borderRadius: TwoBeeRadii.pill,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      decoration: BoxDecoration(
                        color: TwoBeeColors.surfaceCard,
                        borderRadius: TwoBeeRadii.pill,
                        border: Border.all(color: TwoBeeColors.borderSoft),
                        boxShadow: TwoBeeShadows.softCard,
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.search_rounded, color: TwoBeeColors.primary, size: 22),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Search destination (Gulshan, Uttara, Dhanmondi)...',
                              style: TextStyle(color: TwoBeeColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Home & Work Shortcut Chips
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RideLocationScreen())),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: TwoBeeColors.surfaceCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: TwoBeeColors.borderSoft),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: TwoBeeColors.surfaceTonal,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.home_rounded, color: TwoBeeColors.primary, size: 20),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Home', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                                      Text('Banani Road 11', style: TextStyle(color: TwoBeeColors.textSecondary, fontSize: 10), overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RideLocationScreen())),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: TwoBeeColors.surfaceCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: TwoBeeColors.borderSoft),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: TwoBeeColors.surfaceTonal,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.work_rounded, color: TwoBeeColors.primary, size: 20),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Work', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                                      Text('Gulshan 2 Circle', style: TextStyle(color: TwoBeeColors.textSecondary, fontSize: 10), overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Recent Trips List
                  Container(
                    decoration: BoxDecoration(
                      color: TwoBeeColors.surfaceCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: TwoBeeColors.borderSoft),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.history_rounded, color: TwoBeeColors.textSecondary, size: 20),
                          title: const Text('Gulshan-2 Police Plaza', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          subtitle: const Text('Gulshan Avenue, Dhaka', style: TextStyle(fontSize: 11)),
                          trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: TwoBeeColors.textSecondary),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RideLocationScreen())),
                        ),
                        const Divider(height: 1, indent: 48),
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.history_rounded, color: TwoBeeColors.textSecondary, size: 20),
                          title: const Text('Uttara Sector 3 Jashimuddin', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          subtitle: const Text('Airport Road, Dhaka', style: TextStyle(fontSize: 11)),
                          trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: TwoBeeColors.textSecondary),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RideLocationScreen())),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 4. "SEARCH FOR FOOD" & CATEGORY PILLS (Pathao Benchmark)
                  const Text('Search for Food', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                  const SizedBox(height: 10),
                  // Food Search Bar
                  InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodSearchScreen())),
                    borderRadius: TwoBeeRadii.pill,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      decoration: BoxDecoration(
                        color: TwoBeeColors.surfaceCard,
                        borderRadius: TwoBeeRadii.pill,
                        border: Border.all(color: TwoBeeColors.borderSoft),
                        boxShadow: TwoBeeShadows.softCard,
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.restaurant_menu_rounded, color: TwoBeeColors.primary, size: 22),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Search for \'Biryani\', \'Burger\', \'Kebab\'...',
                              style: TextStyle(color: TwoBeeColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Circular Food Category Avatars (Pathao Food Row)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _FoodCategoryItem(name: 'Biryani', icon: '🍲', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodSearchScreen()))),
                        _FoodCategoryItem(name: 'Burger', icon: '🍔', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodSearchScreen()))),
                        _FoodCategoryItem(name: 'Pizza', icon: '🍕', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodSearchScreen()))),
                        _FoodCategoryItem(name: 'Bengali', icon: '🍛', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodSearchScreen()))),
                        _FoodCategoryItem(name: 'Fast Food', icon: '🍟', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodSearchScreen()))),
                        _FoodCategoryItem(name: 'Healthy', icon: '🥗', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodSearchScreen()))),
                        _FoodCategoryItem(name: 'Coffee', icon: '☕', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodSearchScreen()))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // 5. "ORDER AGAIN" CARD (Pathao Benchmark)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Order again', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                      TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodHomeScreen())),
                        child: const Text('View All', style: TextStyle(fontWeight: FontWeight.w800, color: TwoBeeColors.primaryAccent)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: TwoBeeColors.surfaceCard,
                      borderRadius: TwoBeeRadii.card,
                      border: Border.all(color: TwoBeeColors.borderSoft),
                      boxShadow: TwoBeeShadows.softCard,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Center(
                                child: Text('🍗', style: TextStyle(fontSize: 24)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Kacchi Bhai - Uttara', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                                      Text('৳283', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: TwoBeeColors.primaryAccent)),
                                    ],
                                  ),
                                  SizedBox(height: 2),
                                  Text('Delivery order • 16 MAY 2026, 02:24 PM', style: TextStyle(fontSize: 11, color: TwoBeeColors.textSecondary)),
                                  SizedBox(height: 2),
                                  Text('Bashmoti Kacchi x1', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: TwoBeeColors.surfaceTonal,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.local_offer_rounded, size: 14, color: TwoBeeColors.primaryAccent),
                              SizedBox(width: 6),
                              Text('Ongoing offers • Code: SHERADEAL30', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: TwoBeeColors.primaryAccent)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TwoBeeColors.primary,
                            foregroundColor: TwoBeeColors.obsidian,
                            minimumSize: const Size.fromHeight(42),
                            shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
                            elevation: 0,
                          ),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodHomeScreen())),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.refresh_rounded, size: 18),
                              SizedBox(width: 6),
                              Text('Select items and reorder', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 6. TRENDING RESTAURANTS / KITCHENS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Trending Kitchens', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                      TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodHomeScreen())),
                        child: const Text('See all', style: TextStyle(fontWeight: FontWeight.w800, color: TwoBeeColors.primaryAccent)),
                      ),
                    ],
                  ),
                  if (_loading)
                    const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                  else
                    ...trending.map((m) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: TwoBeeColors.surfaceCard,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: TwoBeeColors.borderSoft),
                            boxShadow: TwoBeeShadows.softCard,
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: TwoBeeColors.surfaceTonal,
                                borderRadius: TwoBeeRadii.inner,
                              ),
                              child: const Icon(Icons.storefront_rounded, color: TwoBeeColors.primary, size: 22),
                            ),
                            title: Row(
                              children: [
                                Expanded(child: Text(m['businessName'].toString(), style: const TextStyle(fontWeight: FontWeight.w800))),
                                if (m['merchantType'] == 'HOME_KITCHEN')
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: TwoBeeColors.surfaceTonal, borderRadius: BorderRadius.circular(6)),
                                    child: const Text('Home Kitchen', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: TwoBeeColors.primaryAccent)),
                                  ),
                              ],
                            ),
                            subtitle: Text('★ ${m['rating']} · ${m['avgPrepMins']}m · Fee ${bdt(m['deliveryFeeBdt'] ?? 45)}', style: const TextStyle(color: TwoBeeColors.textSecondary, fontSize: 12)),
                            trailing: const Icon(Icons.chevron_right_rounded, color: TwoBeeColors.textSecondary),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => RestaurantDetailScreen(merchantId: m['id'] as String)),
                            ),
                          ),
                        )),
                  const SizedBox(height: 20),

                  // 7. INVITE FRIENDS & GET DISCOUNT (Pathao Benchmark)
                  const Text('Invite Friends & Get Discount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _InviteCard(
                          title: 'Invite on Ride',
                          description: 'Share this code with friends. They get ৳100 off.',
                          promoCode: '2BEE-RIDE',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _InviteCard(
                          title: 'Invite on Food',
                          description: 'Share with hungry friends & get ৳150 off each order.',
                          promoCode: '2BEE-FOOD',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 8. FOOTER WITH CITY EMBLEM & "BACK TO TOP" (Pathao Style)
                  Center(
                    child: Column(
                      children: [
                        const Text('⚡ 100% Zero-Emission Fleet', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: TwoBeeColors.primaryAccent, letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        const Text('Crafted with 💚 for Clean Dhaka', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: TwoBeeColors.textSecondary)),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: TwoBeeColors.borderSoft),
                            shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          onPressed: () {},
                          icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 18),
                          label: const Text('Back to top', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PathaoServiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badgeText;
  final Color badgeColor;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _PathaoServiceCard({
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.badgeColor,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 140,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: TwoBeeColors.surfaceCard,
            borderRadius: BorderRadius.circular(22),
            boxShadow: TwoBeeShadows.softCard,
            border: Border.all(color: TwoBeeColors.borderSoft),
          ),
          child: Stack(
            children: [
              // Text Content
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge (EV SOLO / FREE DELIVERY / P2P EXPRESS)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: TwoBeeRadii.pill,
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: badgeColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    width: 95,
                    child: Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        color: TwoBeeColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // 3D / Flat Illustration Icon in Lower-Right
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(icon, color: TwoBeeColors.obsidian, size: 30),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoodCategoryItem extends StatelessWidget {
  final String name;
  final String icon;
  final VoidCallback onTap;

  const _FoodCategoryItem({
    required this.name,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: TwoBeeColors.surfaceCard,
                shape: BoxShape.circle,
                border: Border.all(color: TwoBeeColors.borderSoft),
                boxShadow: TwoBeeShadows.softCard,
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: TwoBeeColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  final String title;
  final String description;
  final String promoCode;

  const _InviteCard({
    required this.title,
    required this.description,
    required this.promoCode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TwoBeeColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TwoBeeColors.borderSoft),
        boxShadow: TwoBeeShadows.softCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(fontSize: 10, color: TwoBeeColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: TwoBeeColors.surfaceTonal,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: TwoBeeColors.borderSoft),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(promoCode, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: 11)),
                const Icon(Icons.copy_rounded, size: 14, color: TwoBeeColors.textSecondary),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TwoBeeColors.primary,
              foregroundColor: TwoBeeColors.obsidian,
              minimumSize: const Size.fromHeight(34),
              shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
              padding: EdgeInsets.zero,
              elevation: 0,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied referral code $promoCode!')));
            },
            child: const Text('Invite', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}


class _ClientActivityTab extends ConsumerStatefulWidget {
  const _ClientActivityTab();

  @override
  ConsumerState<_ClientActivityTab> createState() => _ClientActivityTabState();
}

class _ClientActivityTabState extends ConsumerState<_ClientActivityTab> {
  String _filter = 'ALL';
  bool _showActive = true;
  List<dynamic> _active = [];
  List<dynamic> _past = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/client/activity', query: {'type': _filter});
      setState(() {
        _active = (res['active'] as List?) ?? [];
        _past = (res['past'] as List?) ?? [];
      });
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openItem(Map item) {
    final svc = item['serviceType'] as String;
    final id = item['id'] as String;
    final status = item['status']?.toString() ?? '';
    if (svc == 'FOOD') {
      if (['DELIVERED', 'CANCELLED', 'REJECTED'].contains(status)) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ClientOrderDetailScreen(orderId: id)));
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => FoodLiveTrackingScreen(orderId: id)));
      }
    } else if (svc == 'PARCEL') {
      final isReceiver = item['isReceiver'] == true || item['type'] == 'INCOMING';
      if (isReceiver) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiverParcelTrackingScreen(parcelId: id, isDeliveredHistory: status == 'DELIVERED')));
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ParcelTrackingScreen(parcelId: id)));
      }
    } else {
      if (status == 'MATCHING') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => RideMatchingRadarScreen(tripId: id)));
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => RideActiveTripScreen(tripId: id)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _showActive ? _active : _past;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          const TwoBeeHomeAction(),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text('Active (${_active.length})')),
                ButtonSegment(value: false, label: Text('Past (${_past.length})')),
              ],
              selected: {_showActive},
              onSelectionChanged: (v) => setState(() => _showActive = v.first),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: ['ALL', 'FOOD', 'PARCEL', 'RIDE'].map((t) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(t),
                    selected: _filter == t,
                    onSelected: (_) {
                      setState(() => _filter = t);
                      _load();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.receipt_long_outlined, size: 48, color: TwoBeeColors.textSecondary),
                            const SizedBox(height: 8),
                            Text(_showActive ? 'No active bookings right now' : 'No completed activity yet'),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final x = list[i] as Map;
                            final svc = x['serviceType'] as String;
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: TwoBeeColors.surfaceTonal,
                                  child: Icon(
                                    svc == 'FOOD'
                                        ? Icons.restaurant
                                        : svc == 'PARCEL'
                                            ? Icons.inventory_2
                                            : Icons.two_wheeler,
                                    color: TwoBeeColors.primary,
                                  ),
                                ),
                                title: Text('${x['code']} · ${x['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text('${x['subtitle']}\nStatus: ${x['status']}'),
                                isThreeLine: true,
                                trailing: Text(bdt(x['amountBdt'] ?? 0), style: const TextStyle(fontWeight: FontWeight.w800, color: TwoBeeColors.primary)),
                                onTap: () => _openItem(x),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ClientWalletTab extends ConsumerStatefulWidget {
  const _ClientWalletTab();

  @override
  ConsumerState<_ClientWalletTab> createState() => _ClientWalletTabState();
}

class _ClientWalletTabState extends ConsumerState<_ClientWalletTab> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/client/wallet');
      setState(() => _data = res);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _topUp() async {
    const amount = 500;
    final ok = await showStripeSandboxDialog(context, amountBdt: amount, title: 'Top up 2Bee Client Wallet');
    if (!ok) return;
    final api = ref.read(apiClientProvider);
    final intent = await api.post('/client/wallet/topup/stripe-intent', body: {'amountBdt': amount});
    await api.post('/client/wallet/topup/confirm', body: {'paymentIntentId': intent['paymentIntentId'], 'amountBdt': amount});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added ৳500 via Stripe Sandbox!')));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = (_data?['wallet'] as Map?) ?? {};
    final txs = (wallet['transactions'] as List?) ?? [];
    final vouchers = (_data?['vouchers'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet'), actions: const [TwoBeeHomeAction()]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: TwoBeeColors.obsidian, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('2Bee Wallet Balance', style: TextStyle(color: TwoBeeColors.primarySoft, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(bdt(wallet['balanceBdt'] ?? 0), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: _topUp,
                          icon: const Icon(Icons.add_card_rounded),
                          label: const Text('Top Up ৳500 (Stripe Sandbox)'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  PaymentSelectorCard(selectedMethod: 'STRIPE_SANDBOX', showCod: false, onSelected: (_) {}),
                  const SizedBox(height: 16),
                  const Text('Active Promo Vouchers', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 8),
                  if (vouchers.isEmpty)
                    const Text('No active promos.', style: TextStyle(color: TwoBeeColors.textSecondary))
                  else
                    ...vouchers.map((v) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.local_offer_outlined, color: TwoBeeColors.primary),
                            title: Text('${v['promoCode']} · ${v['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('Min order ${bdt(v['minOrderBdt'] ?? 0)}'),
                          ),
                        )),
                  const SizedBox(height: 16),
                  const Text('Transaction History', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 8),
                  if (txs.isEmpty)
                    const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No wallet transactions yet.')))
                  else
                    ...txs.map((t) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(t['description']?.toString() ?? ''),
                            subtitle: Text(t['referenceCode']?.toString() ?? ''),
                            trailing: Text(
                              '${(t['amountBdt'] as num) >= 0 ? '+' : ''}${bdt(t['amountBdt'] as num)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: (t['amountBdt'] as num) >= 0 ? TwoBeeColors.primary : TwoBeeColors.errorText,
                              ),
                            ),
                          ),
                        )),
                ],
              ),
            ),
    );
  }
}

class _ClientProfileTab extends ConsumerWidget {
  const _ClientProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), actions: const [TwoBeeHomeAction()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                radius: 26,
                backgroundColor: TwoBeeColors.surfaceTonal,
                child: Icon(Icons.person_rounded, color: TwoBeeColors.primary, size: 28),
              ),
              title: Text(user?['fullName']?.toString() ?? '2Bee Customer', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${user?['phone'] ?? ''} · ${user?['email'] ?? 'Tap Edit to add email'}'),
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined, color: TwoBeeColors.primary),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditClientProfileScreen())),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.location_on_outlined, color: TwoBeeColors.primary),
                  title: const Text('Saved Addresses (Home, Work, Airport)'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedAddressesScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.favorite_border_rounded, color: TwoBeeColors.primary),
                  title: const Text('Favorites (Restaurants & Dishes)'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_none_rounded, color: TwoBeeColors.primary),
                  title: const Text('Notifications'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen(roleFilter: 'CLIENT'))),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help_outline_rounded, color: TwoBeeColors.primary),
                  title: const Text('Help, Terms & Legal'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportLegalScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.emergency_outlined, color: TwoBeeColors.errorText),
                  title: const Text('Emergency SOS & Support'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showSosSafetySheet(context, ref, role: 'CLIENT'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.swap_horiz_rounded, color: TwoBeeColors.primary),
                  title: const Text('Switch Role (Client / Rider / Restaurant)'),
                  subtitle: const Text('Same verified phone, role passcode protected'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.go('/roles'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.account_tree_outlined, color: TwoBeeColors.primary),
                  title: const Text('Preview All 2Bee Screens & Step Flows'),
                  subtitle: const Text('Jump to any step across Client, Rider & Merchant'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/screens'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: TwoBeeColors.errorText, side: const BorderSide(color: TwoBeeColors.errorText)),
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}

class EditClientProfileScreen extends ConsumerStatefulWidget {
  const EditClientProfileScreen({super.key});

  @override
  ConsumerState<EditClientProfileScreen> createState() => _EditClientProfileScreenState();
}

class _EditClientProfileScreenState extends ConsumerState<EditClientProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = ref.read(authControllerProvider).user;
    _nameCtrl.text = u?['fullName']?.toString() ?? '';
    _emailCtrl.text = u?['email']?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile'), actions: const [TwoBeeHomeAction()]),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
            const SizedBox(height: 12),
            TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email Address (optional)')),
            const Spacer(),
            ElevatedButton(
              onPressed: _saving
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      await ref.read(apiClientProvider).patch('/client/profile', body: {
                        'fullName': _nameCtrl.text.trim(),
                        'email': _emailCtrl.text.trim(),
                      });
                      await ref.read(authControllerProvider.notifier).refreshRoles();
                      if (context.mounted) Navigator.pop(context);
                    },
              child: Text(_saving ? 'Saving...' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}

class SavedAddressesScreen extends ConsumerStatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  ConsumerState<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends ConsumerState<SavedAddressesScreen> {
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/client/addresses');
      setState(() => _items = (res['items'] as List?) ?? []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addAddress() async {
    final labelCtrl = TextEditingController(text: 'Work');
    final addrCtrl = TextEditingController();
    String zoneId = 'zone-banani';
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Add Saved Address'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: labelCtrl, decoration: const InputDecoration(labelText: 'Label (Home / Work / Other)')),
              const SizedBox(height: 8),
              TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Street / House Address')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: zoneId,
                decoration: const InputDecoration(labelText: 'Dhaka Zone'),
                items: const [
                  DropdownMenuItem(value: 'zone-banani', child: Text('Banani')),
                  DropdownMenuItem(value: 'zone-gulshan', child: Text('Gulshan')),
                  DropdownMenuItem(value: 'zone-uttara', child: Text('Uttara')),
                  DropdownMenuItem(value: 'zone-dhanmondi', child: Text('Dhanmondi')),
                  DropdownMenuItem(value: 'zone-mirpur', child: Text('Mirpur')),
                ],
                onChanged: (v) => setS(() => zoneId = v ?? 'zone-banani'),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                if (addrCtrl.text.trim().length < 3) return;
                await ref.read(apiClientProvider).post('/client/addresses', body: {
                  'label': labelCtrl.text.trim(),
                  'address': addrCtrl.text.trim(),
                  'zoneId': zoneId,
                  'lat': 23.7937,
                  'lng': 90.4066,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('Save Address'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Addresses'), actions: const [TwoBeeHomeAction()]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: TwoBeeColors.primary,
        foregroundColor: Colors.white,
        onPressed: _addAddress,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add Address'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('No saved addresses yet.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final a = _items[i] as Map;
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.location_on_outlined, color: TwoBeeColors.primary),
                        title: Text(a['label']?.toString() ?? 'Address', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(a['address']?.toString() ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: TwoBeeColors.errorText),
                          onPressed: () async {
                            await ref.read(apiClientProvider).delete('/client/addresses/${a['id']}');
                            _load();
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

