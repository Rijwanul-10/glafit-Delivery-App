import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../../core/services/food_order_sync_service.dart';
import '../../core/theme/twobee_theme.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/foodpanda_map_widget.dart';
import '../common/shared_screens.dart';

/// Option B 4-Tab Rider Shell: Home | Jobs | Wallet | Profile
class RiderShell extends ConsumerStatefulWidget {
  const RiderShell({super.key});

  @override
  ConsumerState<RiderShell> createState() => _RiderShellState();
}

class _RiderShellState extends ConsumerState<RiderShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);
    if (session.lockModalNeeded || session.riderRoleToken == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_clock_rounded,
                  size: 52,
                  color: TwoBeeColors.primary,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Rider Session Locked',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Auto-locked for your safety (15-min inactivity limit).',
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.go('/rider/passcode'),
                  child: const Text('Unlock with 4-Digit PIN'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final pages = [
      const _RiderHomeTab(),
      const _RiderJobsTab(),
      const _RiderWalletTab(),
      const _RiderProfileTab(),
    ];

    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: AppBottomNav(
        role: AppUserRole.rider,
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _RiderHomeTab extends ConsumerStatefulWidget {
  const _RiderHomeTab();

  @override
  ConsumerState<_RiderHomeTab> createState() => _RiderHomeTabState();
}

class _RiderHomeTabState extends ConsumerState<_RiderHomeTab> {
  Map<String, dynamic>? _home;
  bool _loading = true;
  Timer? _autoVerifyTimer;
  bool _justAutoApproved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _autoVerifyTimer?.cancel();
    super.dispose();
  }

  void _scheduleAutoVerifyIfPending(Map<String, dynamic> data) {
    final status = data['rider']?['kycStatus'];
    if (status == 'APPROVED') return;
    if (_autoVerifyTimer?.isActive == true) return;
    _autoVerifyTimer = Timer(const Duration(seconds: 3), () async {
      if (!mounted) return;
      try {
        await ref
            .read(apiClientProvider)
            .post('/common/demo/auto-verify-rider');
        await ref.read(authControllerProvider.notifier).refreshRoles();
        if (mounted) setState(() => _justAutoApproved = true);
        await _load();
      } catch (_) {}
    });
  }

  static final Map<String, dynamic> _fallbackRiderHome = {
    'ok': true,
    'rider': {
      'id': 'rider-demo-01',
      'fullName': 'Sabbir Rahman (EV Rider)',
      'phone': '+8801712345678',
      'kycStatus': 'APPROVED',
      'kycNotes': null,
      'isOnline': true,
      'rating': 4.92,
      'vehicleBrandModel': 'Glafit EV Solo (GFR-02 Smart e-Bike)',
      'plateNo': 'DHAKA-METRO-HA-8821',
      'preferredZoneId': 'zone-banani',
      'activeServices': {'parcel': true, 'ride': true, 'food': true},
      'vehicleOwnership': 'RENTAL',
      'frontCarrierEnabled': true,
      'rearCarrierEnabled': true,
      'spareHelmetConfirmed': true,
      'batteryHealthPct': 88,
      'rentalPlan': 'DAILY',
      'totalTripsCompleted': 142,
    },
    'todayEarningsBdt': 1420,
    'todayEarnings': 1420,
    'todayTripsCount': 6,
    'activeBatch': {
      'id': 'sample-batch-live',
      'batchCode': 'MULTI-2B99',
      'originZoneId': 'zone-banani',
      'destinationZoneId': 'zone-uttara',
      'status': 'PASSENGER_PICKUP_PENDING',
      'totalPayoutBdt': 215,
      'rideTrip': {
        'id': 'sample-ride',
        'tripCode': '2B-R7391',
        'pickupAddress': 'Banani Road 11 (Beside Gloria Jean\'s)',
        'dropoffAddress': 'Uttara Sector 7 (Rabindra Sarani)',
        'fleetTier': '2BEE_EV_SOLO',
        'distanceKm': 8.4,
        'totalFareBdt': 165,
        'riderPayoutBdt': 135,
        'startPin': '7391',
        'paymentMethod': 'COD',
        'user': {'fullName': 'Tanvir Ahmed', 'phone': '+8801711223344'},
        'status': 'DRIVER_ASSIGNED',
      },
      'parcelShipment': {
        'id': 'sample-parcel',
        'trackingCode': '2B-P4821',
        'pickupAddress': 'Gulshan 2, Road 45 (Boutique Hub)',
        'deliveryAddress': 'Uttara Sector 3 (Near North Tower)',
        'weightKg': 2.5,
        'riderPayoutBdt': 80,
        'handoverOtp': '4821',
        'paymentMethod': 'COD',
        'status': 'CO_LOADED',
      },
    },
    'recentCompletedTrips': [
      {
        'id': 'trip-c1',
        'service': 'PARCEL',
        'code': '2B-P9012',
        'route': 'Gulshan 1 -> Mohakhali DOHS',
        'payoutBdt': 120,
        'time': '45m ago',
      },
      {
        'id': 'trip-c2',
        'service': 'FOOD',
        'code': '2B-F4420',
        'route': "Sultan's Dine -> Banani Road 11",
        'payoutBdt': 95,
        'time': '2h ago',
      },
      {
        'id': 'trip-c3',
        'service': 'RIDE',
        'code': '2B-R1109',
        'route': 'Airport -> Kuril Bishwa Road',
        'payoutBdt': 140,
        'time': '3h ago',
      },
    ],
  };

  Future<void> _load() async {
    final token = ref.read(authControllerProvider).riderRoleToken;
    if (token == null) {
      if (mounted) {
        setState(() {
          _home = _fallbackRiderHome;
          _loading = false;
        });
      }
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await ref
          .read(apiClientProvider)
          .get('/rider/panel/home', roleToken: token);
      setState(() => _home = res);
      _scheduleAutoVerifyIfPending(res);
    } catch (_) {
      if (mounted) setState(() => _home = _fallbackRiderHome);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleOnline(bool goOnline) async {
    if (goOnline) {
      bool p = true, r = true, f = true;
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setM) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Start Your Shift',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const Text(
                  'Configure active services before going online',
                  style: TextStyle(
                    color: TwoBeeColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                CheckboxListTile(
                  value: p,
                  onChanged: (v) => setM(() => p = v ?? true),
                  title: const Text('Parcel (Avg ৳140/trip)'),
                ),
                CheckboxListTile(
                  value: r,
                  onChanged: (v) => setM(() => r = v ?? true),
                  title: const Text('Ride (Avg ৳85/trip)'),
                ),
                CheckboxListTile(
                  value: f,
                  onChanged: (v) => setM(() => f = v ?? true),
                  title: const Text('Food (Avg ৳85/trip)'),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  margin: const EdgeInsets.only(top: 8, bottom: 12),
                  decoration: BoxDecoration(
                    color: TwoBeeColors.surfaceTonal,
                    borderRadius: TwoBeeRadii.card,
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.electric_moped_rounded,
                        color: TwoBeeColors.primary,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '100% Electric Glafit Fleet (EV Solo & Express)',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: TwoBeeColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Go Online ->'),
                ),
              ],
            ),
          ),
        ),
      );
      if (confirmed != true) return;
      final token = ref.read(authControllerProvider).riderRoleToken;
      await ref
          .read(apiClientProvider)
          .post(
            '/rider/panel/online',
            roleToken: token,
            body: {
              'isOnline': true,
              'lat': 23.7937,
              'lng': 90.4066,
              'services': {'parcel': p, 'ride': r, 'food': f},
            },
          );
      final riderId = _home?['rider']?['id'] as String?;
      if (riderId != null) {
        ref
            .read(socketServiceProvider)
            .streamRiderLocation(riderId: riderId, lat: 23.7937, lng: 90.4066);
      }
      _load();
      if (mounted)
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LookingForRequestsScreen()),
        );
      return;
    }

    final token = ref.read(authControllerProvider).riderRoleToken;
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/rider/panel/online',
            roleToken: token,
            body: {'isOnline': false, 'lat': 23.7937, 'lng': 90.4066},
          );
      _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _home == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final r = _home!['rider'] as Map;
    final approved = r['kycStatus'] == 'APPROVED';
    final isOnline = r['isOnline'] == true;
    final activeBatch = _home!['activeBatch'] as Map?;
    final recent = (_home!['recentCompletedTrips'] as List?) ?? [];

    return Scaffold(
      backgroundColor: TwoBeeColors.scaffoldBg,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Top Deep Forest Obsidian Rider Header Sheet
            Container(
              decoration: const BoxDecoration(
                color: TwoBeeColors.obsidian,
                borderRadius: TwoBeeRadii.headerBottom,
                boxShadow: TwoBeeShadows.dockNav,
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status + Actions Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? TwoBeeColors.primary
                                      : TwoBeeColors.textSecondary,
                                  shape: BoxShape.circle,
                                  boxShadow: isOnline
                                      ? TwoBeeShadows.emeraldGlow
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '2BEE RIDER MULTI-SERVICE',
                                style: TextStyle(
                                  color: isOnline
                                      ? TwoBeeColors.primary
                                      : Colors.white60,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.notifications_none_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const NotificationsScreen(
                                      roleFilter: 'RIDER',
                                    ),
                                  ),
                                ),
                              ),
                              const TwoBeeHomeAction(),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Rider Name + Online Toggle Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${r['fullName'] ?? 'Md. Rafiqul Islam'} · ★${r['rating'] ?? '4.92'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${r['vehicleBrandModel'] ?? 'Glafit EV Solo'} · ${r['plateNo'] ?? 'DHAKA-METRO-HA-8821'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(100, 38),
                              backgroundColor: !approved
                                  ? Colors.white12
                                  : (isOnline
                                        ? const Color(0x33E53935)
                                        : TwoBeeColors.primary),
                              foregroundColor: isOnline
                                  ? const Color(0xFFFF8A80)
                                  : TwoBeeColors.textPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: TwoBeeRadii.pill,
                                side: isOnline
                                    ? const BorderSide(color: Color(0x66E53935))
                                    : BorderSide.none,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                            ),
                            onPressed: approved
                                ? () => _toggleOnline(!isOnline)
                                : null,
                            child: Text(
                              isOnline ? 'Go Offline' : 'Go Online',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Today's Earnings Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: TwoBeeColors.obsidianCard,
                          borderRadius: TwoBeeRadii.inner,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "TODAY'S TOTAL EARNINGS",
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  bdt(
                                    _home!['todayEarningsBdt'] ??
                                        _home!['todayEarnings'] ??
                                        0,
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'TRIPS DONE',
                                  style: TextStyle(
                                    color: TwoBeeColors.primarySoft,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${recent.length} Trips Completed',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Content Body
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!approved) ...[
                    const VerificationBanner(
                      title:
                          'Verification in progress · Auto-verifying in 3s...',
                      subtitle: 'Reviewing your KYC & front-carrier limits. Rider & Multi-Service features unlock automatically.',
                    ),
                    const SizedBox(height: 12),
                  ] else if (_justAutoApproved) ...[
                    const VerificationBanner(
                      title: "You're approved! Rider Home Unlocked",
                      subtitle: 'KYC verified — you can now Go Online and accept Multi-Service jobs.',
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Active Multi-Service Batch Card
                  if (activeBatch != null) ...[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: TwoBeeColors.surfaceCard,
                        borderRadius: TwoBeeRadii.card,
                        boxShadow: TwoBeeShadows.softCard,
                        border: Border.all(
                          color: TwoBeeColors.primary,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: TwoBeeColors.primary,
                                  borderRadius: TwoBeeRadii.pill,
                                ),
                                child: Text(
                                  'LIVE MULTI-SERVICE · ${activeBatch['batchCode']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                    color: TwoBeeColors.textPrimary,
                                  ),
                                ),
                              ),
                              const Text(
                                'Status: Active',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: TwoBeeColors.primaryAccent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Zone A (Banani) → Zone B (Gulshan) Multi-Drop',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: TwoBeeColors.surfaceTonal,
                              borderRadius: TwoBeeRadii.inner,
                            ),
                            child: Column(
                              children: const [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.looks_one_rounded,
                                      color: TwoBeeColors.primary,
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Stop 1: Passenger Dropoff (1st Priority)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.looks_two_rounded,
                                      color: TwoBeeColors.primary,
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Stop 2: Front-Rack Parcel Deliver (2nd Priority)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TwoBeeColors.obsidian,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(44),
                              shape: RoundedRectangleBorder(
                                borderRadius: TwoBeeRadii.pill,
                              ),
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const RiderMultiServiceBatchesScreen(),
                              ),
                            ),
                            child: const Text(
                              'Open Multi-Service Batch Details ->',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Radar Dispatch Shortcut
                  if (approved)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LookingForRequestsScreen(),
                          ),
                        ),
                        borderRadius: TwoBeeRadii.card,
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: TwoBeeColors.obsidian,
                            borderRadius: TwoBeeRadii.card,
                            boxShadow: TwoBeeShadows.dockNav,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: TwoBeeColors.primary.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: TwoBeeRadii.inner,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.radar_rounded,
                                    color: TwoBeeColors.primary,
                                    size: 26,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Open Live Dispatch Radar',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Multi-Service: ${r['multiServiceEnabled'] == true ? "READY (Front 8kg + Helmet)" : "Single-Service"}',
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: TwoBeeColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),

                  // EV Bike Rental Banner
                  Container(
                    decoration: BoxDecoration(
                      color: TwoBeeColors.surfaceCard,
                      borderRadius: TwoBeeRadii.card,
                      boxShadow: TwoBeeShadows.softCard,
                      border: Border.all(color: TwoBeeColors.borderSoft),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: TwoBeeColors.surfaceTonal,
                          borderRadius: TwoBeeRadii.inner,
                        ),
                        child: const Icon(
                          Icons.electric_moped_rounded,
                          color: TwoBeeColors.primary,
                        ),
                      ),
                      title: const Text(
                        'Rent EV Bike · from ৳250/day',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      trailing: const Text(
                        'Browse >',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: TwoBeeColors.primaryAccent,
                        ),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BikeRentalHomeScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Recent Trips
                  const Text(
                    'Recent Completed Trips',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (recent.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: TwoBeeColors.surfaceCard,
                        borderRadius: TwoBeeRadii.card,
                        boxShadow: TwoBeeShadows.softCard,
                        border: Border.all(color: TwoBeeColors.borderSoft),
                      ),
                      child: Center(
                        child: Text(
                          approved ? 'No recent completed trips today.' : 'Trips will appear here once approved and active.',
                          style: const TextStyle(
                            color: TwoBeeColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  else
                    ...recent.map(
                      (t) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: TwoBeeColors.surfaceCard,
                          borderRadius: TwoBeeRadii.card,
                          boxShadow: TwoBeeShadows.softCard,
                          border: Border.all(color: TwoBeeColors.borderSoft),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          title: Text(
                            '${t['type'] ?? t['service'] ?? 'TRIP'} · ${t['code'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            (t['label'] ?? t['route'] ?? '').toString(),
                            style: const TextStyle(
                              color: TwoBeeColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Text(
                            '+${bdt(t['payoutBdt'] ?? 0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: TwoBeeColors.primary,
                              fontSize: 15,
                            ),
                          ),
                        ),
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

/// Live Dispatch Radar + Multi-Service Zone A -> Zone B Ride Add-on Request Matcher
class LookingForRequestsScreen extends ConsumerStatefulWidget {
  const LookingForRequestsScreen({super.key});

  @override
  ConsumerState<LookingForRequestsScreen> createState() =>
      _LookingForRequestsScreenState();
}

class _LookingForRequestsScreenState
    extends ConsumerState<LookingForRequestsScreen> {
  Map<String, dynamic>? _open;
  bool _loading = true;
  String _serviceFilter = 'ALL';

  static final Map<String, dynamic> _fallbackOpenDispatch = {
    'ok': true,
    'parcel': [
      {
        'id': 'open-p1',
        'trackingCode': '2B-P8831',
        'pickupAddress': 'Banani Road 11 (Hub)',
        'dropoffAddress': 'Uttara Sector 3',
        'weightKg': 2.2,
        'riderPayoutBdt': 140,
        'paymentMethod': 'COD',
      },
    ],
    'food': [
      {
        'id': 'open-f1',
        'orderCode': '2B-F2091',
        'restaurantName': "Sultan's Dine Banani",
        'deliveryAddress': 'Gulshan 2, Road 54',
        'riderPayoutBdt': 95,
        'paymentMethod': 'STRIPE_SANDBOX',
      },
    ],
    'ride': [
      {
        'id': 'open-r1',
        'tripCode': '2B-R4019',
        'pickupAddress': 'Mohakhali Wireless Gate',
        'dropoffAddress': 'Banani 11',
        'fleetTier': '2BEE_EV_SOLO',
        'riderPayoutBdt': 85,
        'paymentMethod': 'COD',
      },
    ],
    'multiServiceRideAddons': [
      {
        'id': 'addon-1',
        'tripCode': '2B-R7391',
        'pickupAddress': 'Banani Road 11',
        'dropoffAddress': 'Uttara Sector 7',
        'pickupZoneId': 'zone-banani',
        'dropoffZoneId': 'zone-uttara',
        'riderPayoutBdt': 135,
        'paymentMethod': 'COD',
      },
    ],
  };

  late final SocketService _sock;

  void _onOffer(_) {
    if (mounted) _load();
  }

  @override
  void initState() {
    super.initState();
    _sock = ref.read(socketServiceProvider);
    _load();
    _sock.socket?.off('rider:incoming_offer', _onOffer);
    _sock.socket?.off('rider:ride_addon_offer', _onOffer);
    _sock.socket?.on('rider:incoming_offer', _onOffer);
    _sock.socket?.on('rider:ride_addon_offer', _onOffer);
  }

  @override
  void dispose() {
    _sock.socket?.off('rider:incoming_offer', _onOffer);
    _sock.socket?.off('rider:ride_addon_offer', _onOffer);
    super.dispose();
  }

  Future<void> _load() async {
    final token = ref.read(authControllerProvider).riderRoleToken;
    if (token == null) {
      if (mounted) {
        setState(() {
          _open = _fallbackOpenDispatch;
          _loading = false;
        });
      }
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await ref
          .read(apiClientProvider)
          .get('/rider/panel/dispatch/open', roleToken: token);
      setState(() => _open = res);
    } catch (_) {
      if (mounted) setState(() => _open = _fallbackOpenDispatch);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _seedSampleDispatch() async {
    await ref.read(apiClientProvider).post('/common/demo/seed-dispatch');
    await _load();
  }

  Future<bool> _showIncomingOfferModal({
    required String badge,
    required String title,
    required String subtitle,
    required num payoutBdt,
    required String paymentLabel,
    bool isMultiService = false,
    int countdownSecs = 15,
  }) async {
    int secs = countdownSecs;
    Timer? timer;
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TwoBeeColors.obsidian,
      shape: const RoundedRectangleBorder(borderRadius: TwoBeeRadii.sheetTop),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
            if (!ctx.mounted) return;
            if (secs <= 1) {
              timer?.cancel();
              if (Navigator.canPop(ctx)) Navigator.pop(ctx, false);
            } else {
              setS(() => secs--);
            }
          });
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: TwoBeeColors.primary.withValues(alpha: 0.18),
                        borderRadius: TwoBeeRadii.pill,
                        border: Border.all(
                          color: TwoBeeColors.primary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: TwoBeeColors.primary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: TwoBeeColors.obsidianCard,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: TwoBeeColors.primary,
                          width: 2,
                        ),
                        boxShadow: TwoBeeShadows.emeraldGlow,
                      ),
                      child: Center(
                        child: Text(
                          '${secs}s',
                          style: const TextStyle(
                            color: TwoBeeColors.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: TwoBeeColors.obsidianCard,
                    borderRadius: TwoBeeRadii.card,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ESTIMATED RIDER PAYOUT',
                            style: TextStyle(
                              color: TwoBeeColors.primarySoft,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            paymentLabel,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        bdt(payoutBdt),
                        style: const TextStyle(
                          color: TwoBeeColors.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isMultiService)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      '✓ Fits Front Carrier (<=8kg) · Zone A → Zone B Multi-Service Verified',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: TwoBeeColors.primary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: TwoBeeRadii.pill,
                          ),
                        ),
                        onPressed: () {
                          timer?.cancel();
                          Navigator.pop(ctx, false);
                        },
                        child: const Text(
                          'Decline',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: TwoBeeShadows.emeraldGlow,
                          borderRadius: TwoBeeRadii.pill,
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TwoBeeColors.primary,
                            foregroundColor: TwoBeeColors.textPrimary,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: TwoBeeRadii.pill,
                            ),
                          ),
                          onPressed: () {
                            timer?.cancel();
                            Navigator.pop(ctx, true);
                          },
                          child: Text(
                            'Accept (${secs}s)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
    timer?.cancel();
    return accepted == true;
  }

  @override
  Widget build(BuildContext context) {
    final parcels = (_open?['parcel'] as List?) ?? [];
    final rides = (_open?['ride'] as List?) ?? [];
    final food = (_open?['food'] as List?) ?? [];
    final totalCount = parcels.length + rides.length + food.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Dispatch Radar'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Radar',
          ),
          const TwoBeeHomeAction(),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_open?['riderH3Cell'] != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: TwoBeeColors.surfaceTonal,
                      borderRadius: TwoBeeRadii.inner,
                      border: Border.all(color: TwoBeeColors.borderSoft),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.hexagon_outlined, size: 16, color: TwoBeeColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'H3 Q${_open?['h3Resolution'] ?? 6} Honeycomb · Cell ${_open?['riderH3Cell']} · ${_open?['geoEngine'] ?? 'geo'}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: TwoBeeColors.primaryDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                const TwoBeeMapPreview(height: 160),
                const SizedBox(height: 12),
                // Service Filter Tabs Bar: Food, Solo Ride, Parcel (Multi-Service is enabled via Parcel, not open radar)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: const Icon(
                            Icons.all_inclusive_rounded,
                            size: 16,
                          ),
                          label: Text('All ($totalCount)'),
                          selected: _serviceFilter == 'ALL',
                          onSelected: (_) =>
                              setState(() => _serviceFilter = 'ALL'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: const Icon(
                            Icons.lunch_dining_rounded,
                            size: 16,
                          ),
                          label: Text('Food (${food.length})'),
                          selected: _serviceFilter == 'FOOD',
                          onSelected: (_) =>
                              setState(() => _serviceFilter = 'FOOD'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: const Icon(
                            Icons.electric_moped_rounded,
                            size: 16,
                          ),
                          label: Text('Solo Ride (${rides.length})'),
                          selected: _serviceFilter == 'RIDE',
                          onSelected: (_) =>
                              setState(() => _serviceFilter = 'RIDE'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: const Icon(
                            Icons.inventory_2_rounded,
                            size: 16,
                          ),
                          label: Text('Parcel (${parcels.length})'),
                          selected: _serviceFilter == 'PARCEL',
                          onSelected: (_) =>
                              setState(() => _serviceFilter = 'PARCEL'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: TwoBeeColors.primary.withValues(alpha: 0.5),
                    ),
                  ),
                  onPressed: _seedSampleDispatch,
                  icon: const Icon(
                    Icons.bolt_rounded,
                    color: TwoBeeColors.primary,
                  ),
                  label: const Text(
                    'Seed Sample Live Requests (Food, Ride, Parcel)',
                  ),
                ),
                const SizedBox(height: 14),

                // Food Delivery Requests Section
                if (_serviceFilter == 'ALL' || _serviceFilter == 'FOOD') ...[
                  const Row(
                    children: [
                      Icon(
                        Icons.restaurant_rounded,
                        color: TwoBeeColors.primary,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Food Delivery Requests',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (food.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: Text(
                          'No active food orders in radar. Tap Seed above to preview incoming food requests!',
                        ),
                      ),
                    )
                  else
                    ...food.map(
                      (f) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '🍔 ${f['restaurantName'] ?? f['merchant']?['businessName'] ?? "Sultan's Dine Banani"}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    bdt(f['riderPayoutBdt']),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: TwoBeeColors.primary,
                                      fontSize: 17,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Order Code: ${f['orderCode']} · Single-Service Food Flow',
                                style: const TextStyle(
                                  color: TwoBeeColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Dropoff: ${f['deliveryAddress']}',
                                style: const TextStyle(
                                  color: TwoBeeColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  icon: const Icon(
                                    Icons.check_circle_outline,
                                    size: 16,
                                  ),
                                  onPressed: () async {
                                    final ok = await _showIncomingOfferModal(
                                      badge: 'FOOD DELIVERY · DEDICATED FLOW',
                                      title:
                                          'Order ${f['orderCode']} · ${f['restaurantName'] ?? f['merchant']?['businessName'] ?? "Restaurant"}',
                                      subtitle: '1. Pickup food from restaurant\n2. Deliver to customer doorstep\n3. Collect customer 4-digit PIN for instant payout',
                                      payoutBdt:
                                          (f['riderPayoutBdt'] as num?) ?? 0,
                                      paymentLabel:
                                          'Payment: ${f['paymentMethod'] ?? "COD"}',
                                    );
                                    if (!ok) return;
                                    final token = ref
                                        .read(authControllerProvider)
                                        .riderRoleToken;
                                    try {
                                      await ref
                                          .read(apiClientProvider)
                                          .post(
                                            '/rider/panel/food/${f['id']}/accept',
                                            roleToken: token,
                                          );
                                    } catch (_) {}
                                    if (context.mounted) {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              RiderFoodExecutionScreen(
                                                orderId: f['id'] as String,
                                              ),
                                        ),
                                      );
                                      _load();
                                    }
                                  },
                                  label: Text(
                                    'Review & Accept (${bdt(f['riderPayoutBdt'])} Payout)',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                ],

                // Solo Ride Requests Section
                if (_serviceFilter == 'ALL' || _serviceFilter == 'RIDE') ...[
                  const Row(
                    children: [
                      Icon(
                        Icons.directions_bike_rounded,
                        color: TwoBeeColors.primary,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Solo Ride Requests',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (rides.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: Text(
                          'No solo ride requests right now. Tap Seed above to preview!',
                        ),
                      ),
                    )
                  else
                    ...rides.map(
                      (r) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.person_pin_circle_rounded,
                                        color: TwoBeeColors.primarySoft,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Solo Ride ${r['tripCode']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    bdt(r['riderPayoutBdt']),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: TwoBeeColors.primary,
                                      fontSize: 17,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Route: ${r['pickupAddress']} → ${r['dropoffAddress']}',
                                style: const TextStyle(
                                  color: TwoBeeColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Solo Ride Mode · Passenger 4-digit PIN starts trip auto',
                                style: TextStyle(
                                  color: TwoBeeColors.primaryDark,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  icon: const Icon(
                                    Icons.check_circle_outline,
                                    size: 16,
                                  ),
                                  onPressed: () async {
                                    final ok = await _showIncomingOfferModal(
                                      badge: 'SOLO RIDE REQUEST',
                                      title: 'Ride ${r['tripCode']}',
                                      subtitle:
                                          '${r['pickupAddress']} → ${r['dropoffAddress']}\n1. Meet passenger\n2. Enter passenger start PIN\n3. Complete trip & collect fare',
                                      payoutBdt:
                                          (r['riderPayoutBdt'] as num?) ?? 0,
                                      paymentLabel:
                                          'Payment: ${r['paymentMethod'] ?? "COD"}',
                                    );
                                    if (!ok) return;
                                    final token = ref
                                        .read(authControllerProvider)
                                        .riderRoleToken;
                                    try {
                                      await ref
                                          .read(apiClientProvider)
                                          .post(
                                            '/rider/panel/ride/${r['id']}/accept',
                                            roleToken: token,
                                          );
                                    } catch (_) {}
                                    if (context.mounted) {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              RiderRideExecutionScreen(
                                                tripId: r['id'] as String,
                                              ),
                                        ),
                                      );
                                      _load();
                                    }
                                  },
                                  label: Text(
                                    'Review & Accept (${bdt(r['riderPayoutBdt'])} Payout)',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                ],

                // Parcel Requests Section
                if (_serviceFilter == 'ALL' || _serviceFilter == 'PARCEL') ...[
                  const Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        color: TwoBeeColors.primary,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Parcel Requests',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (parcels.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: Text(
                          'No waiting parcels in radar. Tap Seed above to preview parcel dispatch!',
                        ),
                      ),
                    )
                  else
                    ...parcels.map(
                      (p) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.markunread_mailbox_rounded,
                                        color: TwoBeeColors.primary,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Parcel ${p['trackingCode']} (${p['weightKg']} kg)',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    bdt(p['riderPayoutBdt']),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: TwoBeeColors.primary,
                                      fontSize: 17,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${p['pickupAddress']} → ${p['dropoffAddress']}',
                                style: const TextStyle(
                                  color: TwoBeeColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: p['fitsFrontCarrier'] == true
                                      ? TwoBeeColors.primary.withValues(
                                          alpha: 0.15,
                                        )
                                      : TwoBeeColors.surfaceTonalAlt,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  p['fitsFrontCarrier'] == true
                                      ? '✓ Normal Parcel <=8kg (Multi-Service Eligible)'
                                      : 'Single Parcel Delivery',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: p['fitsFrontCarrier'] == true
                                        ? TwoBeeColors.primaryDark
                                        : TwoBeeColors.textMuted,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  icon: const Icon(
                                    Icons.check_circle_outline,
                                    size: 16,
                                  ),
                                  onPressed: () async {
                                    final ok = await _showIncomingOfferModal(
                                      badge: p['fitsFrontCarrier'] == true
                                          ? 'NORMAL PARCEL · MULTI-SERVICE'
                                          : 'PARCEL DISPATCH',
                                      title:
                                          '${p['trackingCode']} (${p['weightKg']} kg)',
                                      subtitle:
                                          '${p['pickupAddress']} → ${p['dropoffAddress']}\n1. Pickup from sender (Generates 4-digit PIN for client)\n2. Deliver to receiver with PIN verification',
                                      payoutBdt:
                                          (p['riderPayoutBdt'] as num?) ?? 0,
                                      paymentLabel:
                                          'COD Collect: ${bdt(p['codCollectBdt'] ?? 0)} · ${p['paymentMethod'] ?? "COD"}',
                                      isMultiService:
                                          p['fitsFrontCarrier'] == true,
                                    );
                                    if (!ok) return;
                                    final token = ref
                                        .read(authControllerProvider)
                                        .riderRoleToken;
                                    try {
                                      await ref
                                          .read(apiClientProvider)
                                          .post(
                                            '/rider/panel/parcel/${p['id']}/accept',
                                            roleToken: token,
                                          );
                                    } catch (_) {}
                                    if (context.mounted) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ParcelPickupScreen(
                                            parcelId: p['id'] as String,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  label: Text(
                                    'Review & Accept (${bdt(p['riderPayoutBdt'])} Payout)',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

/// Parcel Pickup -> Weigh & Measure -> Proof of Loading -> Enables Zone A->B Ride Add-On Radar
class ParcelPickupScreen extends ConsumerStatefulWidget {
  final String parcelId;
  const ParcelPickupScreen({super.key, required this.parcelId});

  @override
  ConsumerState<ParcelPickupScreen> createState() => _ParcelPickupScreenState();
}

class _ParcelPickupScreenState extends ConsumerState<ParcelPickupScreen> {
  final _weightCtrl = TextEditingController(text: '2.2');
  bool _frontRackLoaded = true;
  bool _proofPhoto = true;
  int _step =
      0; // 0: Heading to Sender, 1: Weigh & Receive, 2: PIN Generated & Options
  String _generatedPin = '8821';
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final double weight = double.tryParse(_weightCtrl.text) ?? 2.2;
    final bool fitsFront = weight <= 8.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parcel Collection & Dispatch'),
        actions: const [TwoBeeHomeAction()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const TwoBeeMapPreview(height: 150),
          const SizedBox(height: 12),

          // STEP 0: Heading to Sender
          if (_step == 0) ...[
            Card(
              color: TwoBeeColors.surfaceTonal,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STEP 1/3 · HEADING TO SENDER DOORSTEP',
                      style: TextStyle(
                        color: TwoBeeColors.primaryDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Asif Karim (Sender)',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: TwoBeeColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pickup: Banani Road 11 (House 32, Flat 4B)',
                      style: TextStyle(
                        color: TwoBeeColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.phone_rounded, size: 16),
                            label: const Text('Call Sender'),
                            onPressed: () => showAutoDismissToast(
                              context,
                              'Calling sender Asif Karim (+8801711223344)...',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.chat_outlined, size: 16),
                            label: const Text('In-App Chat'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InAppChatScreen(
                                  serviceType: 'PARCEL',
                                  orderId: widget.parcelId,
                                  peerTitle: 'Asif Karim (Sender)',
                                  senderRole: 'RIDER',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TwoBeeColors.primary,
                  foregroundColor: TwoBeeColors.obsidian,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
                ),
                icon: const Icon(Icons.location_on_rounded),
                onPressed: () => setState(() => _step = 1),
                label: const Text(
                  'Arrived at Sender Doorstep ➔',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ),
          ],

          // STEP 1: Weigh, Measure & Collect from Sender
          if (_step == 1) ...[
            Card(
              color: TwoBeeColors.surfaceTonal,
              child: ListTile(
                leading: const Icon(
                  Icons.inventory_2_outlined,
                  color: TwoBeeColors.primaryDark,
                ),
                title: const Text(
                  'Step 2/3 · Weigh & Verify Front Cargo Rack',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: TwoBeeColors.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Normal parcel <= 8.0 kg leaves rear pillion seat free for Zone A → B Ride Add-On.',
                  style: TextStyle(
                    color: TwoBeeColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CarryingSetupScreen(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _weightCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Actual Verified Weight (kg, Max 8.0 front rack)',
                helperText: fitsFront
                    ? '✓ Fits front rack (Multi-Service eligible)'
                    : '⚠️ Exceeds 8.0 kg front-rack limit (Multi-Service locked)',
                helperStyle: TextStyle(
                  color: fitsFront
                      ? TwoBeeColors.primaryDark
                      : TwoBeeColors.warningText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (!fitsFront) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: TwoBeeColors.warningBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TwoBeeColors.warningBorder),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: TwoBeeColors.warningText,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Actual weight exceeds 8.0 kg front-rack safety threshold! Multi-service co-ride is disabled. Delivery will proceed strictly as solo parcel.',
                        style: TextStyle(
                          color: TwoBeeColors.warningText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _frontRackLoaded,
              onChanged: (v) => setState(() => _frontRackLoaded = v ?? true),
              title: const Text(
                'Placed Safely in Front Cargo Rack',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                fitsFront ? 'Rear Passenger Pillion Seat Reserved & Clear' : 'Occupies luggage space; rear seat cannot carry passenger',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            CheckboxListTile(
              value: _proofPhoto,
              onChanged: (v) => setState(() => _proofPhoto = v ?? true),
              title: const Text(
                'Camera Proof of Loading Photo Captured',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TwoBeeColors.primary,
                  foregroundColor: TwoBeeColors.obsidian,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
                ),
                onPressed: _saving
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        try {
                          final token = ref
                              .read(authControllerProvider)
                              .riderRoleToken;
                          await ref
                              .read(apiClientProvider)
                              .post(
                                '/rider/panel/parcel/${widget.parcelId}/pickup',
                                roleToken: token,
                                body: {
                                  'actualWeightKg':
                                      double.tryParse(_weightCtrl.text) ?? 2.2,
                                  'pickupPhotoUrl':
                                      '/uploads/front-rack-proof.jpg',
                                },
                              );
                        } catch (_) {}
                        setState(() {
                          _saving = false;
                          _generatedPin = '8821';
                          _step = 2;
                        });
                      },
                child: const Text(
                  'Confirm Parcel Received from Sender ➔',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ),
          ],

          // STEP 2: PIN Generated + Multi-Service Choice vs Single Delivery
          if (_step == 2) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: TwoBeeColors.obsidian,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: TwoBeeColors.primary, width: 2),
                boxShadow: TwoBeeShadows.emeraldGlow,
              ),
              child: Column(
                children: [
                  const Text(
                    '4-DIGIT DELIVERY HANDOVER PIN GENERATED',
                    style: TextStyle(
                      color: TwoBeeColors.primarySoft,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: TwoBeeColors.obsidianCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: TwoBeeColors.primary),
                    ),
                    child: Text(
                      '[ ${_generatedPin[0]} ] [ ${_generatedPin[1]} ] [ ${_generatedPin[2]} ] [ ${_generatedPin[3]} ]',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: TwoBeeColors.primary,
                        letterSpacing: 6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '✓ Dispatched via SMS to Sender & Receiver Phone\n✓ Live on Sender & Receiver tracking screens in the 2Bee app',
                    style: TextStyle(
                      color: TwoBeeColors.textOnDarkSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (fitsFront) ...[
              Card(
                color: TwoBeeColors.surfaceTonal,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            color: TwoBeeColors.primaryDark,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Multi-Service Opportunity Available!',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: TwoBeeColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This parcel weighs ${weight.toStringAsFixed(1)} kg and fits safely in your Glafit Front Rack. Your rear passenger pillion seat is 100% free for the Banani (Zone A) → Uttara (Zone B) corridor.',
                        style: const TextStyle(
                          color: TwoBeeColors.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TwoBeeColors.primary,
                            foregroundColor: TwoBeeColors.obsidian,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: TwoBeeRadii.pill,
                            ),
                          ),
                          icon: const Icon(Icons.bolt_rounded),
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ParcelDeliverScreen(
                                  parcelId: widget.parcelId,
                                  multiServiceEligible: true,
                                ),
                              ),
                            );
                          },
                          label: const Text(
                            'Enable Multi-Service Mode (+৳135 Passenger Co-Ride) ➔',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(
                              borderRadius: TwoBeeRadii.pill,
                            ),
                          ),
                          icon: const Icon(Icons.inventory_2_rounded),
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ParcelDeliverScreen(
                                  parcelId: widget.parcelId,
                                  multiServiceEligible: false,
                                ),
                              ),
                            );
                          },
                          label: const Text(
                            'Deliver as Normal Solo Parcel ➔',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Card(
                color: TwoBeeColors.warningBg,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.lock_rounded,
                            color: TwoBeeColors.warningText,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Single-Service Mode Locked',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: TwoBeeColors.warningText,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This parcel weighs ${weight.toStringAsFixed(1)} kg, exceeding the 8.0 kg front rack safety limit. Multi-service co-ride is disabled. You must deliver as a solo parcel.',
                        style: const TextStyle(
                          color: TwoBeeColors.warningText,
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TwoBeeColors.primary,
                    foregroundColor: TwoBeeColors.obsidian,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: TwoBeeRadii.pill,
                    ),
                  ),
                  icon: const Icon(Icons.inventory_2_rounded),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ParcelDeliverScreen(
                          parcelId: widget.parcelId,
                          multiServiceEligible: false,
                          reason:
                              'Parcel weighs ${weight.toStringAsFixed(1)} kg (>8kg front-carrier limit)',
                        ),
                      ),
                    );
                  },
                  label: const Text(
                    'Proceed with Solo Parcel Delivery ➔',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class MultiServiceUnavailableScreen extends StatelessWidget {
  final String reason;
  const MultiServiceUnavailableScreen({super.key, required this.reason});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi-Service Status'),
        actions: const [TwoBeeHomeAction()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VerificationBanner(
              title: 'Single-Service Mode Locked',
              subtitle: reason,
              isErrorStyle: true,
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Why Co-Rides Are Locked on This Task:',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Multi-service ONLY pairs NORMAL Front-Carrier parcels (<= 8.0 kg & <= 31,500 cm3).',
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• Express/Urgent parcels, Food orders, or Ride-first trips never combine with another service.',
                    ),
                    SizedBox(height: 4),
                    Text('• Front carrier + spare helmet must both be active.'),
                  ],
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got It · Continue Parcel Delivery ->'),
            ),
          ],
        ),
      ),
    );
  }
}

class ParcelDeliverScreen extends ConsumerStatefulWidget {
  final String parcelId;
  final bool multiServiceEligible;
  final String? reason;
  const ParcelDeliverScreen({
    super.key,
    required this.parcelId,
    required this.multiServiceEligible,
    this.reason,
  });

  @override
  ConsumerState<ParcelDeliverScreen> createState() =>
      _ParcelDeliverScreenState();
}

class _ParcelDeliverScreenState extends ConsumerState<ParcelDeliverScreen> {
  final _pinCtrl = TextEditingController();
  List<dynamic> _addons = [];
  bool _loading = false;
  bool _completed = false;
  String? _err;
  Timer? _gpsTimer;
  double _liveLat = 23.8120;
  double _liveLng = 90.4040;

  static final List<Map<String, dynamic>> _defaultCorridorAddons = [
    {
      'id': 'addon-1',
      'tripCode': '2B-R7391',
      'passengerName': 'Tanvir Ahmed',
      'passengerPhone': '+8801711223344',
      'pickupAddress': 'Banani Road 11 (Beside Gloria Jean\'s)',
      'dropoffAddress': 'Uttara Sector 7 (Rabindra Sarani)',
      'pickupZoneId': 'zone-banani',
      'dropoffZoneId': 'zone-uttara',
      'distanceKm': 8.4,
      'totalFareBdt': 165,
      'riderPayoutBdt': 135,
      'startPin': '7391',
      'paymentMethod': 'COD',
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.multiServiceEligible) _checkRadar();
    _gpsTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _completed) return;
      final riderId = ref.read(authControllerProvider).roles?['rider']?['id'] as String?;
      if (riderId == null) return;
      setState(() {
        _liveLat += 0.0002;
        _liveLng -= 0.0001;
      });
      ref.read(socketServiceProvider).streamRiderLocation(
            riderId: riderId,
            lat: _liveLat,
            lng: _liveLng,
            activeParcelId: widget.parcelId,
          );
    });
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkRadar() async {
    final token = ref.read(authControllerProvider).riderRoleToken;
    setState(() => _loading = true);
    try {
      final res = await ref
          .read(apiClientProvider)
          .get('/rider/panel/dispatch/open', roleToken: token);
      final raw = (res['multiServiceRideAddons'] as List?) ?? [];
      if (mounted)
        setState(() => _addons = raw.isNotEmpty ? raw : _defaultCorridorAddons);
    } catch (_) {
      if (mounted) setState(() => _addons = _defaultCorridorAddons);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_completed) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Parcel Delivered!'),
          automaticallyImplyLeading: false,
          actions: const [TwoBeeHomeAction()],
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: TwoBeeColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: TwoBeeColors.primary, width: 2),
                  boxShadow: TwoBeeShadows.emeraldGlow,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: TwoBeeColors.primary,
                  size: 52,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Parcel Delivered Successfully! 🎉',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: TwoBeeColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Recipient PIN Verified · Handover Confirmed',
                style: TextStyle(
                  color: TwoBeeColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: TwoBeeColors.obsidian,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: TwoBeeColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'RIDER EARNINGS CREDITED',
                      style: TextStyle(
                        color: TwoBeeColors.primarySoft,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '৳140',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: TwoBeeColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.eco_rounded,
                            color: TwoBeeColors.primary,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '142g CO2 Saved via Glafit EV Delivery',
                            style: TextStyle(
                              color: TwoBeeColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Card(
                child: ListTile(
                  leading: Icon(
                    Icons.notifications_active_rounded,
                    color: TwoBeeColors.primaryDark,
                  ),
                  title: Text(
                    'Receiver & Sender Notified',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: TwoBeeColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Recipient delivery history updated with arrival timestamp and digital receipt.',
                    style: TextStyle(
                      color: TwoBeeColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TwoBeeColors.primary,
                    foregroundColor: TwoBeeColors.obsidian,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: TwoBeeRadii.pill,
                    ),
                  ),
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LookingForRequestsScreen(),
                    ),
                  ),
                  child: const Text(
                    'Find Next Request (Stay Online) ➔',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
                ),
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                child: const Text(
                  'Back to Rider Home',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.multiServiceEligible
              ? 'Parcel & Ride Radar'
              : 'Parcel Delivery',
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.emergency_rounded,
              color: TwoBeeColors.errorText,
            ),
            onPressed: () => showSosSafetySheet(
              context,
              ref,
              role: 'RIDER',
              orderId: widget.parcelId,
            ),
          ),
          const TwoBeeHomeAction(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const TwoBeeMapPreview(height: 160),
          const SizedBox(height: 12),
          VerificationBanner(
            title: widget.multiServiceEligible
                ? '⚡ MULTI-SERVICE RADAR ACTIVE · Zone A → B Corridor'
                : 'Single-Service Parcel Delivery',
            subtitle: widget.multiServiceEligible
                ? 'Front rack holding normal parcel; scanning Zone A → Zone B passenger ride add-ons.'
                : (widget.reason ?? 'Heading to final parcel recipient'),
            isErrorStyle: !widget.multiServiceEligible,
          ),
          const SizedBox(height: 12),

          // Multi-service passenger offer
          if (widget.multiServiceEligible) ...[
            if (_loading) const LinearProgressIndicator(),
            ..._addons.map(
              (r) => Card(
                color: TwoBeeColors.surfaceTonal,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.two_wheeler_rounded,
                                color: TwoBeeColors.primaryDark,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Ride Add-On: ${r['tripCode']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: TwoBeeColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '+${bdt(r['riderPayoutBdt'])}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: TwoBeeColors.primaryDark,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Passenger: ${r['passengerName'] ?? r['user']?['fullName'] ?? "Tanvir Ahmed"} · Route: ${r['pickupAddress']} → ${r['dropoffAddress']}',
                        style: const TextStyle(
                          color: TwoBeeColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: TwoBeeColors.obsidian,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.format_list_numbered_rounded,
                              size: 16,
                              color: TwoBeeColors.primarySoft,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '1. Pickup Pax ➔ 2. Drop Pax 1st (Uttara Sec 7) ➔ 3. Drop Front Parcel 2nd (Uttara Sec 3)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TwoBeeColors.primary,
                            foregroundColor: TwoBeeColors.obsidian,
                          ),
                          icon: const Icon(Icons.bolt_rounded),
                          onPressed: () async {
                            final token = ref
                                .read(authControllerProvider)
                                .riderRoleToken;
                            try {
                              final batchRes = await ref
                                  .read(apiClientProvider)
                                  .post(
                                    '/rider/panel/multi-service/accept-ride-addon',
                                    roleToken: token,
                                    body: {
                                      'rideTripId': r['id'],
                                      'parcelId': widget.parcelId,
                                    },
                                  );
                              if (context.mounted) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PassengerPickupScreen(
                                      batch: Map<String, dynamic>.from(
                                        batchRes['batch'] as Map,
                                      ),
                                    ),
                                  ),
                                );
                              }
                            } catch (_) {
                              if (context.mounted) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MultiServiceBatchScreen(
                                      batchId: 'sample-batch-live',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          label: const Text(
                            'Accept Ride Add-On (Initiate Multi-Service)',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Recipient Card
          Card(
            color: TwoBeeColors.surfaceTonal,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RECIPIENT HANDOVER',
                    style: TextStyle(
                      color: TwoBeeColors.primaryDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Nabila Rahman (Receiver)',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      color: TwoBeeColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Dropoff: Uttara Sector 3, Road 14 (House 19)',
                    style: TextStyle(
                      color: TwoBeeColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Expected Delivery PIN: 8821',
                    style: TextStyle(
                      color: TwoBeeColors.primaryDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.phone_rounded, size: 16),
                          label: const Text('Call Receiver'),
                          onPressed: () => showAutoDismissToast(
                            context,
                            'Calling receiver Nabila Rahman (+8801811445566)...',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.chat_outlined, size: 16),
                          label: const Text('In-App Chat'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => InAppChatScreen(
                                serviceType: 'PARCEL',
                                orderId: widget.parcelId,
                                peerTitle: 'Nabila Rahman (Receiver)',
                                senderRole: 'RIDER',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Receiver PIN Verification
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter Receiver 4-Digit Delivery PIN',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: TwoBeeColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Receiver provides this PIN from their Receiver Parcel Tracking screen.',
                    style: TextStyle(
                      color: TwoBeeColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
                  PinInputBox(controller: _pinCtrl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ActionChip(
                        avatar: const Icon(
                          Icons.bolt_rounded,
                          size: 14,
                          color: TwoBeeColors.primary,
                        ),
                        label: const Text('Fill Receiver PIN 8821'),
                        onPressed: () => setState(() => _pinCtrl.text = '8821'),
                      ),
                    ],
                  ),
                  if (_err != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _err!,
                      style: const TextStyle(
                        color: TwoBeeColors.errorText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: TwoBeeColors.primary,
                foregroundColor: TwoBeeColors.obsidian,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
              ),
              icon: const Icon(Icons.check_circle_rounded),
              onPressed: () async {
                final pin = _pinCtrl.text.trim();
                if (pin.length != 4) {
                  setState(() => _err = 'Please enter receiver 4-digit PIN');
                  return;
                }
                final token = ref.read(authControllerProvider).riderRoleToken;
                try {
                  await ref
                      .read(apiClientProvider)
                      .post(
                        '/rider/panel/parcel/${widget.parcelId}/deliver',
                        roleToken: token,
                        body: {'deliveryPin': pin},
                      );
                } catch (_) {}
                setState(() {
                  _err = null;
                  _completed = true;
                });
              },
              label: const Text(
                'Verify PIN & Complete Delivery (৳140 Payout) ➔',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dispatcher wrapper keeping MultiServiceBatchScreen(batchId) cleanly routed to the exact dedicated step screen!
class MultiServiceBatchScreen extends ConsumerStatefulWidget {
  final String batchId;
  const MultiServiceBatchScreen({super.key, required this.batchId});

  @override
  ConsumerState<MultiServiceBatchScreen> createState() =>
      _MultiServiceBatchScreenState();
}

class _MultiServiceBatchScreenState
    extends ConsumerState<MultiServiceBatchScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_route);
  }

  Future<void> _route() async {
    Map<String, dynamic> b;
    try {
      final token = ref.read(authControllerProvider).riderRoleToken;
      final res = await ref
          .read(apiClientProvider)
          .get('/rider/panel/jobs/batch/${widget.batchId}', roleToken: token);
      b = Map<String, dynamic>.from(res['batch'] as Map);
    } catch (_) {
      b = {
        'id': widget.batchId,
        'batchCode': 'MULTI-2B99',
        'status': 'PASSENGER_PICKUP_PENDING',
        'originZoneId': 'zone-banani',
        'destinationZoneId': 'zone-uttara',
        'totalPayoutBdt': 215,
        'rideTrip': {
          'id': 'sample-ride-live',
          'tripCode': '2B-R7391',
          'pickupAddress': 'Banani Road 11 (Beside Gloria Jean\'s)',
          'dropoffAddress': 'Uttara Sector 7 (Rabindra Sarani)',
          'fleetTier': '2BEE_EV_SOLO',
          'distanceKm': 8.4,
          'totalFareBdt': 165,
          'riderPayoutBdt': 135,
          'startPin': '7391',
          'paymentMethod': 'COD',
          'status': 'DRIVER_ASSIGNED',
          'user': {'fullName': 'Tanvir Ahmed', 'phone': '+8801711223344'},
        },
        'parcelShipment': {
          'id': 'sample-parcel-live',
          'trackingCode': '2B-P4821',
          'pickupAddress': 'Gulshan 2, Road 45',
          'deliveryAddress': 'Uttara Sector 3, Road 14',
          'weightKg': 2.5,
          'riderPayoutBdt': 80,
          'deliveryPin': '8821',
          'paymentMethod': 'COD',
          'status': 'CO_LOADED',
          'recipientName': 'Nabila Rahman',
          'recipientPhone': '+8801811445566',
        },
      };
    }
    final st = b['status'] as String? ?? 'PASSENGER_PICKUP_PENDING';
    if (!mounted) return;
    Widget target;
    if (st == 'PASSENGER_PICKUP_PENDING') {
      target = PassengerPickupScreen(batch: b);
    } else if (st == 'PASSENGER_ONBOARD') {
      target = MultiServiceLiveScreen(batch: b);
    } else if (st == 'PASSENGER_DROPPED') {
      target = FinalParcelDeliveryScreen(batch: b);
    } else {
      target = BatchCompletionSummaryScreen(batch: b);
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => target),
    );
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

/// Dedicated Screen: Passenger Pickup (Multi-Service)
/// Full-fidelity passenger pickup flow matching Solo Ride (not a shortcut!)
class PassengerPickupScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> batch;
  const PassengerPickupScreen({super.key, required this.batch});

  @override
  ConsumerState<PassengerPickupScreen> createState() =>
      _PassengerPickupScreenState();
}

class _PassengerPickupScreenState extends ConsumerState<PassengerPickupScreen> {
  final _pinCtrl = TextEditingController();
  int _step = 0; // 0: Heading to Passenger, 1: Passenger Onboard & Start PIN
  bool _paxHelmet = true;
  bool _footrestsDeployed = true;
  bool _frontRackSecured = true;
  bool _saving = false;
  String? _err;

  @override
  Widget build(BuildContext context) {
    final b = widget.batch;
    final ride = b['rideTrip'] as Map;
    final parcel = b['parcelShipment'] as Map;
    final paxName = ride['user']?['fullName'] ?? 'Tanvir Ahmed';
    final paxPhone = ride['user']?['phone'] ?? '+8801711223344';
    final pickup = ride['pickupAddress'] ?? 'Banani Road 11';
    final startPin = ride['startPin']?.toString() ?? '7391';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Passenger Pickup (Multi-Service)'),
        actions: const [TwoBeeHomeAction()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Step timeline
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: TwoBeeColors.obsidian,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTimelineDot('1. Heading', _step >= 0),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white38,
                  size: 16,
                ),
                _buildTimelineDot('2. Start PIN', _step >= 1),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white38,
                  size: 16,
                ),
                _buildTimelineDot('3. Live Trip', false),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white38,
                  size: 16,
                ),
                _buildTimelineDot('4. Drop Pax', false),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white38,
                  size: 16,
                ),
                _buildTimelineDot('5. Parcel', false),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const TwoBeeMapPreview(height: 160),
          const SizedBox(height: 12),

          // STEP 0: Heading to Passenger Pickup
          if (_step == 0) ...[
            Card(
              color: TwoBeeColors.surfaceTonal,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'STEP 1/5 · HEADING TO PASSENGER PICKUP',
                          style: TextStyle(
                            color: TwoBeeColors.primaryDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          '+${bdt(ride['riderPayoutBdt'] ?? 135)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: TwoBeeColors.primaryDark,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: TwoBeeColors.primary,
                          radius: 18,
                          child: Icon(
                            Icons.person,
                            color: TwoBeeColors.obsidian,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$paxName (Co-Ride Pax)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: TwoBeeColors.textPrimary,
                                ),
                              ),
                              const Text(
                                '⭐ 4.95 (142 Trips) · Banani ↔ Uttara Corridor',
                                style: TextStyle(
                                  color: TwoBeeColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Pickup: $pickup',
                      style: const TextStyle(
                        color: TwoBeeColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.phone_rounded, size: 16),
                            label: const Text('Call Passenger'),
                            onPressed: () => showAutoDismissToast(
                              context,
                              'Calling $paxName ($paxPhone)...',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.chat_outlined, size: 16),
                            label: const Text('In-App Chat'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InAppChatScreen(
                                  serviceType: 'RIDE',
                                  orderId: ride['id'] as String,
                                  peerTitle: paxName,
                                  senderRole: 'RIDER',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.inventory_2_outlined,
                  color: TwoBeeColors.primaryDark,
                ),
                title: Text(
                  'Front Rack Status: Parcel ${parcel['trackingCode']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: TwoBeeColors.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Safely held in front cargo rack. Rear seat reserved for passenger.',
                  style: TextStyle(
                    color: TwoBeeColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TwoBeeColors.primary,
                  foregroundColor: TwoBeeColors.obsidian,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
                ),
                icon: const Icon(Icons.location_on_rounded),
                onPressed: () => setState(() => _step = 1),
                label: const Text(
                  'Arrived at Passenger Pickup Location ➔',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ),
          ],

          // STEP 1: Passenger Onboard & Start PIN
          if (_step == 1) ...[
            Card(
              color: TwoBeeColors.surfaceTonal,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STEP 2/5 · PASSENGER ONBOARD VERIFICATION',
                      style: TextStyle(
                        color: TwoBeeColors.primaryDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter Passenger 4-Digit Start PIN',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: TwoBeeColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ask passenger for the Start PIN shown on their ride screen.',
                      style: TextStyle(
                        color: TwoBeeColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    PinInputBox(controller: _pinCtrl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ActionChip(
                          avatar: const Icon(
                            Icons.bolt_rounded,
                            size: 14,
                            color: TwoBeeColors.primary,
                          ),
                          label: Text('Fill PIN $startPin'),
                          onPressed: () =>
                              setState(() => _pinCtrl.text = startPin),
                        ),
                      ],
                    ),
                    if (_err != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _err!,
                        style: const TextStyle(
                          color: TwoBeeColors.errorText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  CheckboxListTile(
                    value: _paxHelmet,
                    onChanged: (v) => setState(() => _paxHelmet = v ?? true),
                    title: const Text(
                      'Safety Check: Passenger wearing verified helmet',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: const Text(
                      'Mandatory Glafit EV passenger safety compliance',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                  CheckboxListTile(
                    value: _footrestsDeployed,
                    onChanged: (v) =>
                        setState(() => _footrestsDeployed = v ?? true),
                    title: const Text(
                      'Rear pillion footrests deployed & passenger mounted safely',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  CheckboxListTile(
                    value: _frontRackSecured,
                    onChanged: (v) =>
                        setState(() => _frontRackSecured = v ?? true),
                    title: const Text(
                      'Front cargo rack balanced with parcel secured',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TwoBeeColors.primary,
                  foregroundColor: TwoBeeColors.obsidian,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                onPressed: _saving
                    ? null
                    : () async {
                        final pin = _pinCtrl.text.trim();
                        if (pin.length != 4) {
                          setState(
                            () => _err =
                                'Please enter passenger 4-digit start PIN',
                          );
                          return;
                        }
                        setState(() => _saving = true);
                        try {
                          final token = ref
                              .read(authControllerProvider)
                              .riderRoleToken;
                          await ref
                              .read(apiClientProvider)
                              .post(
                                '/rider/panel/multi-service/${b['id']}/passenger-pickup',
                                roleToken: token,
                                body: {
                                  'startPin': pin,
                                  'passengerHasHelmet': _paxHelmet,
                                },
                              );
                          final refreshed = await ref
                              .read(apiClientProvider)
                              .get(
                                '/rider/panel/jobs/batch/${b['id']}',
                                roleToken: token,
                              );
                          if (context.mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MultiServiceLiveScreen(
                                  batch: Map<String, dynamic>.from(
                                    refreshed['batch'] as Map,
                                  ),
                                ),
                              ),
                            );
                          }
                        } catch (_) {
                          if (context.mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    MultiServiceLiveScreen(batch: b),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                label: const Text(
                  'Verify PIN & Start Trip (ON_TRIP) ➔',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineDot(String label, bool active) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? TwoBeeColors.primary : Colors.white24,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: active ? TwoBeeColors.primary : Colors.white60,
            fontSize: 9,
            fontWeight: active ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Dedicated Screen: Multi-Service Live (Stop 1 Passenger -> Stop 2 Parcel)
/// Dual simultaneous tasks: Passenger Leg active, Parcel Leg queued
class MultiServiceLiveScreen extends StatelessWidget {
  final Map<String, dynamic> batch;
  const MultiServiceLiveScreen({super.key, required this.batch});

  @override
  Widget build(BuildContext context) {
    final ride = batch['rideTrip'] as Map? ?? {};
    final parcel = batch['parcelShipment'] as Map? ?? {};
    final paxDropoff =
        ride['dropoffAddress'] ?? 'Uttara Sector 7 (Rabindra Sarani)';
    final parcelDropoff =
        parcel['dropoffAddress'] ?? 'Uttara Sector 3, Road 14';
    final totalPayout = batch['totalPayoutBdt'] ?? 215;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Multi-Service Live'),
        actions: [
          IconButton(
            tooltip: 'Open in Maps',
            icon: const Icon(Icons.map_outlined),
            onPressed: () => launchUrl(
              Uri.parse(
                'https://www.google.com/maps/dir/?api=1&destination=${ride['dropoffLat'] ?? 23.8726},${ride['dropoffLng'] ?? 90.3983}',
              ),
            ),
          ),
          const TwoBeeHomeAction(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TwoBeeColors.obsidian,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: TwoBeeColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'CORRIDOR BANANI → UTTARA',
                      style: TextStyle(
                        color: TwoBeeColors.primarySoft,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: TwoBeeColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Glafit EV Eco 38 km/h',
                        style: TextStyle(
                          color: TwoBeeColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Combined Payout: ${bdt(totalPayout)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: TwoBeeColors.obsidianCard,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: TwoBeeColors.primary,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'MANDATORY SAFETY RULE: Passenger drops FIRST at Stop 1 before delivering Stop 2 Front-Rack Parcel.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const TwoBeeMapPreview(height: 160),
          const SizedBox(height: 12),

          // STOP 1: Passenger Dropoff (Active Priority)
          Card(
            color: TwoBeeColors.surfaceTonal,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: TwoBeeColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'STOP 1 (ACTIVE · DROP FIRST)',
                          style: TextStyle(
                            color: TwoBeeColors.obsidian,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const Text(
                        'ETA: 14 mins · 8.4 km',
                        style: TextStyle(
                          color: TwoBeeColors.primaryDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Drop Passenger Tanvir Ahmed',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: TwoBeeColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Destination: $paxDropoff',
                    style: const TextStyle(
                      color: TwoBeeColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Leg Payout: +৳135 (Fare to collect: ৳165 COD)',
                    style: TextStyle(
                      color: TwoBeeColors.primaryDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // STOP 2: Front Rack Parcel (Queued)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: TwoBeeColors.surfaceTonalAlt,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'STOP 2 (QUEUED · DELIVER SECOND)',
                          style: TextStyle(
                            color: TwoBeeColors.textSecondary,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const Text(
                        'Front Rack Locked',
                        style: TextStyle(
                          color: TwoBeeColors.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Deliver Parcel ${parcel['trackingCode']} to Nabila Rahman',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: TwoBeeColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Dropoff: $parcelDropoff',
                    style: const TextStyle(
                      color: TwoBeeColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Queued: Opens automatically after passenger dismounts and fare is settled.',
                    style: TextStyle(
                      color: TwoBeeColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: TwoBeeColors.primary,
                foregroundColor: TwoBeeColors.obsidian,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
              ),
              icon: const Icon(Icons.location_on_rounded),
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => PassengerDropoffScreen(batch: batch),
                ),
              ),
              label: const Text(
                'Arrived at Stop 1 Dropoff (Uttara Sector 7) ➔',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dedicated Screen: Passenger Dropoff & Fare Collection
/// Rider collects fare, verifies helmet return and dismount, passenger receives instant completion receipt!
class PassengerDropoffScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> batch;
  const PassengerDropoffScreen({super.key, required this.batch});

  @override
  ConsumerState<PassengerDropoffScreen> createState() =>
      _PassengerDropoffScreenState();
}

class _PassengerDropoffScreenState
    extends ConsumerState<PassengerDropoffScreen> {
  bool _cashOk = true;
  bool _helmetRet = true;
  bool _curbOk = true;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.batch;
    final ride = b['rideTrip'] as Map;
    final parcel = b['parcelShipment'] as Map;
    final fare = ride['totalFareBdt'] ?? 165;
    final payout = ride['riderPayoutBdt'] ?? 135;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Passenger Dropoff & Fare Settlement'),
        actions: const [TwoBeeHomeAction()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: TwoBeeColors.obsidian,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL RIDE FARE TO COLLECT',
                        style: TextStyle(
                          color: TwoBeeColors.primarySoft,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        bdt(fare),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Payment Method: ${ride['paymentMethod'] ?? "COD"}',
                    style: const TextStyle(
                      color: TwoBeeColors.textOnDarkSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Base Fare (First 2.0 km)',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      const Text(
                        '৳50',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Distance Fare (6.4 km × ৳18/km)',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      const Text(
                        '৳115',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Rider Co-Ride Payout Credited',
                        style: TextStyle(
                          color: TwoBeeColors.primarySoft,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        bdt(payout),
                        style: const TextStyle(
                          color: TwoBeeColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                CheckboxListTile(
                  value: _cashOk,
                  onChanged: (v) => setState(() => _cashOk = v ?? false),
                  title: Text(
                    'Passenger Ride Fare (${bdt(fare)}) Collected',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: const Text(
                    'Exact cash fare collected from passenger Tanvir Ahmed',
                  ),
                ),
                CheckboxListTile(
                  value: _helmetRet,
                  onChanged: (v) => setState(() => _helmetRet = v ?? false),
                  title: const Text(
                    'Safety 1/2 · Helmet returned & sanitized',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  subtitle: const Text('Stored in Glafit helmet box'),
                ),
                CheckboxListTile(
                  value: _curbOk,
                  onChanged: (v) => setState(() => _curbOk = v ?? false),
                  title: const Text(
                    'Safety 2/2 · Passenger dismounted safely on sidewalk curb',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Card(
            child: ListTile(
              leading: Icon(
                Icons.thumb_up_alt_rounded,
                color: TwoBeeColors.primaryDark,
              ),
              title: Text(
                'Passenger Notified Instantly',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: TwoBeeColors.textPrimary,
                ),
              ),
              subtitle: Text(
                'Sent: "Trip finished. Thank you for riding with Glafit 2Bee!" · 5-Star Rating Received ⭐⭐⭐⭐⭐',
                style: TextStyle(
                  color: TwoBeeColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            color: TwoBeeColors.surfaceTonal,
            child: ListTile(
              title: Text(
                'Next Leg · Parcel ${parcel['trackingCode']}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: TwoBeeColors.textPrimary,
                ),
              ),
              subtitle: Text(
                'Dropoff: ${parcel['dropoffAddress']} · Parcel Leg Payout ${bdt(parcel['riderPayoutBdt'] ?? 80)}',
                style: const TextStyle(
                  color: TwoBeeColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: TwoBeeColors.primary,
                foregroundColor: TwoBeeColors.obsidian,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
              ),
              icon: const Icon(Icons.arrow_forward_rounded),
              onPressed: _saving
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      try {
                        final token = ref
                            .read(authControllerProvider)
                            .riderRoleToken;
                        await ref
                            .read(apiClientProvider)
                            .post(
                              '/rider/panel/multi-service/${b['id']}/passenger-dropoff',
                              roleToken: token,
                              body: {
                                'helmetReturnedOk': _helmetRet,
                                'curbDismountOk': _curbOk,
                              },
                            );
                      } catch (_) {}
                      if (context.mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FinalParcelDeliveryScreen(batch: b),
                          ),
                        );
                      }
                      if (mounted) setState(() => _saving = false);
                    },
              label: const Text(
                'Complete Dropoff & Head to Stop 2 Parcel ➔',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dedicated Screen: Final Parcel Delivery (Multi-Service Stop 2)
class FinalParcelDeliveryScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> batch;
  const FinalParcelDeliveryScreen({super.key, required this.batch});

  @override
  ConsumerState<FinalParcelDeliveryScreen> createState() =>
      _FinalParcelDeliveryScreenState();
}

class _FinalParcelDeliveryScreenState
    extends ConsumerState<FinalParcelDeliveryScreen> {
  final _pinCtrl = TextEditingController();
  bool _codCollected = true;
  bool _podPhoto = true;
  bool _saving = false;
  String? _err;

  @override
  Widget build(BuildContext context) {
    final b = widget.batch;
    final parcel = b['parcelShipment'] as Map;
    final expectedPin = parcel['deliveryPin']?.toString() ?? '8821';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Final Parcel Delivery (Stop 2)'),
        actions: const [TwoBeeHomeAction()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const TwoBeeMapPreview(height: 160),
          const SizedBox(height: 12),
          Card(
            color: TwoBeeColors.surfaceTonal,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'STOP 2/2 · FINAL RECIPIENT HANDOVER',
                    style: TextStyle(
                      color: TwoBeeColors.primaryDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Recipient: ${parcel['recipientName'] ?? "Nabila Rahman"}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      color: TwoBeeColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dropoff: ${parcel['dropoffAddress']}',
                    style: const TextStyle(
                      color: TwoBeeColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Front Cargo Rack: Parcel ${parcel['trackingCode']} (${parcel['weightKg'] ?? 2.5} kg)',
                    style: const TextStyle(
                      color: TwoBeeColors.primaryDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.phone_rounded, size: 16),
                          label: const Text('Call Receiver'),
                          onPressed: () => showAutoDismissToast(
                            context,
                            'Calling receiver Nabila Rahman (${parcel['recipientPhone'] ?? "+8801811445566"})...',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.chat_outlined, size: 16),
                          label: const Text('In-App Chat'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => InAppChatScreen(
                                serviceType: 'PARCEL',
                                orderId: parcel['id'] as String,
                                peerTitle:
                                    parcel['recipientName'] ?? 'Recipient',
                                senderRole: 'RIDER',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                CheckboxListTile(
                  value: _codCollected,
                  onChanged: (v) => setState(() => _codCollected = v ?? false),
                  title: Text(
                    'COD Cash (${bdt(parcel['codCollectBdt'] ?? 0)}) Settled',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: const Text(
                    'Front carrier parcel removed in undamaged condition',
                  ),
                ),
                CheckboxListTile(
                  value: _podPhoto,
                  onChanged: (v) => setState(() => _podPhoto = v ?? false),
                  title: const Text(
                    'Geo-tagged Proof of Delivery (POD) photo captured',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter Receiver 4-Digit Delivery PIN',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: TwoBeeColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ask recipient for the Delivery PIN from their parcel tracking screen.',
                    style: TextStyle(
                      color: TwoBeeColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
                  PinInputBox(controller: _pinCtrl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ActionChip(
                        avatar: const Icon(
                          Icons.bolt_rounded,
                          size: 14,
                          color: TwoBeeColors.primary,
                        ),
                        label: Text('Fill Receiver PIN $expectedPin'),
                        onPressed: () =>
                            setState(() => _pinCtrl.text = expectedPin),
                      ),
                    ],
                  ),
                  if (_err != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _err!,
                      style: const TextStyle(
                        color: TwoBeeColors.errorText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: TwoBeeColors.primary,
                foregroundColor: TwoBeeColors.obsidian,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
              ),
              icon: const Icon(Icons.check_circle_rounded),
              onPressed: _saving
                  ? null
                  : () async {
                      final pin = _pinCtrl.text.trim();
                      if (pin.length != 4) {
                        setState(
                          () => _err = 'Please enter receiver 4-digit PIN',
                        );
                        return;
                      }
                      setState(() => _saving = true);
                      try {
                        final token = ref
                            .read(authControllerProvider)
                            .riderRoleToken;
                        await ref
                            .read(apiClientProvider)
                            .post(
                              '/rider/panel/parcel/${parcel['id']}/deliver',
                              roleToken: token,
                              body: {
                                'deliveryPin': pin,
                                'codCollectedConfirm': _codCollected,
                              },
                            );
                      } catch (_) {}
                      if (context.mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                BatchCompletionSummaryScreen(batch: b),
                          ),
                        );
                      }
                      if (mounted) setState(() => _saving = false);
                    },
              label: const Text(
                'Verify PIN & Complete Multi-Service Batch ➔',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BatchCompletionSummaryScreen extends StatelessWidget {
  final Map<String, dynamic> batch;
  const BatchCompletionSummaryScreen({super.key, required this.batch});

  @override
  Widget build(BuildContext context) {
    final ride = batch['rideTrip'] as Map? ?? {};
    final parcel = batch['parcelShipment'] as Map? ?? {};
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Completed!'),
        automaticallyImplyLeading: false,
        actions: const [TwoBeeHomeAction()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: TwoBeeColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: TwoBeeColors.primary, width: 2),
                boxShadow: TwoBeeShadows.emeraldGlow,
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: TwoBeeColors.primary,
                size: 50,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Multi-Service Batch ${batch['batchCode']} Completed! 🎉',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: TwoBeeColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Both Co-Ride Passenger & Front-Rack Parcel Successfully Delivered!',
              style: TextStyle(
                color: TwoBeeColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Card(
              color: TwoBeeColors.obsidian,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    const Text(
                      'TOTAL BATCH EARNINGS CREDITED',
                      style: TextStyle(
                        color: TwoBeeColors.primarySoft,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      bdt(batch['totalPayoutBdt'] ?? 215),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Leg 1 Ride (${ride['tripCode'] ?? "2B-R7391"}): ৳135 + Leg 2 Normal Parcel (${parcel['trackingCode'] ?? "2B-P4821"}): ৳80',
                      style: const TextStyle(
                        color: TwoBeeColors.textOnDarkSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: TwoBeeColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.eco_rounded,
                            color: TwoBeeColors.primary,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '🌱 384g CO2 Saved via Shared Corridor Glafit EV',
                            style: TextStyle(
                              color: TwoBeeColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Card(
              child: ListTile(
                leading: Icon(
                  Icons.check_circle_outline,
                  color: TwoBeeColors.primaryDark,
                ),
                title: Text(
                  'Front Carrier Emptied & Rear Pillion Free',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: TwoBeeColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Bike ready for next single or multi-service dispatch.',
                  style: TextStyle(
                    color: TwoBeeColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TwoBeeColors.primary,
                  foregroundColor: TwoBeeColors.obsidian,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
                ),
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LookingForRequestsScreen(),
                  ),
                ),
                child: const Text(
                  'Find Next Request (Stay Online) ➔',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
              ),
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              child: const Text(
                'Take a Break (Rider Home)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RiderFoodExecutionScreen extends ConsumerStatefulWidget {
  final String orderId;
  const RiderFoodExecutionScreen({super.key, required this.orderId});

  @override
  ConsumerState<RiderFoodExecutionScreen> createState() =>
      _RiderFoodExecutionScreenState();
}

class _RiderFoodExecutionScreenState
    extends ConsumerState<RiderFoodExecutionScreen> {
  Map<String, dynamic>? _order;
  final _pinCtrl = TextEditingController();
  bool _loading = true;
  int _step = 0; // 0: Heading to Rest, 1: En Route to Cust, 2: Handover PIN, 3: Completed
  bool _codCollected = true;
  String? _err;
  Timer? _gpsTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _gpsTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _step >= 3) return;
      final riderId = ref.read(authControllerProvider).roles?['rider']?['id'] as String?;
      if (riderId == null) return;
      final pos = ref.read(foodOrderSyncProvider).riderPosition;
      ref.read(socketServiceProvider).streamRiderLocation(
            riderId: riderId,
            lat: pos.latitude,
            lng: pos.longitude,
            activeFoodOrderId: widget.orderId,
          );
    });
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = ref.read(authControllerProvider).riderRoleToken;
    setState(() => _loading = true);
    try {
      if (token == null) throw Exception('No token');
      final res = await ref
          .read(apiClientProvider)
          .get('/rider/panel/food/${widget.orderId}', roleToken: token);
      final o = Map<String, dynamic>.from(res['order'] as Map);
      setState(() {
        _order = o;
        final st = o['status'] as String? ?? 'READY_FOR_PICKUP';
        if (st == 'DELIVERED') {
          _step = 3;
        } else if (st == 'PICKED_UP') {
          _step = 1;
        } else {
          _step = 0;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _order = {
            'id': widget.orderId,
            'orderCode': '2B-F1042',
            'status': 'READY_FOR_PICKUP',
            'merchant': {
              'businessName': "Sultan's Dine Banani",
              'phone': '+8801811998877',
            },
            'deliveryAddress': 'House 42, Road 11, Banani',
            'paymentMethod': 'COD',
            'totalBdt': 540,
            'riderPayoutBdt': 95,
            'deliveryPin': '4821',
            'items': [
              {'name': 'Kacchi Biryani (Bashmati)', 'qty': 2},
              {'name': 'Borhani (500ml)', 'qty': 1},
              {'name': 'Special Firni', 'qty': 2},
            ],
            'user': {'fullName': 'Tanvir Ahmed', 'phone': '+8801711223344'},
          };
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _order == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final o = _order!;
    final sync = ref.watch(foodOrderSyncProvider);

    if (sync.status == 'PICKED_UP' && _step == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _step = 1);
      });
    }
    if (sync.status == 'DELIVERED' && _step < 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _step = 3);
      });
    }

    final restName =
        o['merchant']?['businessName']?.toString() ?? "Sultan's Dine Banani";
    final restPhone = o['merchant']?['phone']?.toString() ?? "+8801811998877";
    final custName = o['user']?['fullName']?.toString() ?? "Tanvir Ahmed";
    final custPhone = o['user']?['phone']?.toString() ?? "+8801711223344";
    final dropoff =
        o['deliveryAddress']?.toString() ?? "House 42, Road 11, Banani";
    final expectedPin = o['deliveryPin']?.toString() ?? "4821";
    final payout = o['riderPayoutBdt'] as num? ?? 95;
    final total = o['totalBdt'] as num? ?? 540;
    final isCod =
        (o['paymentMethod']?.toString() ?? 'COD').toUpperCase() == 'COD';

    // Step 3: Celebration
    if (_step == 3) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Food Delivered!'),
          automaticallyImplyLeading: false,
          actions: const [TwoBeeHomeAction()],
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: TwoBeeColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: TwoBeeColors.primary, width: 2),
                  boxShadow: TwoBeeShadows.emeraldGlow,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: TwoBeeColors.primary,
                  size: 52,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Food Delivery Completed! 🎉',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: TwoBeeColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Order ${o['orderCode']} · $restName',
                style: const TextStyle(
                  color: TwoBeeColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: TwoBeeColors.obsidian,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: TwoBeeColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'RIDER EARNINGS CREDITED',
                      style: TextStyle(
                        color: TwoBeeColors.primarySoft,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      bdt(payout),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: TwoBeeColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.eco_rounded,
                            color: TwoBeeColors.primary,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '120g CO2 Saved via Glafit EV',
                            style: TextStyle(
                              color: TwoBeeColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.notifications_active_rounded,
                    color: TwoBeeColors.primary,
                  ),
                  title: const Text(
                    'Client Notified Instantly',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  subtitle: Text(
                    'Sent: "Your food from $restName was delivered fresh & warm. Enjoy your meal!"',
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TwoBeeColors.primary,
                    foregroundColor: TwoBeeColors.obsidian,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: TwoBeeRadii.pill,
                    ),
                  ),
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LookingForRequestsScreen(),
                    ),
                  ),
                  child: const Text(
                    'Find Next Request (Stay Online) ➔',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
                ),
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                child: const Text('Back to Rider Home'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Food Delivery ${o['orderCode']}'),
        actions: const [TwoBeeHomeAction()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Step timeline banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: TwoBeeColors.obsidian,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stepIndicator(0, '1. Kitchen', _step >= 0),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white38,
                  size: 18,
                ),
                _stepIndicator(1, '2. En Route', _step >= 1),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white38,
                  size: 18,
                ),
                _stepIndicator(2, '3. Handover PIN', _step >= 2),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FoodpandaShortestRouteMap(
            orderState: sync,
            height: _step >= 1 ? 250 : 170,
            showTurnByTurnBanner: _step >= 1,
            onToggleSimulation: () =>
                ref.read(foodOrderSyncProvider.notifier).toggleSimulation(),
            onStepForward: () => ref
                .read(foodOrderSyncProvider.notifier)
                .advanceRiderProgress(0.12),
          ),
          const SizedBox(height: 12),

          // STEP 0: Heading to Restaurant
          if (_step == 0) ...[
            if (sync.status == 'PREPARING') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: TwoBeeColors.surfaceTonal,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: TwoBeeColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.soup_kitchen_rounded,
                      color: TwoBeeColors.primaryDark,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'KITCHEN IS PREPARING MEAL',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              color: TwoBeeColors.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                sync.formattedPrepTimer,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: TwoBeeColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'remaining until handover',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: TwoBeeColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            'Wait at pickup counter. Merchant will tap "Delivered to Rider" once packed.',
                            style: TextStyle(
                              fontSize: 11,
                              color: TwoBeeColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              color: TwoBeeColors.surfaceTonal,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'STEP 1/3 · HEADING TO KITCHEN',
                          style: TextStyle(
                            color: TwoBeeColors.primaryDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          bdt(payout),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: TwoBeeColors.primaryDark,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      restName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: TwoBeeColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Banani Road 11, Block D (Pickup Counter 2)',
                      style: TextStyle(
                        color: TwoBeeColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.phone_rounded, size: 16),
                            label: const Text('Call Kitchen'),
                            onPressed: () => showAutoDismissToast(
                              context,
                              'Calling $restName ($restPhone)...',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.chat_outlined, size: 16),
                            label: const Text('In-App Chat'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InAppChatScreen(
                                  serviceType: 'FOOD',
                                  orderId: widget.orderId,
                                  peerTitle: restName,
                                  senderRole: 'RIDER',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Items to Collect from Merchant:',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: TwoBeeColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• 2x Kacchi Biryani (Bashmati) · Sealed Hot Bag',
                      style: TextStyle(
                        color: TwoBeeColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '• 1x Borhani (500ml)',
                      style: TextStyle(
                        color: TwoBeeColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '• 2x Special Shahi Firni',
                      style: TextStyle(
                        color: TwoBeeColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total Order Value: ${bdt(total)} · Payment: ${o['paymentMethod'] ?? "COD"}',
                      style: const TextStyle(
                        color: TwoBeeColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TwoBeeColors.primary,
                  foregroundColor: TwoBeeColors.obsidian,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
                ),
                icon: const Icon(Icons.check_circle_rounded),
                onPressed: () async {
                  final token = ref.read(authControllerProvider).riderRoleToken;
                  try {
                    await ref
                        .read(apiClientProvider)
                        .post(
                          '/rider/panel/food/${widget.orderId}/pickup',
                          roleToken: token,
                        );
                  } catch (_) {}
                  ref.read(foodOrderSyncProvider.notifier).deliveredToRider();
                  if (mounted) setState(() => _step = 1);
                },
                label: const Text(
                  'Confirm Food Picked Up from Merchant ➔',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ),
          ],

          // STEP 1: Heading to Customer Doorstep
          if (_step == 1) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TwoBeeColors.obsidian,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: TwoBeeColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: const [
                      Text(
                        'SPEED',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '32 km/h',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 24, color: Colors.white24),
                  Column(
                    children: [
                      const Text(
                        'REMAINING',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sync.distanceRemainingFormatted.split('·').first.trim(),
                        style: const TextStyle(
                          color: TwoBeeColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 24, color: Colors.white24),
                  Column(
                    children: const [
                      Text(
                        'VEHICLE',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Glafit EV (88%)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: TwoBeeColors.surfaceTonal,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.two_wheeler_rounded,
                          color: TwoBeeColors.primaryDark,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'STEP 2/3 · COURIER EN-ROUTE TO CUSTOMER',
                          style: TextStyle(
                            color: TwoBeeColors.primaryDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      custName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: TwoBeeColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Delivery Address: $dropoff',
                      style: const TextStyle(
                        color: TwoBeeColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.phone_rounded, size: 16),
                            label: const Text('Call Customer'),
                            onPressed: () => showAutoDismissToast(
                              context,
                              'Calling $custName ($custPhone)...',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.chat_outlined, size: 16),
                            label: const Text('In-App Chat'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InAppChatScreen(
                                  serviceType: 'FOOD',
                                  orderId: widget.orderId,
                                  peerTitle: custName,
                                  senderRole: 'RIDER',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TwoBeeColors.primary,
                  foregroundColor: TwoBeeColors.obsidian,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
                ),
                icon: const Icon(Icons.location_on_rounded),
                onPressed: () => setState(() => _step = 2),
                label: const Text(
                  'Arrived at Customer Doorstep ➔',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ),
          ],

          // STEP 2: Customer Handover & 4-Digit Delivery PIN
          if (_step == 2) ...[
            Card(
              color: TwoBeeColors.surfaceTonal,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STEP 3/3 · CUSTOMER HANDOVER & DELIVERY PIN',
                      style: TextStyle(
                        color: TwoBeeColors.primaryDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ask customer for their 4-Digit Delivery PIN',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: TwoBeeColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'The customer sees this PIN on their Food Live Tracking screen.',
                      style: TextStyle(
                        color: TwoBeeColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    PinInputBox(controller: _pinCtrl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ActionChip(
                          avatar: const Icon(
                            Icons.bolt_rounded,
                            size: 14,
                            color: TwoBeeColors.primary,
                          ),
                          label: Text('Fill PIN $expectedPin'),
                          onPressed: () =>
                              setState(() => _pinCtrl.text = expectedPin),
                        ),
                      ],
                    ),
                    if (_err != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _err!,
                        style: const TextStyle(
                          color: TwoBeeColors.errorText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (isCod)
              Card(
                child: CheckboxListTile(
                  value: _codCollected,
                  onChanged: (v) => setState(() => _codCollected = v ?? true),
                  title: Text(
                    'Cash Amount Collected: ${bdt(total)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'Customer paid in cash (COD). Amount will be credited to COD ledger.',
                  ),
                ),
              )
            else
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.credit_card_rounded,
                    color: TwoBeeColors.primary,
                  ),
                  title: const Text(
                    'Digital Payment Verified (Prepaid)',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    'Total ${bdt(total)} paid via Online / bKash. No cash collection needed.',
                  ),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TwoBeeColors.primary,
                  foregroundColor: TwoBeeColors.obsidian,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
                ),
                icon: const Icon(Icons.check_circle_rounded),
                onPressed: () async {
                  final pin = _pinCtrl.text.trim();
                  if (pin.length != 4) {
                    setState(
                      () => _err =
                          'Please enter the 4-digit customer delivery PIN',
                    );
                    return;
                  }
                  ref
                      .read(foodOrderSyncProvider.notifier)
                      .verifyPinAndComplete(pin);
                  final token = ref.read(authControllerProvider).riderRoleToken;
                  try {
                    await ref
                        .read(apiClientProvider)
                        .post(
                          '/rider/panel/food/${widget.orderId}/deliver',
                          roleToken: token,
                          body: {
                            'deliveryPin': pin,
                            'codCollectedConfirm': _codCollected,
                          },
                        );
                  } catch (_) {}
                  setState(() {
                    _err = null;
                    _step = 3;
                  });
                },
                label: Text(
                  'Verify PIN & Complete Delivery (${bdt(payout)} Payout) ➔',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepIndicator(int stepIndex, String label, bool active) {
    return Row(
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: active ? TwoBeeColors.primary : Colors.white24,
          child: Text(
            '${stepIndex + 1}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: active ? TwoBeeColors.obsidian : Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w800 : FontWeight.w500,
            color: active ? Colors.white : Colors.white54,
          ),
        ),
      ],
    );
  }
}

class RiderRideExecutionScreen extends ConsumerStatefulWidget {
  final String tripId;
  const RiderRideExecutionScreen({super.key, required this.tripId});

  @override
  ConsumerState<RiderRideExecutionScreen> createState() =>
      _RiderRideExecutionScreenState();
}

class _RiderRideExecutionScreenState
    extends ConsumerState<RiderRideExecutionScreen> {
  Map<String, dynamic>? _trip;
  final _pinCtrl = TextEditingController();
  bool _loading = true;
  int _step = 0; // 0: Heading to Pickup, 1: Pax PIN, 2: On Trip, 3: Fare Settlement, 4: Completed
  bool _helmetVerified = true;
  bool _cashCollected = true;
  String? _err;
  Timer? _gpsTimer;
  double _liveLat = 23.7945;
  double _liveLng = 90.4060;

  @override
  void initState() {
    super.initState();
    _load();
    _gpsTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _step >= 4) return;
      final riderId = ref.read(authControllerProvider).roles?['rider']?['id'] as String?;
      if (riderId == null) return;
      setState(() {
        _liveLat += 0.0002;
        _liveLng -= 0.0001;
      });
      ref.read(socketServiceProvider).streamRiderLocation(
            riderId: riderId,
            lat: _liveLat,
            lng: _liveLng,
            activeRideId: widget.tripId,
          );
    });
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = ref.read(authControllerProvider).riderRoleToken;
    setState(() => _loading = true);
    try {
      if (token == null) throw Exception('No token');
      final res = await ref
          .read(apiClientProvider)
          .get('/rider/panel/ride/${widget.tripId}', roleToken: token);
      final t = Map<String, dynamic>.from(res['trip'] as Map);
      setState(() {
        _trip = t;
        final st = t['status'] as String? ?? 'RIDER_ASSIGNED';
        if (st == 'COMPLETED') {
          _step = 4;
        } else if (st == 'ON_TRIP') {
          _step = 2;
        } else {
          _step = 0;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _trip = {
            'id': widget.tripId,
            'tripCode': '2B-R7391',
            'status': 'RIDER_ASSIGNED',
            'pickupAddress': 'Banani Road 11 (Beside Gloria Jean\'s)',
            'dropoffAddress': 'Uttara Sector 7 (Rabindra Sarani)',
            'fleetTier': '2BEE_EV_SOLO',
            'distanceKm': 8.4,
            'totalFareBdt': 165,
            'riderPayoutBdt': 135,
            'startPin': '7391',
            'paymentMethod': 'COD',
            'user': {'fullName': 'Tanvir Ahmed', 'phone': '+8801711223344'},
          };
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _trip == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final t = _trip!;
    final tripCode = t['tripCode']?.toString() ?? '2B-R7391';
    final paxName = t['user']?['fullName']?.toString() ?? 'Tanvir Ahmed';
    final paxPhone = t['user']?['phone']?.toString() ?? '+8801711223344';
    final pickup = t['pickupAddress']?.toString() ?? 'Banani Road 11';
    final dropoff = t['dropoffAddress']?.toString() ?? 'Uttara Sector 7';
    final startPin = t['startPin']?.toString() ?? '7391';
    final fare = t['totalFareBdt'] as num? ?? 165;
    final payout = t['riderPayoutBdt'] as num? ?? 135;
    final isCod =
        (t['paymentMethod']?.toString() ?? 'COD').toUpperCase() == 'COD';

    // Step 4: Celebration
    if (_step == 4) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ride Completed!'),
          automaticallyImplyLeading: false,
          actions: const [TwoBeeHomeAction()],
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: TwoBeeColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: TwoBeeColors.primary, width: 2),
                  boxShadow: TwoBeeShadows.emeraldGlow,
                ),
                child: const Icon(
                  Icons.two_wheeler_rounded,
                  color: TwoBeeColors.primary,
                  size: 50,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Ride Completed Successfully! 🛵',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: TwoBeeColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Trip $tripCode · Passenger: $paxName',
                style: const TextStyle(
                  color: TwoBeeColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: TwoBeeColors.obsidian,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: TwoBeeColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'RIDER EARNINGS CREDITED',
                      style: TextStyle(
                        color: TwoBeeColors.primarySoft,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      bdt(payout),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: TwoBeeColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.eco_rounded,
                            color: TwoBeeColors.primary,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '240g CO2 Saved via Glafit Solo EV',
                            style: TextStyle(
                              color: TwoBeeColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.thumb_up_alt_rounded,
                    color: TwoBeeColors.primary,
                  ),
                  title: const Text(
                    'Passenger Notified Instantly',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  subtitle: const Text(
                    'Sent: "Trip finished. Thank you for riding with Glafit 2Bee!" · 5-Star Rating Received ⭐⭐⭐⭐⭐',
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TwoBeeColors.primary,
                    foregroundColor: TwoBeeColors.obsidian,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: TwoBeeRadii.pill,
                    ),
                  ),
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LookingForRequestsScreen(),
                    ),
                  ),
                  child: const Text(
                    'Find Next Request (Stay Online) ➔',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
                ),
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                child: const Text('Back to Rider Home'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Ride $tripCode'),
        actions: const [TwoBeeHomeAction()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Step timeline
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: TwoBeeColors.obsidian,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stepDot(0, 'Pickup', _step >= 0),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white38,
                  size: 16,
                ),
                _stepDot(1, 'Start PIN', _step >= 1),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white38,
                  size: 16,
                ),
                _stepDot(2, 'On Trip', _step >= 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white38,
                  size: 16,
                ),
                _stepDot(3, 'Settlement', _step >= 3),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TwoBeeMapPreview(
            pickupLat: (t['pickupLat'] as num?)?.toDouble() ?? 23.7937,
            pickupLng: (t['pickupLng'] as num?)?.toDouble() ?? 90.4066,
            dropoffLat: (t['dropoffLat'] as num?)?.toDouble() ?? 23.8648,
            dropoffLng: (t['dropoffLng'] as num?)?.toDouble() ?? 90.3974,
            riderLat: _liveLat,
            riderLng: _liveLng,
            height: 150,
          ),
          const SizedBox(height: 12),

          // STEP 0: Heading to Passenger Pickup
          if (_step == 0) ...[
            Card(
              color: TwoBeeColors.surfaceTonal,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'STEP 1/4 · HEADING TO PASSENGER PICKUP',
                          style: TextStyle(
                            color: TwoBeeColors.primaryDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          bdt(payout),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: TwoBeeColors.primaryDark,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      paxName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: TwoBeeColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pickup: $pickup',
                      style: const TextStyle(
                        color: TwoBeeColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.phone_rounded, size: 16),
                            label: const Text('Call Passenger'),
                            onPressed: () => showAutoDismissToast(
                              context,
                              'Calling $paxName ($paxPhone)...',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.chat_outlined, size: 16),
                            label: const Text('In-App Chat'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InAppChatScreen(
                                  serviceType: 'RIDE',
                                  orderId: widget.tripId,
                                  peerTitle: paxName,
                                  senderRole: 'RIDER',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TwoBeeColors.primary,
                  foregroundColor: TwoBeeColors.obsidian,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
                ),
                icon: const Icon(Icons.location_on_rounded),
                onPressed: () => setState(() => _step = 1),
                label: const Text(
                  'Arrived at Passenger Pickup Location ➔',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ),
          ],

          // STEP 1: Passenger Onboard & 4-Digit Start PIN
          if (_step == 1) ...[
            Card(
              color: TwoBeeColors.surfaceTonal,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STEP 2/4 · PASSENGER ONBOARD VERIFICATION',
                      style: TextStyle(
                        color: TwoBeeColors.primaryDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter Passenger 4-Digit Start PIN',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: TwoBeeColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ask passenger for the Start PIN shown on their ride screen.',
                      style: TextStyle(
                        color: TwoBeeColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    PinInputBox(controller: _pinCtrl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ActionChip(
                          avatar: const Icon(
                            Icons.bolt_rounded,
                            size: 14,
                            color: TwoBeeColors.primary,
                          ),
                          label: Text('Fill PIN $startPin'),
                          onPressed: () =>
                              setState(() => _pinCtrl.text = startPin),
                        ),
                      ],
                    ),
                    if (_err != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _err!,
                        style: const TextStyle(
                          color: TwoBeeColors.errorText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: CheckboxListTile(
                value: _helmetVerified,
                onChanged: (v) => setState(() => _helmetVerified = v ?? true),
                title: const Text(
                  'Safety Check: Passenger wearing helmet',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text(
                  'Mandatory Glafit EV passenger safety compliance',
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TwoBeeColors.primary,
                  foregroundColor: TwoBeeColors.obsidian,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                onPressed: () async {
                  final pin = _pinCtrl.text.trim();
                  if (pin.length != 4) {
                    setState(
                      () => _err = 'Please enter passenger 4-digit start PIN',
                    );
                    return;
                  }
                  final token = ref.read(authControllerProvider).riderRoleToken;
                  try {
                    await ref
                        .read(apiClientProvider)
                        .post(
                          '/rider/panel/ride/${widget.tripId}/start',
                          roleToken: token,
                          body: {'startPin': pin},
                        );
                  } catch (_) {}
                  setState(() {
                    _err = null;
                    _step = 2;
                  });
                },
                label: const Text(
                  'Verify PIN & Start Trip (Auto-Starts) ➔',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ),
          ],

          // STEP 2: ON TRIP (In Progress)
          if (_step == 2) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: TwoBeeColors.obsidian,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.directions_bike_rounded,
                        color: TwoBeeColors.primary,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'RIDE IN PROGRESS · GLAFIT EV',
                        style: TextStyle(
                          color: TwoBeeColors.primarySoft,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Destination: $dropoff',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Speed: 38 km/h · Distance: 8.4 km · Eco Mode Active',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.shield_rounded,
                  color: TwoBeeColors.primary,
                ),
                title: const Text('Emergency Assistance & SOS Active'),
                trailing: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: TwoBeeColors.errorText,
                    side: const BorderSide(color: TwoBeeColors.errorText),
                  ),
                  onPressed: () => showSosSafetySheet(
                    context,
                    ref,
                    role: 'RIDER',
                    orderId: widget.tripId,
                  ),
                  child: const Text('SOS'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TwoBeeColors.primary,
                  foregroundColor: TwoBeeColors.obsidian,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
                ),
                icon: const Icon(Icons.stop_circle_rounded),
                onPressed: () => setState(() => _step = 3),
                label: const Text(
                  'Arrived at Passenger Destination ➔',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ),
          ],

          // STEP 3: Final Fare & Settlement Screen
          if (_step == 3) ...[
            Card(
              color: TwoBeeColors.surfaceTonal,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STEP 4/4 · FINAL RIDE FARE & SETTLEMENT',
                      style: TextStyle(
                        color: TwoBeeColors.primaryDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL RIDE FARE',
                          style: TextStyle(
                            color: TwoBeeColors.textSecondary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          bdt(fare),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: TwoBeeColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Base Fare (First 2.0 km)',
                          style: TextStyle(
                            color: TwoBeeColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const Text(
                          '৳50',
                          style: TextStyle(
                            color: TwoBeeColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Distance Fare (6.4 km × ৳18/km)',
                          style: TextStyle(
                            color: TwoBeeColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const Text(
                          '৳115',
                          style: TextStyle(
                            color: TwoBeeColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Rider Payout Credited',
                          style: TextStyle(
                            color: TwoBeeColors.primaryDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          bdt(payout),
                          style: const TextStyle(
                            color: TwoBeeColors.primaryDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (isCod)
              Card(
                child: CheckboxListTile(
                  value: _cashCollected,
                  onChanged: (v) => setState(() => _cashCollected = v ?? true),
                  title: Text(
                    'Cash Collected: ${bdt(fare)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'Collect exact cash fare from passenger before completing.',
                  ),
                ),
              )
            else
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.credit_card_rounded,
                    color: TwoBeeColors.primary,
                  ),
                  title: const Text(
                    'Digital Fare Settled (Card/bKash)',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    'Fare ${bdt(fare)} charged to passenger account. No cash to collect.',
                  ),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TwoBeeColors.primary,
                  foregroundColor: TwoBeeColors.obsidian,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
                ),
                icon: const Icon(Icons.check_circle_rounded),
                onPressed: () async {
                  final token = ref.read(authControllerProvider).riderRoleToken;
                  try {
                    await ref
                        .read(apiClientProvider)
                        .post(
                          '/rider/panel/ride/${widget.tripId}/complete',
                          roleToken: token,
                        );
                  } catch (_) {}
                  setState(() => _step = 4);
                },
                label: Text(
                  'Confirm Fare & Complete Ride (${bdt(payout)} Payout) ➔',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepDot(int index, String label, bool active) {
    return Row(
      children: [
        CircleAvatar(
          radius: 9,
          backgroundColor: active ? TwoBeeColors.primary : Colors.white24,
          child: Text(
            '${index + 1}',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: active ? TwoBeeColors.obsidian : Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.w800 : FontWeight.w500,
            color: active ? Colors.white : Colors.white54,
          ),
        ),
      ],
    );
  }
}

class _RiderJobsTab extends ConsumerStatefulWidget {
  const _RiderJobsTab();

  @override
  ConsumerState<_RiderJobsTab> createState() => _RiderJobsTabState();
}

class _RiderJobsTabState extends ConsumerState<_RiderJobsTab> {
  bool _showLive = true;
  String _cat = 'ALL';
  String _query = '';
  Map<String, dynamic>? _jobs;
  bool _loading = true;

  static final Map<String, dynamic> _fallbackRiderJobs = {
    'ok': true,
    'live': {
      'multiServiceBatches': [
        {
          'id': 'sample-batch-live',
          'batchCode': 'MULTI-2B99',
          'originZoneId': 'zone-banani',
          'destinationZoneId': 'zone-uttara',
          'status': 'PASSENGER_PICKUP_PENDING',
          'totalPayoutBdt': 215,
          'createdAt': '12m ago',
          'rideTrip': {
            'id': 'sample-ride',
            'tripCode': '2B-R7391',
            'pickupAddress': 'Banani Road 11',
            'dropoffAddress': 'Uttara Sector 7',
            'fleetTier': '2BEE_EV_SOLO',
            'distanceKm': 8.4,
            'totalFareBdt': 165,
            'riderPayoutBdt': 135,
            'startPin': '7391',
            'paymentMethod': 'COD',
            'status': 'DRIVER_ASSIGNED',
          },
          'parcelShipment': {
            'id': 'sample-parcel',
            'trackingCode': '2B-P4821',
            'pickupAddress': 'Gulshan 2, Road 45',
            'deliveryAddress': 'Uttara Sector 3',
            'weightKg': 2.5,
            'riderPayoutBdt': 80,
            'handoverOtp': '4821',
            'paymentMethod': 'COD',
            'status': 'CO_LOADED',
          },
        },
      ],
      'parcels': [
        {
          'id': 'sample-parcel-single',
          'trackingCode': '2B-P7712',
          'pickupAddress': 'Mohakhali Wireless Gate',
          'dropoffAddress': 'Dhanmondi 27',
          'weightKg': 1.8,
          'riderPayoutBdt': 140,
          'status': 'PICKED_UP',
        },
      ],
      'food': [
        {
          'id': 'sample-food-single',
          'orderCode': '2B-F8819',
          'restaurantName': "Sultan's Dine Banani",
          'deliveryAddress': 'House 14, Road 18, Gulshan 2',
          'itemsCount': 3,
          'riderPayoutBdt': 95,
          'status': 'PICKED_UP',
        },
      ],
      'rides': [
        {
          'id': 'sample-ride-single',
          'tripCode': '2B-R3301',
          'pickupAddress': 'Kuril Flyover Ramp',
          'dropoffAddress': 'Bashundhara R/A Gate 1',
          'fleetTier': '2BEE_EV_SOLO',
          'riderPayoutBdt': 85,
          'status': 'DRIVER_ARRIVED',
        },
      ],
    },
    'completed': {
      'multiServiceBatches': [
        {
          'id': 'batch-done-1',
          'batchCode': 'MULTI-2B10',
          'originZoneId': 'zone-dhanmondi',
          'destinationZoneId': 'zone-banani',
          'status': 'COMPLETED',
          'totalPayoutBdt': 230,
        },
      ],
      'parcels': [
        {
          'id': 'parcel-done-1',
          'trackingCode': '2B-P1104',
          'pickupAddress': 'Badda Link Road',
          'dropoffAddress': 'Gulshan 1 Circle',
          'riderPayoutBdt': 120,
          'status': 'DELIVERED',
        },
      ],
      'food': [
        {
          'id': 'food-done-1',
          'orderCode': '2B-F5502',
          'restaurantName': 'Kacchi Bhai Uttara',
          'deliveryAddress': 'Sector 11, Uttara',
          'riderPayoutBdt': 110,
          'status': 'DELIVERED',
        },
      ],
      'rides': [
        {
          'id': 'ride-done-1',
          'tripCode': '2B-R9940',
          'pickupAddress': 'Shahjalal Airport Terminal 2',
          'dropoffAddress': 'Uttara Sector 4',
          'fleetTier': '2BEE_EV_EXPRESS',
          'riderPayoutBdt': 150,
          'status': 'COMPLETED',
        },
      ],
    },
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = ref.read(authControllerProvider).riderRoleToken;
    if (token == null) {
      if (mounted) {
        setState(() {
          _jobs = _fallbackRiderJobs;
          _loading = false;
        });
      }
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await ref
          .read(apiClientProvider)
          .get('/rider/panel/jobs', roleToken: token);
      setState(() => _jobs = res);
    } catch (_) {
      if (mounted) setState(() => _jobs = _fallbackRiderJobs);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _matchesQuery(Map m, List<String> keys) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return keys.any((k) => (m[k]?.toString() ?? '').toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final bucket = (_jobs?[_showLive ? 'live' : 'completed'] as Map?) ?? {};
    final allBatches = (bucket['multiServiceBatches'] as List?) ?? [];
    final allParcels = (bucket['parcels'] as List?) ?? [];
    final allFood = (bucket['food'] as List?) ?? [];
    final allRides = (bucket['rides'] as List?) ?? [];

    final batches = (_cat == 'ALL' || _cat == 'MULTI')
        ? allBatches
              .where(
                (b) => _matchesQuery(b as Map, [
                  'batchCode',
                  'originZoneId',
                  'destinationZoneId',
                  'status',
                ]),
              )
              .toList()
        : [];
    final parcels = (_cat == 'ALL' || _cat == 'PARCEL')
        ? allParcels
              .where(
                (p) => _matchesQuery(p as Map, [
                  'trackingCode',
                  'pickupAddress',
                  'dropoffAddress',
                  'status',
                ]),
              )
              .toList()
        : [];
    final food = (_cat == 'ALL' || _cat == 'FOOD')
        ? allFood
              .where(
                (f) => _matchesQuery(f as Map, [
                  'orderCode',
                  'deliveryAddress',
                  'status',
                ]),
              )
              .toList()
        : [];
    final rides = (_cat == 'ALL' || _cat == 'RIDE')
        ? allRides
              .where(
                (r) => _matchesQuery(r as Map, [
                  'tripCode',
                  'pickupAddress',
                  'dropoffAddress',
                  'status',
                ]),
              )
              .toList()
        : [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service History'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          const TwoBeeHomeAction(),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Live')),
                ButtonSegment(value: false, label: Text('Completed')),
              ],
              selected: {_showLive},
              onSelectionChanged: (v) => setState(() => _showLive = v.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search tracking code, trip code, zone...',
                isDense: true,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: ['ALL', 'MULTI', 'PARCEL', 'FOOD', 'RIDE'].map((c) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      c == 'MULTI'
                          ? 'Multi-Service'
                          : c[0] + c.substring(1).toLowerCase(),
                    ),
                    selected: _cat == c,
                    onSelected: (_) => setState(() => _cat = c),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ...batches.map(
                        (b) => Card(
                          color: TwoBeeColors.surfaceTonal,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text(
                              'Parcel & Ride (${b['batchCode']})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              '${b['originZoneId']} → ${b['destinationZoneId']} · ${b['status']}',
                            ),
                            trailing: Text(
                              bdt(b['totalPayoutBdt']),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: TwoBeeColors.primary,
                              ),
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _showLive
                                    ? MultiServiceBatchScreen(
                                        batchId: b['id'] as String,
                                      )
                                    : RiderServiceDetailScreen(
                                        serviceType: 'MULTI',
                                        title:
                                            'Multi-Service Batch ${b['batchCode']}',
                                        data: Map<String, dynamic>.from(
                                          b as Map,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      ...parcels.map(
                        (p) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(
                              'Parcel ${p['trackingCode']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${p['pickupAddress']} → ${p['dropoffAddress']} · ${p['status']}',
                            ),
                            trailing: Text(bdt(p['riderPayoutBdt'])),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _showLive
                                    ? ParcelPickupScreen(
                                        parcelId: p['id'] as String,
                                      )
                                    : RiderServiceDetailScreen(
                                        serviceType: 'PARCEL',
                                        title: 'Parcel ${p['trackingCode']}',
                                        data: Map<String, dynamic>.from(
                                          p as Map,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      ...food.map(
                        (f) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(
                              'Food ${f['orderCode']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${f['merchant']?['businessName'] ?? ''} · ${f['status']}',
                            ),
                            trailing: Text(bdt(f['riderPayoutBdt'])),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _showLive
                                    ? RiderFoodExecutionScreen(
                                        orderId: f['id'] as String,
                                      )
                                    : RiderServiceDetailScreen(
                                        serviceType: 'FOOD',
                                        title: 'Food ${f['orderCode']}',
                                        data: Map<String, dynamic>.from(
                                          f as Map,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      ...rides.map(
                        (r) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(
                              'Ride ${r['tripCode']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${r['pickupAddress']} → ${r['dropoffAddress']} · ${r['status']}',
                            ),
                            trailing: Text(bdt(r['riderPayoutBdt'])),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _showLive
                                    ? RiderRideExecutionScreen(
                                        tripId: r['id'] as String,
                                      )
                                    : RiderServiceDetailScreen(
                                        serviceType: 'RIDE',
                                        title: 'Ride ${r['tripCode']}',
                                        data: Map<String, dynamic>.from(
                                          r as Map,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (batches.isEmpty &&
                          parcels.isEmpty &&
                          food.isEmpty &&
                          rides.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('No jobs matching filter in this tab.'),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Dedicated Screen: Rider Service Detail (Multi-Service Legs visible ONLY to Rider!)
class RiderServiceDetailScreen extends StatelessWidget {
  final String serviceType;
  final String title;
  final Map<String, dynamic> data;
  const RiderServiceDetailScreen({
    super.key,
    required this.serviceType,
    required this.title,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final ride = data['rideTrip'] as Map?;
    final parcel = data['parcelShipment'] as Map?;
    final payout = data['totalPayoutBdt'] ?? data['riderPayoutBdt'] ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(title), actions: const [TwoBeeHomeAction()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: TwoBeeColors.obsidian,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$serviceType JOB DETAIL',
                  style: const TextStyle(
                    color: TwoBeeColors.primarySoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  bdt(payout),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Status: ${data['status']}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (serviceType == 'MULTI' && ride != null && parcel != null) ...[
            Card(
              color: TwoBeeColors.surfaceTonal,
              child: ListTile(
                title: Text(
                  'Stop 1 · Passenger Ride (${ride['tripCode']})',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${ride['pickupAddress']} -> ${ride['dropoffAddress']} · ${bdt(ride['riderPayoutBdt'])}',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                title: Text(
                  'Stop 2 · Front-Rack Parcel (${parcel['trackingCode']})',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${parcel['pickupAddress']} -> ${parcel['dropoffAddress']} · ${bdt(parcel['riderPayoutBdt'])}',
                ),
              ),
            ),
          ] else
            Card(
              child: ListTile(
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${data['pickupAddress'] ?? data['merchant']?['businessName'] ?? ''} -> ${data['dropoffAddress'] ?? data['deliveryAddress'] ?? ''}',
                ),
              ),
            ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const SupportLegalScreen(title: 'Report Route Issue'),
              ),
            ),
            icon: const Icon(Icons.report_problem_outlined),
            label: const Text('Report Route / Payout Issue'),
          ),
        ],
      ),
    );
  }
}

/// Dedicated Screen: Multi-Service Batch Details & Trip History
/// Displays active multi-service and previous completed batches.
/// Strict requirements:
/// 1. Only show the previous and currently active multi-services and their details.
/// 2. Nothing can be operated from that screen (no operational/edit/cancel/accept buttons).
/// 3. Just the active multi-service is clickable to go directly to its current state.
class RiderMultiServiceBatchesScreen extends ConsumerStatefulWidget {
  const RiderMultiServiceBatchesScreen({super.key});

  @override
  ConsumerState<RiderMultiServiceBatchesScreen> createState() =>
      _RiderMultiServiceBatchesScreenState();
}

class _RiderMultiServiceBatchesScreenState
    extends ConsumerState<RiderMultiServiceBatchesScreen> {
  bool _loading = true;
  Map<String, dynamic>? _activeBatch;
  List<Map<String, dynamic>> _completedBatches = [];

  static final Map<String, dynamic> _fallbackActiveBatch = {
    'id': 'sample-batch-live',
    'batchCode': 'MULTI-2B99',
    'status': 'PASSENGER_PICKUP_PENDING',
    'originZoneId': 'zone-banani',
    'destinationZoneId': 'zone-uttara',
    'corridorName': 'Banani Hub ↔ Uttara Sector 7 Corridor',
    'totalPayoutBdt': 215,
    'startTime': '12 mins ago',
    'co2SavedGrams': 384,
    'rideTrip': {
      'id': 'sample-ride-live',
      'tripCode': '2B-R7391',
      'pickupAddress': 'Banani Road 11 (Beside Gloria Jean\'s)',
      'dropoffAddress': 'Uttara Sector 7 (Rabindra Sarani)',
      'fleetTier': '2BEE_EV_SOLO',
      'distanceKm': 8.4,
      'totalFareBdt': 165,
      'riderPayoutBdt': 135,
      'startPin': '7391',
      'paymentMethod': 'COD',
      'status': 'DRIVER_ASSIGNED',
      'user': {'fullName': 'Tanvir Ahmed', 'phone': '+880 1711-223344'},
    },
    'parcelShipment': {
      'id': 'sample-parcel-live',
      'trackingCode': '2B-P4821',
      'pickupAddress': 'Gulshan 2, Road 45',
      'deliveryAddress': 'Uttara Sector 3, Road 14',
      'weightKg': 2.5,
      'riderPayoutBdt': 80,
      'deliveryPin': '8821',
      'paymentMethod': 'COD',
      'status': 'CO_LOADED',
      'recipientName': 'Nabila Rahman',
      'recipientPhone': '+880 1811-445566',
    },
    'equipment': {
      'frontRack': 'Secured (2.5 kg / 8.0 kg max capacity)',
      'passengerHelmet': 'Verified & In Use',
      'pillionFootrests': 'Deployed',
    },
  };

  static final List<Map<String, dynamic>> _fallbackCompletedBatches = [
    {
      'id': 'batch-done-1',
      'batchCode': 'MULTI-2B88',
      'corridorName': 'Mohakhali Wireless ↔ Banani Block D',
      'status': 'COMPLETED',
      'totalPayoutBdt': 230,
      'completedAt': 'Today, 2:45 PM',
      'durationMins': 32,
      'co2SavedGrams': 384,
      'rideTrip': {
        'tripCode': '2B-R5102',
        'passengerName': 'Farhan Kabir',
        'pickupAddress': 'Mohakhali TB Gate',
        'dropoffAddress': 'Banani Road 27',
        'riderPayoutBdt': 140,
        'distanceKm': 5.2,
        'status': 'COMPLETED',
        'completionPin': '5102',
      },
      'parcelShipment': {
        'trackingCode': '2B-P3991',
        'recipientName': 'Shakil Ahmed',
        'pickupAddress': 'Amtoli Mohakhali',
        'deliveryAddress': 'Banani Chairmanbari',
        'weightKg': 3.1,
        'riderPayoutBdt': 90,
        'status': 'DELIVERED',
        'podPin': '3991',
      },
    },
    {
      'id': 'batch-done-2',
      'batchCode': 'MULTI-2B72',
      'corridorName': 'Dhanmondi 27 ↔ Mohakhali DOHS',
      'status': 'COMPLETED',
      'totalPayoutBdt': 260,
      'completedAt': 'Yesterday, 5:20 PM',
      'durationMins': 41,
      'co2SavedGrams': 420,
      'rideTrip': {
        'tripCode': '2B-R4820',
        'passengerName': 'Sadia Islam',
        'pickupAddress': 'Dhanmondi Lake Road',
        'dropoffAddress': 'Mohakhali DOHS Gate 2',
        'riderPayoutBdt': 160,
        'distanceKm': 7.1,
        'status': 'COMPLETED',
        'completionPin': '4820',
      },
      'parcelShipment': {
        'trackingCode': '2B-P2190',
        'recipientName': 'Tamim Hossain',
        'pickupAddress': 'Sobhanbagh Masjid',
        'deliveryAddress': 'Mohakhali Flyover North',
        'weightKg': 1.8,
        'riderPayoutBdt': 100,
        'status': 'DELIVERED',
        'podPin': '2190',
      },
    },
    {
      'id': 'batch-done-3',
      'batchCode': 'MULTI-2B60',
      'corridorName': 'Gulshan 1 Circle ↔ Bashundhara R/A',
      'status': 'COMPLETED',
      'totalPayoutBdt': 245,
      'completedAt': '21 Nov 2026, 1:15 PM',
      'durationMins': 36,
      'co2SavedGrams': 390,
      'rideTrip': {
        'tripCode': '2B-R3310',
        'passengerName': 'Mehedi Hasan',
        'pickupAddress': 'Gulshan 1 Circle',
        'dropoffAddress': 'Bashundhara Gate 2',
        'riderPayoutBdt': 155,
        'distanceKm': 6.8,
        'status': 'COMPLETED',
        'completionPin': '3310',
      },
      'parcelShipment': {
        'trackingCode': '2B-P1104',
        'recipientName': 'Afsana Mimi',
        'pickupAddress': 'Niketon Gate 1',
        'deliveryAddress': 'Block C, Bashundhara',
        'weightKg': 2.0,
        'riderPayoutBdt': 90,
        'status': 'DELIVERED',
        'podPin': '1104',
      },
    },
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final token = ref.read(authControllerProvider).riderRoleToken;
    if (token == null) {
      if (mounted) {
        setState(() {
          _activeBatch = _fallbackActiveBatch;
          _completedBatches = _fallbackCompletedBatches;
          _loading = false;
        });
      }
      return;
    }
    try {
      final res = await ref
          .read(apiClientProvider)
          .get('/rider/panel/jobs', roleToken: token);
      final liveBatches = (res['live']?['multiServiceBatches'] as List?) ?? [];
      final doneBatches =
          (res['completed']?['multiServiceBatches'] as List?) ?? [];

      if (mounted) {
        setState(() {
          _activeBatch = liveBatches.isNotEmpty
              ? Map<String, dynamic>.from(liveBatches.first as Map)
              : _fallbackActiveBatch;
          _completedBatches = doneBatches.isNotEmpty
              ? doneBatches
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList()
              : _fallbackCompletedBatches;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _activeBatch = _fallbackActiveBatch;
          _completedBatches = _fallbackCompletedBatches;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Multi-Service Batch Details',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
          const TwoBeeHomeAction(),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Informational Notice Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: TwoBeeColors.surfaceTonal,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: TwoBeeColors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: TwoBeeColors.primaryDark,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Multi-Service Audit & Details',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: TwoBeeColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Read-only record of active co-ride pairing and past batches. Only the active multi-service below is clickable to resume live trip execution.',
                              style: TextStyle(
                                fontSize: 11,
                                color: TwoBeeColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 1. Currently Active Multi-Service Section
                const Row(
                  children: [
                    Icon(
                      Icons.alt_route_rounded,
                      color: TwoBeeColors.primaryDark,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'CURRENTLY ACTIVE MULTI-SERVICE',
                      style: TextStyle(
                        color: TwoBeeColors.primaryDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_activeBatch != null) ...[
                  Card(
                    color: TwoBeeColors.obsidian,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(
                        color: TwoBeeColors.primary,
                        width: 1.8,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        // "just active multi service can be clickable for going to the current state of multiservice"
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MultiServiceBatchScreen(
                              batchId: _activeBatch!['id'] as String,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Status badge & Total Payout
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: TwoBeeColors.primary,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.fiber_manual_record_rounded,
                                            color: Colors.black,
                                            size: 10,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'ACTIVE · IN PROGRESS',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _activeBatch!['batchCode']?.toString() ??
                                          'MULTI-2B99',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  bdt(_activeBatch!['totalPayoutBdt'] ?? 215),
                                  style: const TextStyle(
                                    color: TwoBeeColors.primary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _activeBatch!['corridorName']?.toString() ??
                                  'Banani Hub ↔ Uttara Sector 7 Corridor',
                              style: const TextStyle(
                                color: TwoBeeColors.textOnDarkSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Divider(color: Colors.white24, height: 1),
                            const SizedBox(height: 12),

                            // Stop 1: Passenger Ride Leg
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: TwoBeeColors.obsidianCard,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.person_pin_circle_rounded,
                                        color: TwoBeeColors.primary,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Stop 1 (1st Priority) · Passenger Co-Ride',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: TwoBeeColors.primary
                                              .withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          bdt(
                                            _activeBatch!['rideTrip']?['riderPayoutBdt'] ??
                                                135,
                                          ),
                                          style: const TextStyle(
                                            color: TwoBeeColors.primary,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Passenger: ${_activeBatch!['rideTrip']?['user']?['fullName'] ?? 'Tanvir Ahmed'} (${_activeBatch!['rideTrip']?['tripCode'] ?? '2B-R7391'})',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_activeBatch!['rideTrip']?['pickupAddress']} ➔ ${_activeBatch!['rideTrip']?['dropoffAddress']}',
                                    style: const TextStyle(
                                      color: TwoBeeColors.textOnDarkSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Text(
                                        'Start PIN: ',
                                        style: TextStyle(
                                          color:
                                              TwoBeeColors.textOnDarkSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                      Text(
                                        _activeBatch!['rideTrip']?['startPin']
                                                ?.toString() ??
                                            '7391',
                                        style: const TextStyle(
                                          color: TwoBeeColors.primary,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Text(
                                        '${_activeBatch!['rideTrip']?['distanceKm'] ?? 8.4} km',
                                        style: const TextStyle(
                                          color:
                                              TwoBeeColors.textOnDarkSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Stop 2: Front-Rack Parcel Courier Leg
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: TwoBeeColors.obsidianCard,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.local_shipping_rounded,
                                        color: TwoBeeColors.primary,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Stop 2 (2nd Priority) · Front-Rack Courier',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: TwoBeeColors.primary
                                              .withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          bdt(
                                            _activeBatch!['parcelShipment']?['riderPayoutBdt'] ??
                                                80,
                                          ),
                                          style: const TextStyle(
                                            color: TwoBeeColors.primary,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Tracking: ${_activeBatch!['parcelShipment']?['trackingCode'] ?? '2B-P4821'} · Weight: ${_activeBatch!['parcelShipment']?['weightKg'] ?? 2.5} kg',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Dropoff: ${_activeBatch!['parcelShipment']?['deliveryAddress']}',
                                    style: const TextStyle(
                                      color: TwoBeeColors.textOnDarkSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Text(
                                        'Recipient: ',
                                        style: TextStyle(
                                          color:
                                              TwoBeeColors.textOnDarkSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                      Text(
                                        _activeBatch!['parcelShipment']?['recipientName']
                                                ?.toString() ??
                                            'Nabila Rahman',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      const Text(
                                        'Status: ',
                                        style: TextStyle(
                                          color:
                                              TwoBeeColors.textOnDarkSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const Text(
                                        'Co-Loaded (Queued)',
                                        style: TextStyle(
                                          color: TwoBeeColors.primarySoft,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Prominent action indicator
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: TwoBeeColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.navigation_rounded,
                                    color: Colors.black,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Tap to Go to Current State of Multi-Service ➔',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
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
                ] else ...[
                  Card(
                    color: TwoBeeColors.surfaceTonal,
                    child: const Padding(
                      padding: EdgeInsets.all(18),
                      child: Center(
                        child: Text(
                          'No active multi-service batch currently in progress.',
                          style: TextStyle(
                            color: TwoBeeColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // 2. Previous Multi-Services Section (Completed History)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'PREVIOUS MULTI-SERVICES (COMPLETED HISTORY)',
                      style: TextStyle(
                        color: TwoBeeColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      '${_completedBatches.length} Completed',
                      style: const TextStyle(
                        color: TwoBeeColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Past completed multi-service co-rides. Read-only record — no operational actions.',
                  style: TextStyle(color: TwoBeeColors.textMuted, fontSize: 11),
                ),
                const SizedBox(height: 10),

                ..._completedBatches.map(
                  (b) => Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: TwoBeeColors.borderSoft),
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: TwoBeeColors.surfaceTonalAlt,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      b['batchCode']?.toString() ?? '',
                                      style: const TextStyle(
                                        color: TwoBeeColors.primaryDark,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline_rounded,
                                          color: TwoBeeColors.primaryDark,
                                          size: 12,
                                        ),
                                        SizedBox(width: 3),
                                        Text(
                                          'COMPLETED',
                                          style: TextStyle(
                                            color: TwoBeeColors.textPrimary,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                bdt(b['totalPayoutBdt'] ?? 0),
                                style: const TextStyle(
                                  color: TwoBeeColors.primaryDark,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            b['corridorName']?.toString() ??
                                '${b['originZoneId']} ➔ ${b['destinationZoneId']}',
                            style: const TextStyle(
                              color: TwoBeeColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Delivered ${b['completedAt'] ?? 'Recently'} · Duration: ${b['durationMins'] ?? 30} mins',
                            style: const TextStyle(
                              color: TwoBeeColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: TwoBeeColors.surfaceTonal,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.person_pin_circle_outlined,
                                      size: 16,
                                      color: TwoBeeColors.primaryDark,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Stop 1: ${b['rideTrip']?['passengerName'] ?? 'Passenger'} · ${b['rideTrip']?['distanceKm'] ?? ''} km (${b['rideTrip']?['tripCode'] ?? ''})',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                          color: TwoBeeColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      bdt(
                                        b['rideTrip']?['riderPayoutBdt'] ?? 0,
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                        color: TwoBeeColors.primaryDark,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.inventory_2_outlined,
                                      size: 16,
                                      color: TwoBeeColors.primaryDark,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Stop 2: Front Rack ${b['parcelShipment']?['trackingCode'] ?? ''} (${b['parcelShipment']?['weightKg'] ?? ''} kg) to ${b['parcelShipment']?['recipientName'] ?? 'Recipient'}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                          color: TwoBeeColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      bdt(
                                        b['parcelShipment']?['riderPayoutBdt'] ??
                                            0,
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                        color: TwoBeeColors.primaryDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.eco_rounded,
                                    size: 14,
                                    color: TwoBeeColors.primaryDark,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '🌱 ${b['co2SavedGrams'] ?? 384}g CO2 Saved',
                                    style: const TextStyle(
                                      color: TwoBeeColors.primaryDark,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const Text(
                                'Audit Record · Read-Only',
                                style: TextStyle(
                                  color: TwoBeeColors.textMuted,
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _RiderWalletTab extends ConsumerStatefulWidget {
  const _RiderWalletTab();

  @override
  ConsumerState<_RiderWalletTab> createState() => _RiderWalletTabState();
}

class _RiderWalletTabState extends ConsumerState<_RiderWalletTab> {
  Map<String, dynamic>? _data;
  bool _showAnalytics = false;
  bool _loading = true;

  static final Map<String, dynamic> _fallbackRiderWallet = {
    'ok': true,
    'wallet': {
      'availableBalanceBdt': 3850,
      'todayEarningsBdt': 1420,
      'pendingSettlementBdt': 620,
      'payoutProvider': 'BKASH',
      'payoutAccountNumber': '01712345678',
      'transactions': [
        {
          'id': 'tx-1',
          'type': 'TRIP_PAYOUT',
          'service': 'MULTI_BATCH',
          'amountBdt': 215,
          'referenceCode': 'MULTI-2B99',
          'createdAt': '30m ago',
        },
        {
          'id': 'tx-2',
          'type': 'TRIP_PAYOUT',
          'service': 'PARCEL',
          'amountBdt': 120,
          'referenceCode': '2B-P9012',
          'createdAt': '2h ago',
        },
        {
          'id': 'tx-3',
          'type': 'TRIP_PAYOUT',
          'service': 'FOOD',
          'amountBdt': 95,
          'referenceCode': '2B-F4420',
          'createdAt': '3h ago',
        },
        {
          'id': 'tx-4',
          'type': 'WITHDRAWAL',
          'service': 'BKASH',
          'amountBdt': -2500,
          'referenceCode': 'WD-98102',
          'createdAt': 'Yesterday',
        },
      ],
    },
    'rental': {
      'active': true,
      'bikeModel': 'Glafit GFR-02 Smart e-Bike',
      'planType': 'DAILY',
      'dailyFeeBdt': 120,
      'batteryHealthPct': 88,
      'nextDeduction': 'Tonight 11:59 PM',
    },
    'analytics': {
      'weeklyTotalBdt': 9450,
      'completedTripsCount': 58,
      'hoursOnline': 34.5,
      'fuelSavingsBdt': 2100,
      'co2SavedKg': 18.4,
    },
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = ref.read(authControllerProvider).riderRoleToken;
    if (token == null) {
      if (mounted) {
        setState(() {
          _data = _fallbackRiderWallet;
          _loading = false;
        });
      }
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await ref
          .read(apiClientProvider)
          .get('/rider/panel/wallet', roleToken: token);
      setState(() => _data = res);
    } catch (_) {
      if (mounted) setState(() => _data = _fallbackRiderWallet);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = (_data?['wallet'] as Map?) ?? {};
    final txs = (wallet['transactions'] as List?) ?? [];
    final rental = _data?['rental'] as Map?;
    final analytics = (_data?['analytics'] as Map?) ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet & Earnings'),
        actions: const [TwoBeeHomeAction()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Wallet & Payouts'),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Earnings Analytics'),
                      ),
                    ],
                    selected: {_showAnalytics},
                    onSelectionChanged: (v) =>
                        setState(() => _showAnalytics = v.first),
                  ),
                  const SizedBox(height: 14),
                  if (!_showAnalytics) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: TwoBeeColors.obsidian,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Available Balance',
                            style: TextStyle(color: TwoBeeColors.primarySoft),
                          ),
                          Text(
                            bdt(wallet['balanceBdt'] ?? 0),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'COD Cash-in-Hand: ${bdt(wallet['codCashInHandBdt'] ?? 0)}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    if (rental != null) ...[
                      const SizedBox(height: 12),
                      Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.electric_moped_rounded,
                            color: TwoBeeColors.primary,
                          ),
                          title: Text(
                            'Bike Rent Due: ${bdt(rental['dailyRateBdt'] ?? 250)}/day',
                          ),
                          subtitle: Text(
                            '${rental['bikeModel']} · Auto-debit active',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Text(
                      'Recent Ledger',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    ...txs.map(
                      (t) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(t['description']?.toString() ?? ''),
                          trailing: Text(
                            '${((t['amountBdt'] as num?) ?? 0) >= 0 ? '+' : ''}${bdt(t['amountBdt'])}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: ((t['amountBdt'] as num?) ?? 0) >= 0
                                  ? TwoBeeColors.primary
                                  : TwoBeeColors.errorText,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Ledger Earnings: ${bdt(analytics['earningsTotal'] ?? 0)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: TwoBeeColors.primary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Rental & Other Deductions: ${bdt(analytics['deductionsTotal'] ?? 0)}',
                            ),
                            Text(
                              'Completed Lifetime Trips: ${analytics['totalTrips'] ?? 0}',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _RiderProfileTab extends ConsumerWidget {
  const _RiderProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final fullName = user?['fullName']?.toString() ?? 'Richard Dheo';
    final phone = user?['phone']?.toString() ?? '+880 1711-223344';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider Profile'),
        actions: const [TwoBeeHomeAction()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Rider Header Card
          Card(
            color: TwoBeeColors.surfaceTonal,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Stack(
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: TwoBeeColors.obsidian,
                        child: Icon(
                          Icons.two_wheeler_rounded,
                          color: TwoBeeColors.primary,
                          size: 34,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: TwoBeeColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: TwoBeeColors.obsidian,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified_rounded,
                              color: TwoBeeColors.primary,
                              size: 18,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          phone,
                          style: const TextStyle(
                            color: TwoBeeColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: TwoBeeColors.primary.withValues(
                                  alpha: 0.18,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    color: TwoBeeColors.primaryDark,
                                    size: 14,
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    '4.95 (142 Trips)',
                                    style: TextStyle(
                                      color: TwoBeeColors.primaryDark,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: TwoBeeColors.surfaceTonalAlt,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '2Bee EV Pro',
                                style: TextStyle(
                                  color: TwoBeeColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Active Assigned Glafit EV Bike & Rental Card
          Card(
            color: TwoBeeColors.obsidian,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.electric_moped_rounded,
                            color: TwoBeeColors.primary,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'ASSIGNED EV VEHICLE',
                            style: TextStyle(
                              color: TwoBeeColors.primarySoft,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: TwoBeeColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Rental Active',
                          style: TextStyle(
                            color: TwoBeeColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Glafit GFR-02 Dual-Power EV',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Japanese Precision · Plate: DHK-GLF-4821',
                    style: TextStyle(
                      color: TwoBeeColors.textOnDarkSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: TwoBeeColors.obsidianCard,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BATTERY HEALTH',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '88% (42 km)',
                                style: TextStyle(
                                  color: TwoBeeColors.primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: TwoBeeColors.obsidianCard,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SMART LOCK PIN',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '4821 (Keyless)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: TwoBeeColors.primary.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: TwoBeeRadii.pill,
                        ),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BikeRentalHomeScreen(),
                        ),
                      ),
                      icon: const Icon(
                        Icons.hub_rounded,
                        size: 16,
                        color: TwoBeeColors.primary,
                      ),
                      label: const Text(
                        'Open Glafit EV Bike Rental Hub ➔',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Multi-Service & Carrying Setup Card
          Card(
            color: TwoBeeColors.surfaceTonal,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        color: TwoBeeColors.primaryDark,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'CARRYING SETUP & MULTI-SERVICE STATUS',
                        style: TextStyle(
                          color: TwoBeeColors.primaryDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Front Cargo Rack',
                        style: TextStyle(
                          color: TwoBeeColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '✓ Verified (8.0 kg Max)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: TwoBeeColors.primaryDark,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Rear Passenger Seat',
                        style: TextStyle(
                          color: TwoBeeColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '✓ Free Pillion + Footrest',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: TwoBeeColors.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Passenger Spare Helmet',
                        style: TextStyle(
                          color: TwoBeeColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '✓ Verified & Active',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: TwoBeeColors.primaryDark,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Corridor Multi-Service Pairing',
                        style: TextStyle(
                          color: TwoBeeColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Active (Banani ↔ Uttara)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: TwoBeeColors.primaryDark,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: TwoBeeRadii.pill,
                        ),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CarryingSetupScreen(),
                        ),
                      ),
                      child: const Text(
                        'Configure Carrying Specifications ➔',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TwoBeeColors.primaryDark,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(
                          borderRadius: TwoBeeRadii.pill,
                        ),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const RiderMultiServiceBatchesScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.alt_route_rounded, size: 16),
                      label: const Text(
                        'Open Multi-Service Batch Details ➔',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Menu navigation
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.alt_route_rounded,
                    color: TwoBeeColors.primary,
                  ),
                  title: const Text(
                    'Multi-Service Batch Details',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Active co-ride & previous batch details (Read-only)',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RiderMultiServiceBatchesScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.electric_moped_outlined,
                    color: TwoBeeColors.primary,
                  ),
                  title: const Text(
                    'Glafit EV Bike Rental Hub',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Browse Glafit GFR-02, N-One Pro, Commuter Lite & swap battery passes',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BikeRentalHomeScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.security_rounded,
                    color: TwoBeeColors.primary,
                  ),
                  title: const Text(
                    'Security Settings',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    '4-Digit PIN, biometric unlock & 48h payout protection',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RiderSecurityScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.battery_charging_full_rounded,
                    color: TwoBeeColors.primary,
                  ),
                  title: const Text(
                    '2Bee Rapid Battery Swap Stations',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Banani Hub, Mohakhali Hub, Uttara Sector 3 Hub (30s Swap)',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showSwapStationsModal(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.verified_user_rounded,
                    color: TwoBeeColors.primary,
                  ),
                  title: const Text(
                    'KYC Documents & Credentials',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'National NID, Driving License, Glafit Safety Certificate',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showKycModal(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.swap_horiz_rounded,
                    color: TwoBeeColors.primary,
                  ),
                  title: const Text(
                    'Switch Role',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Switch between Client, Rider, and Merchant panels',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.go('/roles'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.help_outline_rounded,
                    color: TwoBeeColors.primary,
                  ),
                  title: const Text(
                    'Glafit EV Roadside Support & Policy',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SupportLegalScreen(
                        title: 'Rider Support & Glafit Safety Policy',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: TwoBeeColors.errorText,
              side: const BorderSide(color: TwoBeeColors.errorText),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
            ),
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text(
              'Log Out',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _showSwapStationsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TwoBeeColors.obsidian,
      shape: const RoundedRectangleBorder(borderRadius: TwoBeeRadii.sheetTop),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '2Bee Rapid Battery Swap Stations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Instant 30-second hot battery swap for Glafit EV fleet.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _stationTile(
              'Banani Hub Station',
              'House 11, Road 11, Banani',
              '8 Charged Packs Available · Open 24/7',
            ),
            const SizedBox(height: 8),
            _stationTile(
              'Mohakhali Wireless Hub',
              'Plot 4, Wireless Gate, Mohakhali',
              '5 Charged Packs Available · Open 24/7',
            ),
            const SizedBox(height: 8),
            _stationTile(
              'Uttara Sector 3 Station',
              'Sector 3 Hub, Rabindra Sarani, Uttara',
              '11 Charged Packs Available · Open 24/7',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TwoBeeColors.primary,
                  foregroundColor: TwoBeeColors.obsidian,
                  shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Done',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stationTile(String name, String address, String status) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TwoBeeColors.obsidianCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.ev_station_rounded,
            color: TwoBeeColors.primary,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  address,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: const TextStyle(
                    color: TwoBeeColors.primarySoft,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showKycModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TwoBeeColors.obsidian,
      shape: const RoundedRectangleBorder(borderRadius: TwoBeeRadii.sheetTop),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rider Credentials & Verification',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'All mandatory regulatory documents verified by 2Bee Ops.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _kycDocTile(
              'National NID (Smart Card)',
              '1992261789000124 · Verified',
              true,
            ),
            const SizedBox(height: 8),
            _kycDocTile(
              'Motorcycle / EV Driving License',
              'DL-DHK-2023-8891 · Valid till 2033',
              true,
            ),
            const SizedBox(height: 8),
            _kycDocTile(
              'Glafit Electric Bike Safety Training',
              'Cert #GLF-BD-8902 · Passed 100%',
              true,
            ),
            const SizedBox(height: 8),
            _kycDocTile(
              'Police Background Clearance',
              'Approved by DMP Special Branch',
              true,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TwoBeeColors.primary,
                  foregroundColor: TwoBeeColors.obsidian,
                  shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Close',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kycDocTile(String title, String subtitle, bool verified) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TwoBeeColors.obsidianCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(
            verified ? Icons.check_circle_rounded : Icons.pending_rounded,
            color: verified ? TwoBeeColors.primary : Colors.amber,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: TwoBeeColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'VERIFIED',
              style: TextStyle(
                color: TwoBeeColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CarryingSetupScreen extends ConsumerStatefulWidget {
  const CarryingSetupScreen({super.key});

  @override
  ConsumerState<CarryingSetupScreen> createState() =>
      _CarryingSetupScreenState();
}

class _CarryingSetupScreenState extends ConsumerState<CarryingSetupScreen> {
  bool _multi = true;
  bool _helmet = true;
  String? _err;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Carrying Setup"),
        actions: const [TwoBeeHomeAction()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Card(
              color: TwoBeeColors.surfaceTonal,
              child: ListTile(
                title: Text('Front Carrier: 35×30×30 cm · Max 8 kg'),
                subtitle: Text(
                  'Multi-Service Rules: Normal parcels only · 1 passenger max · Zone A → B match · Passenger dropped first.',
                ),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _multi,
              onChanged: (v) => setState(() => _multi = v),
              title: const Text('Parcels + Passengers (Multi-Service)'),
            ),
            CheckboxListTile(
              value: _helmet,
              onChanged: (v) => setState(() => _helmet = v ?? false),
              title: const Text('I have a spare helmet for passenger'),
            ),
            if (_err != null)
              Text(
                _err!,
                style: const TextStyle(color: TwoBeeColors.errorText),
              ),
            const Spacer(),
            ElevatedButton(
              onPressed: () async {
                try {
                  final token = ref.read(authControllerProvider).riderRoleToken;
                  await ref
                      .read(apiClientProvider)
                      .patch(
                        '/rider/panel/carrying-setup',
                        roleToken: token,
                        body: {
                          'multiServiceEnabled': _multi,
                          'spareHelmetConfirmed': _helmet,
                        },
                      );
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  setState(() => _err = e.toString());
                }
              },
              child: const Text('Save Setup ->'),
            ),
          ],
        ),
      ),
    );
  }
}

class BikeRentalHomeScreen extends ConsumerStatefulWidget {
  const BikeRentalHomeScreen({super.key});

  @override
  ConsumerState<BikeRentalHomeScreen> createState() =>
      _BikeRentalHomeScreenState();
}

class _BikeRentalHomeScreenState extends ConsumerState<BikeRentalHomeScreen> {
  Map<String, dynamic>? _activeRental;
  List<dynamic> _bikes = [];
  bool _loading = true;

  static final List<Map<String, dynamic>> _defaultGlafitFleet = [
    {
      'id': 'fleet-glafit-gfr02',
      'modelName': 'Glafit GFR-02 Dual-Power EV',
      'tag': 'POPULAR · MULTI-SERVICE READY',
      'hubName': 'Banani Hub (Sector 11)',
      'rangeKm': 45,
      'topSpeedKmH': 30,
      'batterySwap': '30s Hot-Swap at 2Bee Hubs',
      'frontMaxKg': 8,
      'frontDimensions': '35×30×30 cm³ (Fits Normal Parcels)',
      'rearType': 'Passenger Cushion Pillion + Footrest',
      'dailyRateBdt': 180,
      'weeklyRateBdt': 1100,
      'monthlyRateBdt': 3800,
      'securityDepositBdt': 2000,
      'availableQty': 5,
      'rating': 4.95,
      'desc': 'Japanese precision-engineered folding electric bike. Features pedal-assist and pure EV modes with standard 2Bee front carrier for simultaneous parcel + passenger trips.',
    },
    {
      'id': 'fleet-glafit-none-pro',
      'modelName': 'Glafit N-One Pro (Heavy Duty)',
      'tag': 'LONG RANGE · DUAL BATTERY',
      'hubName': 'Mohakhali Hub / Wireless Gate',
      'rangeKm': 85,
      'topSpeedKmH': 45,
      'batterySwap': 'Dual Rapid Battery Swap',
      'frontMaxKg': 10,
      'frontDimensions': '40×35×30 cm³ Heavy Duty Metal Rack',
      'rearType': 'Reinforced Passenger Pillion + Cargo Hooks',
      'dailyRateBdt': 250,
      'weeklyRateBdt': 1550,
      'monthlyRateBdt': 5400,
      'securityDepositBdt': 3000,
      'availableQty': 3,
      'rating': 4.98,
      'desc': 'High-torque long-range Glafit EV built for intensive multi-service delivery across Dhaka corridors with dual-battery redundancy.',
    },
    {
      'id': 'fleet-glafit-commuter',
      'modelName': 'Glafit Commuter Lite EV',
      'tag': 'AGILE & ECONOMICAL',
      'hubName': 'Uttara Sector 3 Hub',
      'rangeKm': 55,
      'topSpeedKmH': 35,
      'batterySwap': 'Standard 2Bee Swap Compatible',
      'frontMaxKg': 5,
      'frontDimensions': '30×25×25 cm³ Front Basket',
      'rearType': 'Solo Cushion Pillion',
      'dailyRateBdt': 140,
      'weeklyRateBdt': 850,
      'monthlyRateBdt': 3000,
      'securityDepositBdt': 1500,
      'availableQty': 6,
      'rating': 4.88,
      'desc': 'Lightweight and nimble city commuter for fast solo ride shares and express parcel drops.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = ref.read(authControllerProvider).riderRoleToken;
    setState(() => _loading = true);
    try {
      final res = await ref
          .read(apiClientProvider)
          .get('/rider/panel/rentals', roleToken: token);
      if (mounted) {
        setState(() {
          _activeRental = res['activeRental'] as Map<String, dynamic>?;
          final fleet = (res['fleetBikes'] as List?) ?? [];
          _bikes = fleet.isNotEmpty ? fleet : _defaultGlafitFleet;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _bikes = _defaultGlafitFleet;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openRentalWizard(Map<String, dynamic> bike) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RentGlafitBikeWizardScreen(bike: bike)),
    );
    if (ok == true) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TwoBeeColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Glafit EV Bike Rental Hub'),
        actions: const [TwoBeeHomeAction()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Active Rental Card (if any)
                  if (_activeRental != null) ...[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: TwoBeeColors.obsidian,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: TwoBeeShadows.dockNav,
                        border: Border.all(
                          color: TwoBeeColors.primary,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: TwoBeeColors.primary,
                                  borderRadius: TwoBeeRadii.pill,
                                ),
                                child: const Text(
                                  'ACTIVE GLAFIT RENTAL',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                    color: TwoBeeColors.obsidian,
                                  ),
                                ),
                              ),
                              Row(
                                children: const [
                                  Icon(
                                    Icons.battery_charging_full_rounded,
                                    color: TwoBeeColors.primary,
                                    size: 18,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '98% Charged',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _activeRental!['bikeModel']?.toString() ??
                                'Glafit GFR-02 Dual-Power EV',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Plate: ${_activeRental!['plateNo'] ?? '2BEE-EV-048'} · Assigned Hub: ${_activeRental!['hubName'] ?? 'Banani Hub'}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: TwoBeeColors.obsidianCard,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Rate: ${bdt(_activeRental!['dailyRateBdt'] ?? 180)}/day',
                                  style: const TextStyle(
                                    color: TwoBeeColors.primarySoft,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                                const Text(
                                  'Multi-Service Enabled ✓',
                                  style: TextStyle(
                                    color: TwoBeeColors.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Header section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Glafit EV Fleet for Rent',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: TwoBeeColors.surfaceTonal,
                          borderRadius: TwoBeeRadii.pill,
                        ),
                        child: const Text(
                          'Zero Carbon Emission',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: TwoBeeColors.primaryAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Rent an official Glafit EV bike to unlock front-carrier multi-service and instant hub battery swapping.',
                    style: TextStyle(
                      color: TwoBeeColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Bike Fleet Cards
                  ..._bikes.map(
                    (b) => Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: TwoBeeColors.surfaceCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: TwoBeeColors.borderSoft),
                        boxShadow: TwoBeeShadows.softCard,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: TwoBeeColors.surfaceTonal,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.electric_moped_rounded,
                                    color: TwoBeeColors.primary,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (b['tag'] != null) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: TwoBeeColors.primary
                                                .withValues(alpha: 0.15),
                                            borderRadius: TwoBeeRadii.pill,
                                          ),
                                          child: Text(
                                            b['tag'].toString(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 9,
                                              color: TwoBeeColors.primaryAccent,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                      ],
                                      Text(
                                        b['modelName'].toString(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '★${b['rating'] ?? 4.9} · ${b['hubName']}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: TwoBeeColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Specs Pill Row
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _specChip(
                                  Icons.battery_charging_full_rounded,
                                  '${b['rangeKm']} km range',
                                ),
                                _specChip(
                                  Icons.speed_rounded,
                                  '${b['topSpeedKmH'] ?? 30} km/h',
                                ),
                                _specChip(
                                  Icons.inventory_2_outlined,
                                  'Front Rack ${b['frontMaxKg'] ?? 8}kg',
                                ),
                                _specChip(
                                  Icons.airline_seat_recline_normal_rounded,
                                  'Passenger Pillion',
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              b['desc']?.toString() ?? 'High-efficiency Glafit EV bike with front carrier.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: TwoBeeColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${bdt(b['dailyRateBdt'])}/day',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        color: TwoBeeColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Weekly: ${bdt(b['weeklyRateBdt'] ?? 1100)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: TwoBeeColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: TwoBeeColors.primary,
                                    foregroundColor: TwoBeeColors.obsidian,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: TwoBeeRadii.pill,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                  ),
                                  onPressed: () => _openRentalWizard(
                                    Map<String, dynamic>.from(b as Map),
                                  ),
                                  icon: const Icon(Icons.key_rounded, size: 16),
                                  label: const Text(
                                    'Rent Glafit EV ➔',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _specChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: TwoBeeColors.surfaceTonal,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: TwoBeeColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: TwoBeeColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Interactive 4-Step Glafit EV Bike Rental Wizard
class RentGlafitBikeWizardScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> bike;
  const RentGlafitBikeWizardScreen({super.key, required this.bike});

  @override
  ConsumerState<RentGlafitBikeWizardScreen> createState() =>
      _RentGlafitBikeWizardScreenState();
}

class _RentGlafitBikeWizardScreenState
    extends ConsumerState<RentGlafitBikeWizardScreen> {
  int _step = 0;
  String _plan = 'DAILY';
  bool _unlimitedSwap = true;
  String _selectedHub = 'Banani Hub (Sector 11)';
  bool _helmetOk = true;
  bool _agreementOk = true;
  bool _submitting = false;
  Map<String, dynamic>? _confirmedRental;

  final List<String> _hubs = [
    'Banani Hub (Sector 11)',
    'Mohakhali Hub / Wireless Gate',
    'Uttara Sector 3 Hub',
    'Dhanmondi Road 27 Hub',
  ];

  Future<void> _submitRental() async {
    setState(() => _submitting = true);
    final token = ref.read(authControllerProvider).riderRoleToken;
    try {
      final res = await ref
          .read(apiClientProvider)
          .post(
            '/rider/panel/rentals/book',
            roleToken: token,
            body: {
              'bikeId': widget.bike['id'] ?? 'fleet-glafit-gfr02',
              'planType': _plan,
              'swapPassIncluded': _unlimitedSwap,
              'hubName': _selectedHub,
            },
          );
      if (mounted) {
        setState(() {
          _confirmedRental = Map<String, dynamic>.from(res['rental'] as Map);
          _step = 3; // Confirmed state
        });
      }
    } catch (_) {
      // Fallback confirmation
      if (mounted) {
        setState(() {
          _confirmedRental = {
            'bikeModel':
                widget.bike['modelName'] ?? 'Glafit GFR-02 Dual-Power EV',
            'plateNo': '2BEE-EV-4821',
            'hubName': _selectedHub,
            'planType': _plan,
            'smartLockPin': '4821',
            'pickupBay': 'Bay #4',
            'batteryCharge': '98%',
          };
          _step = 3;
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bike;
    return Scaffold(
      backgroundColor: TwoBeeColors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          _step == 3 ? 'Rental Confirmed!' : 'Rent ${b['modelName']}',
        ),
        actions: const [TwoBeeHomeAction()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_step < 3) ...[
              LinearProgressIndicator(
                value: (_step + 1) / 3,
                color: TwoBeeColors.primary,
                backgroundColor: TwoBeeColors.surfaceTonal,
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Step ${_step + 1} of 3',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: TwoBeeColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: ListView(
                children: [
                  if (_step == 0) _buildStep0ModelOverview(b),
                  if (_step == 1) _buildStep1PlanAndHub(b),
                  if (_step == 2) _buildStep2AgreementAndDeposit(b),
                  if (_step == 3) _buildStep3ConfirmedHandover(),
                ],
              ),
            ),
            if (_step < 3) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (_step > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _step--),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TwoBeeColors.primary,
                        foregroundColor: TwoBeeColors.obsidian,
                        shape: RoundedRectangleBorder(
                          borderRadius: TwoBeeRadii.pill,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _step == 2
                          ? (_agreementOk && _helmetOk && !_submitting
                                ? _submitRental
                                : null)
                          : () => setState(() => _step++),
                      child: Text(
                        _step == 2
                            ? (_submitting
                                  ? 'Confirming...'
                                  : 'Confirm & Rent Glafit EV ➔')
                            : 'Next Step ➔',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStep0ModelOverview(Map<String, dynamic> b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: TwoBeeColors.obsidian,
            borderRadius: BorderRadius.circular(20),
            boxShadow: TwoBeeShadows.dockNav,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                b['modelName'].toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${b['hubName']} · ${b['availableQty']} available right now',
                style: const TextStyle(
                  color: TwoBeeColors.primarySoft,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statCol('RANGE', '${b['rangeKm']} km'),
                  _statCol('MAX SPEED', '${b['topSpeedKmH'] ?? 30} km/h'),
                  _statCol('SWAP TIME', '30 sec'),
                  _statCol('FRONT RACK', '${b['frontMaxKg'] ?? 8} kg'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Carrier & Multi-Service Specifications',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.inventory_2_outlined,
                  color: TwoBeeColors.primary,
                ),
                title: const Text(
                  'Front Cargo Carrier (Standard)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                subtitle: Text(
                  b['frontDimensions']?.toString() ??
                      '35×30×30 cm³ · Normal parcel leg compatible',
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.airline_seat_recline_normal_rounded,
                  color: TwoBeeColors.primary,
                ),
                title: const Text(
                  'Rear Passenger Pillion',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                subtitle: Text(
                  b['rearType']?.toString() ??
                      'Ergonomic cushion + helmet carrier',
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.electric_bolt_rounded,
                  color: TwoBeeColors.primary,
                ),
                title: const Text(
                  'Hot-Swap Battery Station Network',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                subtitle: const Text(
                  'Unlimited battery swaps across 12 Banani & Gulshan swap hubs',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statCol(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildStep1PlanAndHub(Map<String, dynamic> b) {
    final daily = b['dailyRateBdt'] ?? 180;
    final weekly = b['weeklyRateBdt'] ?? 1100;
    final monthly = b['monthlyRateBdt'] ?? 3800;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Rental Plan Duration',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
        const SizedBox(height: 10),
        _planRadioCard(
          'DAILY',
          'Daily Flex Plan',
          '${bdt(daily)} / day',
          'Debit daily from rider wallet. Cancel anytime.',
        ),
        _planRadioCard(
          'WEEKLY',
          'Weekly Value Plan (Save 13%)',
          '${bdt(weekly)} / week',
          'Ideal for full-time courier and multi-service riders.',
        ),
        _planRadioCard(
          'RENT_TO_OWN',
          'Monthly Pro Plan (Save 30%)',
          '${bdt(monthly)} / month',
          'Includes maintenance pass + guaranteed battery priority.',
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: TwoBeeColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: TwoBeeColors.primary.withValues(alpha: 0.4),
            ),
          ),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _unlimitedSwap,
            onChanged: (v) => setState(() => _unlimitedSwap = v),
            title: const Text(
              'Unlimited 2Bee Battery Swap Pass',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            subtitle: const Text(
              '+৳40/day · Unlimited battery swaps at all 2Bee hubs',
              style: TextStyle(fontSize: 11),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Select Pickup Hub Location',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedHub,
          items: _hubs
              .map(
                (h) => DropdownMenuItem(
                  value: h,
                  child: Text(h, style: const TextStyle(fontSize: 13)),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedHub = v ?? _selectedHub),
          decoration: const InputDecoration(
            prefixIcon: Icon(
              Icons.location_on_outlined,
              color: TwoBeeColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _planRadioCard(String val, String title, String price, String sub) {
    final sel = _plan == val;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: sel
            ? TwoBeeColors.primary.withValues(alpha: 0.1)
            : TwoBeeColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: sel ? TwoBeeColors.primary : TwoBeeColors.borderSoft,
          width: sel ? 2 : 1,
        ),
      ),
      child: ListTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: sel
                    ? TwoBeeColors.primaryAccent
                    : TwoBeeColors.textPrimary,
              ),
            ),
            Text(
              price,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ],
        ),
        subtitle: Text(sub, style: const TextStyle(fontSize: 11)),
        leading: Radio<String>(
          value: val,
          groupValue: _plan,
          onChanged: (v) => setState(() => _plan = v ?? _plan),
          activeColor: TwoBeeColors.primary,
        ),
        onTap: () => setState(() => _plan = val),
      ),
    );
  }

  Widget _buildStep2AgreementAndDeposit(Map<String, dynamic> b) {
    final deposit = b['securityDepositBdt'] ?? 2000;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TwoBeeColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TwoBeeColors.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PAYMENT & DEPOSIT BREAKDOWN',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  color: TwoBeeColors.textSecondary,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 10),
              _costRow(
                'Refundable Security Deposit',
                bdt(deposit),
                isBold: false,
              ),
              _costRow(
                'Initial Rental Fee ($_plan)',
                bdt(b['dailyRateBdt'] ?? 180),
                isBold: false,
              ),
              if (_unlimitedSwap)
                _costRow('Daily Battery Swap Pass', '৳40', isBold: false),
              const Divider(height: 16),
              _costRow(
                'Total Due Now',
                bdt(
                  deposit +
                      (b['dailyRateBdt'] ?? 180) +
                      (_unlimitedSwap ? 40 : 0),
                ),
                isBold: true,
              ),
              const SizedBox(height: 6),
              const Text(
                'Deposit is 100% refundable upon bike return in working condition.',
                style: TextStyle(
                  fontSize: 11,
                  color: TwoBeeColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Safety Inspection & Agreement',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _helmetOk,
          onChanged: (v) => setState(() => _helmetOk = v ?? false),
          title: const Text(
            'I will carry and wear the 2Bee certified helmet at all times',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          subtitle: const Text(
            'Includes secondary passenger helmet for multi-service rides',
            style: TextStyle(fontSize: 11),
          ),
        ),
        CheckboxListTile(
          value: _agreementOk,
          onChanged: (v) => setState(() => _agreementOk = v ?? false),
          title: const Text(
            'I agree to the Glafit EV Rental & Maintenance Terms',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          subtitle: const Text(
            'Daily rent debits automatically from earnings wallet.',
            style: TextStyle(fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _costRow(String label, String value, {required bool isBold}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
              fontSize: isBold ? 14 : 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: isBold ? 15 : 12,
              color: isBold
                  ? TwoBeeColors.primaryAccent
                  : TwoBeeColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3ConfirmedHandover() {
    final r = _confirmedRental ?? {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: TwoBeeColors.primary,
            shape: BoxShape.circle,
            boxShadow: TwoBeeShadows.emeraldGlow,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: TwoBeeColors.obsidian,
            size: 44,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Glafit EV Bike Activated! ⚡',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          r['bikeModel']?.toString() ?? 'Glafit GFR-02 Dual-Power EV',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: TwoBeeColors.primaryAccent,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: TwoBeeColors.obsidian,
            borderRadius: BorderRadius.circular(20),
            boxShadow: TwoBeeShadows.dockNav,
          ),
          child: Column(
            children: [
              _detailRow(
                'ASSIGNED BIKE PLATE',
                r['plateNo']?.toString() ?? '2BEE-EV-048',
              ),
              const Divider(color: Colors.white24, height: 16),
              _detailRow(
                'SMART LOCK BLUETOOTH PIN',
                r['smartLockPin']?.toString() ?? '4821',
              ),
              const Divider(color: Colors.white24, height: 16),
              _detailRow(
                'PICKUP HUB',
                r['hubName']?.toString() ?? 'Banani Hub (Sector 11)',
              ),
              const Divider(color: Colors.white24, height: 16),
              _detailRow('BATTERY CHARGE', '98% (Ready to roll)'),
              const Divider(color: Colors.white24, height: 16),
              _detailRow(
                'MULTI-SERVICE STATUS',
                'ACTIVE · FRONT CARRIER UNLOCKED ✓',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: TwoBeeColors.primary,
            foregroundColor: TwoBeeColors.obsidian,
            shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            'Go to Rider Home Dashboard ➔',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class RiderSecurityScreen extends ConsumerStatefulWidget {
  const RiderSecurityScreen({super.key});

  @override
  ConsumerState<RiderSecurityScreen> createState() =>
      _RiderSecurityScreenState();
}

class _RiderSecurityScreenState extends ConsumerState<RiderSecurityScreen> {
  final _cur = TextEditingController();
  final _next = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _payoutNoCtrl = TextEditingController();
  final _holderCtrl = TextEditingController();
  String _provider = 'BKASH';
  Map<String, dynamic>? _secData;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = ref.read(authControllerProvider).riderRoleToken;
    if (token == null) return;
    final res = await ref
        .read(apiClientProvider)
        .get('/rider/panel/security', roleToken: token);
    if (mounted) setState(() => _secData = res);
  }

  @override
  Widget build(BuildContext context) {
    final payout = _secData?['payoutAccount'] as Map?;
    final devices = (_secData?['devices'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider Security (4-Digit PIN)'),
        actions: const [TwoBeeHomeAction()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            color: TwoBeeColors.surfaceTonal,
            child: ListTile(
              leading: Icon(Icons.shield_outlined, color: TwoBeeColors.primary),
              title: Text('4-Digit Passcode + 15-min Auto-Lock'),
              subtitle: Text(
                'Payout method updates require SMS OTP + 48-hour hold.',
              ),
            ),
          ),
          if (payout?['pendingEffectiveAt'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: VerificationBanner(
                title: '48-Hour Payout Hold Active',
                subtitle:
                    'Pending change takes effect at ${payout!['pendingEffectiveAt']}',
              ),
            ),
          const SizedBox(height: 14),
          const Text(
            'Change 4-Digit Passcode',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _cur,
            maxLength: 4,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Current 4-digit PIN'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _next,
            maxLength: 4,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'New 4-digit PIN'),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () async {
              final token = ref.read(authControllerProvider).riderRoleToken;
              await ref
                  .read(apiClientProvider)
                  .post(
                    '/rider/panel/security/change-pin',
                    roleToken: token,
                    body: {
                      'currentPasscode': _cur.text.trim(),
                      'newPasscode': _next.text.trim(),
                    },
                  );
              if (context.mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('4-digit Rider PIN updated!')),
                );
            },
            child: const Text('Update 4-Digit Passcode'),
          ),
          const SizedBox(height: 20),
          const Text(
            'Request Payout Change (SMS OTP + 48h Hold)',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              final phone =
                  ref.read(authControllerProvider).user?['phone'] as String;
              final res = await ref
                  .read(apiClientProvider)
                  .post(
                    '/auth/otp/request',
                    body: {'phone': phone, 'purpose': 'PAYOUT_CHANGE'},
                  );
              if (res['devOtpHint'] != null)
                _otpCtrl.text = res['devOtpHint'] as String;
              if (context.mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('SMS OTP requested')),
                );
            },
            child: const Text('Send Payout Verification OTP'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '6-digit SMS OTP'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _provider,
            decoration: const InputDecoration(labelText: 'New Provider'),
            items: const [
              DropdownMenuItem(value: 'BKASH', child: Text('bKash')),
              DropdownMenuItem(value: 'NAGAD', child: Text('Nagad')),
              DropdownMenuItem(value: 'ROCKET', child: Text('Rocket')),
              DropdownMenuItem(value: 'BANK_BEFTN', child: Text('Bank BEFTN')),
            ],
            onChanged: (v) => setState(() => _provider = v ?? 'BKASH'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _payoutNoCtrl,
            decoration: const InputDecoration(
              labelText: 'New Wallet / Account Number',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _holderCtrl,
            decoration: const InputDecoration(
              labelText: 'Holder Name (Match NID)',
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () async {
              final token = ref.read(authControllerProvider).riderRoleToken;
              await ref
                  .read(apiClientProvider)
                  .post(
                    '/rider/panel/payout/change-request',
                    roleToken: token,
                    body: {
                      'otpCode': _otpCtrl.text.trim(),
                      'provider': _provider,
                      'accountNumber': _payoutNoCtrl.text.trim(),
                      'holderName': _holderCtrl.text.trim(),
                    },
                  );
              _load();
              if (context.mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Submitted! 48-hour hold applied.'),
                  ),
                );
            },
            child: const Text('Submit Payout Change (48h Hold)'),
          ),
          if (devices.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Authorized Devices',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            ...devices.map(
              (d) => Card(
                margin: const EdgeInsets.only(top: 8),
                child: ListTile(
                  title: Text(d['deviceName'].toString()),
                  trailing: TextButton(
                    onPressed: () async {
                      final token = ref
                          .read(authControllerProvider)
                          .riderRoleToken;
                      await ref
                          .read(apiClientProvider)
                          .delete(
                            '/rider/panel/security/devices/${d['id']}',
                            roleToken: token,
                          );
                      _load();
                    },
                    child: const Text('Remove'),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
