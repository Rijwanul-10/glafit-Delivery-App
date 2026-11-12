import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/twobee_theme.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/common_widgets.dart';
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
                const Icon(Icons.lock_clock_rounded, size: 52, color: TwoBeeColors.primary),
                const SizedBox(height: 12),
                const Text('Rider Session Locked', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Auto-locked for your safety (15-min inactivity limit).'),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: () => context.go('/rider/passcode'), child: const Text('Unlock with 4-Digit PIN')),
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
        await ref.read(apiClientProvider).post('/common/demo/auto-verify-rider');
        await ref.read(authControllerProvider.notifier).refreshRoles();
        if (mounted) setState(() => _justAutoApproved = true);
        await _load();
      } catch (_) {}
    });
  }

  Future<void> _load() async {
    final token = ref.read(authControllerProvider).riderRoleToken;
    if (token == null) return;
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/rider/panel/home', roleToken: token);
      setState(() => _home = res);
      _scheduleAutoVerifyIfPending(res);
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
                const Text('Start Your Shift', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const Text('Configure active services before going online', style: TextStyle(color: TwoBeeColors.textSecondary, fontSize: 12)),
                CheckboxListTile(value: p, onChanged: (v) => setM(() => p = v ?? true), title: const Text('Parcel (Avg ৳140/trip)')),
                CheckboxListTile(value: r, onChanged: (v) => setM(() => r = v ?? true), title: const Text('Ride (Avg ৳85/trip)')),
                CheckboxListTile(value: f, onChanged: (v) => setM(() => f = v ?? true), title: const Text('Food (Avg ৳85/trip)')),
                const ListTile(
                  leading: Icon(Icons.lock_outline, color: TwoBeeColors.textSecondary),
                  title: Text('CNG / Car', style: TextStyle(color: TwoBeeColors.textSecondary)),
                  subtitle: Text('Not available for bike account'),
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
      await ref.read(apiClientProvider).post('/rider/panel/online', roleToken: token, body: {
        'isOnline': true,
        'lat': 23.7937,
        'lng': 90.4066,
        'services': {'parcel': p, 'ride': r, 'food': f},
      });
      final riderId = _home?['rider']?['id'] as String?;
      if (riderId != null) {
        ref.read(socketServiceProvider).streamRiderLocation(riderId: riderId, lat: 23.7937, lng: 90.4066);
      }
      _load();
      if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const LookingForRequestsScreen()));
      return;
    }

    final token = ref.read(authControllerProvider).riderRoleToken;
    try {
      await ref.read(apiClientProvider).post('/rider/panel/online', roleToken: token, body: {
        'isOnline': false,
        'lat': 23.7937,
        'lng': 90.4066,
      });
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _home == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final r = _home!['rider'] as Map;
    final approved = r['kycStatus'] == 'APPROVED';
    final isOnline = r['isOnline'] == true;
    final activeBatch = _home!['activeBatch'] as Map?;
    final recent = (_home!['recentCompletedTrips'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('2Bee Rider'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen(roleFilter: 'RIDER'))),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const TwoBeeHomeAction(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!approved) ...[
              const VerificationBanner(
                title: 'Verification in progress · Auto-verifying in 3s...',
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${r['fullName']} · ★${r['rating']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          Text('${r['vehicleBrandModel']} · ${r['plateNo']}', style: const TextStyle(fontSize: 12, color: TwoBeeColors.textSecondary)),
                          const SizedBox(height: 6),
                          Text(
                            isOnline ? 'You are Online (${_home!['geoEngine']})' : (approved ? 'You are Offline' : 'Account pending review'),
                            style: TextStyle(fontWeight: FontWeight.w700, color: isOnline ? TwoBeeColors.primary : TwoBeeColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(110, 44),
                        backgroundColor: !approved ? TwoBeeColors.borderSoft : (isOnline ? TwoBeeColors.errorText : TwoBeeColors.obsidian),
                      ),
                      onPressed: approved ? () => _toggleOnline(!isOnline) : null,
                      child: Text(isOnline ? 'Go Offline' : 'Go Online'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: TwoBeeColors.obsidian, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Today's Earnings", style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text(bdt(_home!['todayEarningsBdt'] as num), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            if (activeBatch != null) ...[
              const SizedBox(height: 12),
              Card(
                color: TwoBeeColors.surfaceTonal,
                child: ListTile(
                  leading: const Icon(Icons.alt_route_rounded, color: TwoBeeColors.primary),
                  title: Text('LIVE MULTI-SERVICE · ${activeBatch['batchCode']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('Stop 1: Drop Passenger -> Stop 2: Deliver Parcel · Status: ${activeBatch['status']}'),
                  trailing: const Icon(Icons.arrow_forward_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MultiServiceBatchScreen(batchId: activeBatch['id'] as String)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (approved)
              Card(
                color: TwoBeeColors.surfaceTonal,
                child: ListTile(
                  leading: const Icon(Icons.radar_rounded, color: TwoBeeColors.primary),
                  title: const Text('Open Live Dispatch Radar & Zone A→B Jobs', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('Multi-Service: ${r['multiServiceEnabled'] == true ? "READY (Front 8kg + Helmet)" : "Single-Service"}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LookingForRequestsScreen())),
                ),
              ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.electric_moped_rounded, color: TwoBeeColors.primary),
                title: const Text('Rent EV Bike · from ৳250/day'),
                trailing: const Text('Browse >', style: TextStyle(fontWeight: FontWeight.w700, color: TwoBeeColors.primary)),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BikeRentalHomeScreen())),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Recent Completed Trips', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 8),
            if (recent.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(approved ? 'No recent completed trips today.' : 'Trips will appear here once approved and active.'),
                ),
              )
            else
              ...recent.map((t) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text('${t['type']} · ${t['code']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(t['label'].toString()),
                      trailing: Text('+${bdt(t['payoutBdt'] as num)}', style: const TextStyle(fontWeight: FontWeight.w800, color: TwoBeeColors.primary)),
                    ),
                  )),
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
  ConsumerState<LookingForRequestsScreen> createState() => _LookingForRequestsScreenState();
}

class _LookingForRequestsScreenState extends ConsumerState<LookingForRequestsScreen> {
  Map<String, dynamic>? _open;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    ref.read(socketServiceProvider).socket?.on('rider:incoming_offer', (_) => _load());
    ref.read(socketServiceProvider).socket?.on('rider:ride_addon_offer', (_) => _load());
  }

  Future<void> _load() async {
    final token = ref.read(authControllerProvider).riderRoleToken;
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/rider/panel/dispatch/open', roleToken: token);
      setState(() => _open = res);
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
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Chip(
                      label: Text(badge, style: const TextStyle(fontWeight: FontWeight.w800, color: TwoBeeColors.primary)),
                      backgroundColor: TwoBeeColors.surfaceTonal,
                    ),
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: TwoBeeColors.obsidian,
                      child: Text('${secs}s', style: const TextStyle(color: TwoBeeColors.primarySoft, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: TwoBeeColors.textSecondary)),
                const SizedBox(height: 12),
                Card(
                  color: TwoBeeColors.obsidian,
                  child: ListTile(
                    title: const Text('ESTIMATED RIDER PAYOUT', style: TextStyle(color: TwoBeeColors.primarySoft, fontSize: 11, fontWeight: FontWeight.w700)),
                    subtitle: Text(paymentLabel, style: const TextStyle(color: Colors.white70)),
                    trailing: Text(bdt(payoutBdt), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                  ),
                ),
                if (isMultiService)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '✓ Fits Front Carrier (<=8kg) · Zone A → Zone B Ride Add-On Eligible',
                      style: TextStyle(fontWeight: FontWeight.w700, color: TwoBeeColors.primary, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          timer?.cancel();
                          Navigator.pop(ctx, false);
                        },
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          timer?.cancel();
                          Navigator.pop(ctx, true);
                        },
                        child: Text('Accept (${secs}s)'),
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
    final addons = (_open?['multiServiceRideAddons'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Looking for Requests'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh)), const TwoBeeHomeAction()]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const TwoBeeMapPreview(height: 170),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: TwoBeeColors.obsidian),
                  onPressed: _seedSampleDispatch,
                  icon: const Icon(Icons.bolt_rounded),
                  label: const Text('Preview: Seed Banani → Uttara Parcel & Ride Ping'),
                ),
                const SizedBox(height: 14),
                if (addons.isNotEmpty) ...[
                  const Text('ZONE A → B MATCHING RIDE ADD-ONS (12s)', style: TextStyle(fontWeight: FontWeight.w800, color: TwoBeeColors.primary)),
                  const SizedBox(height: 8),
                  ...addons.map((r) => Card(
                        color: TwoBeeColors.surfaceTonal,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text('Ride Add-On ${r['tripCode']} · ${bdt(r['riderPayoutBdt'] as num)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text('${r['pickupZoneId']} → ${r['dropoffZoneId']} · Passenger dropped 1st!'),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(minimumSize: const Size(90, 38)),
                            onPressed: () async {
                              final ok = await _showIncomingOfferModal(
                                badge: 'ZONE A → B RIDE ADD-ON',
                                title: 'Co-Ride ${r['tripCode']} · 3-Stop Sequence',
                                subtitle: '1. Pickup Passenger (${r['pickupAddress']})\n2. Drop Passenger FIRST (${r['dropoffAddress']})\n3. Deliver Front-Rack Parcel SECOND',
                                payoutBdt: r['riderPayoutBdt'] as num,
                                paymentLabel: 'Payment: ${r['paymentMethod']} · Zone A → B Verified',
                                isMultiService: true,
                                countdownSecs: 12,
                              );
                              if (!ok) return;
                              final token = ref.read(authControllerProvider).riderRoleToken;
                              final jobs = await ref.read(apiClientProvider).get('/rider/panel/jobs', roleToken: token);
                              final liveParcels = (jobs['live']?['parcels'] as List?) ?? [];
                              if (liveParcels.isEmpty) return;
                              final parcelId = liveParcels.first['id'] as String;
                              final batchRes = await ref.read(apiClientProvider).post('/rider/panel/multi-service/accept-ride-addon',
                                  roleToken: token, body: {'rideTripId': r['id'], 'parcelId': parcelId});
                              if (context.mounted) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (_) => MultiServiceBatchScreen(batchId: batchRes['batch']['id'] as String)),
                                );
                              }
                            },
                            child: const Text('Review 12s'),
                          ),
                        ),
                      )),
                ],
                const Text('Parcel Requests', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 8),
                if (parcels.isEmpty)
                  const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('No waiting parcels right now. Tap Preview above to generate one!')))
                else
                  ...parcels.map((p) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text('${p['tier']} · ${p['trackingCode']} (${p['weightKg']} kg)', style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${p['pickupAddress']} → ${p['dropoffAddress']}\nFits front carrier: ${p['fitsFrontCarrier']}'),
                          isThreeLine: true,
                          trailing: FilledButton(
                            onPressed: () async {
                              final ok = await _showIncomingOfferModal(
                                badge: p['fitsFrontCarrier'] == true ? 'NORMAL PARCEL · MULTI-SERVICE' : 'PARCEL DISPATCH',
                                title: '${p['trackingCode']} (${p['weightKg']} kg)',
                                subtitle: '${p['pickupAddress']} → ${p['dropoffAddress']}',
                                payoutBdt: p['riderPayoutBdt'] as num,
                                paymentLabel: 'COD Collect: ${bdt(p['codCollectBdt'] ?? 0)} · ${p['paymentMethod']}',
                                isMultiService: p['fitsFrontCarrier'] == true,
                              );
                              if (!ok) return;
                              final token = ref.read(authControllerProvider).riderRoleToken;
                              try {
                                await ref.read(apiClientProvider).post('/rider/panel/parcel/${p['id']}/accept', roleToken: token);
                                if (context.mounted) {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => ParcelPickupScreen(parcelId: p['id'] as String)));
                                }
                              } catch (e) {
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                              }
                            },
                            child: Text(bdt(p['riderPayoutBdt'] as num)),
                          ),
                        ),
                      )),
                const SizedBox(height: 12),
                const Text('Food & Solo Ride Requests', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 8),
                ...food.map((f) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text('Food ${f['orderCode']} · ${f['merchant']?['businessName'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('Dropoff: ${f['deliveryAddress']}'),
                        trailing: FilledButton(
                          onPressed: () async {
                            final ok = await _showIncomingOfferModal(
                              badge: 'FOOD DELIVERY',
                              title: 'Order ${f['orderCode']} · ${f['merchant']?['businessName'] ?? ''}',
                              subtitle: 'Dropoff: ${f['deliveryAddress']} (Single-service Food)',
                              payoutBdt: f['riderPayoutBdt'] as num,
                              paymentLabel: 'Payment: ${f['paymentMethod']}',
                            );
                            if (!ok) return;
                            final token = ref.read(authControllerProvider).riderRoleToken;
                            await ref.read(apiClientProvider).post('/rider/panel/food/${f['id']}/accept', roleToken: token);
                            if (context.mounted) {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => RiderFoodExecutionScreen(orderId: f['id'] as String)));
                              _load();
                            }
                          },
                          child: Text('Accept ${bdt(f['riderPayoutBdt'] as num)}'),
                        ),
                      ),
                    )),
                ...rides.map((r) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text('Solo Ride ${r['tripCode']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${r['pickupAddress']} → ${r['dropoffAddress']} (Locks Multi-Service)'),
                        trailing: FilledButton(
                          onPressed: () async {
                            final ok = await _showIncomingOfferModal(
                              badge: 'SOLO RIDE REQUEST',
                              title: 'Ride ${r['tripCode']}',
                              subtitle: '${r['pickupAddress']} → ${r['dropoffAddress']}\nNote: Ride-first trips lock out Multi-Service.',
                              payoutBdt: r['riderPayoutBdt'] as num,
                              paymentLabel: 'Payment: ${r['paymentMethod']}',
                            );
                            if (!ok) return;
                            final token = ref.read(authControllerProvider).riderRoleToken;
                            await ref.read(apiClientProvider).post('/rider/panel/ride/${r['id']}/accept', roleToken: token);
                            if (context.mounted) {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => RiderRideExecutionScreen(tripId: r['id'] as String)));
                              _load();
                            }
                          },
                          child: Text('Accept ${bdt(r['riderPayoutBdt'] as num)}'),
                        ),
                      ),
                    )),
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
  final _weightCtrl = TextEditingController(text: '2.0');
  bool _frontRackLoaded = true;
  bool _proofPhoto = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parcel Pickup (Multi-Service)'), actions: const [TwoBeeHomeAction()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: TwoBeeColors.surfaceTonal,
            child: ListTile(
              leading: const Icon(Icons.inventory_2_outlined, color: TwoBeeColors.primary),
              title: const Text('Step 1/2 · Weigh & Measure Front Rack', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Normal parcel <= 8.0 kg & <= 31,500 cm3 leaves rear pillion seat free for Zone A -> B Ride Add-On.'),
              trailing: IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CarryingSetupScreen())),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _weightCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Actual Verified Weight (kg, Max 8.0 front)'),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _frontRackLoaded,
            onChanged: (v) => setState(() => _frontRackLoaded = v ?? true),
            title: const Text('Step 2/2 · Placed Safely in Front Cargo Rack'),
            subtitle: const Text('Rear Passenger Pillion Seat Reserved & Clear'),
          ),
          CheckboxListTile(
            value: _proofPhoto,
            onChanged: (v) => setState(() => _proofPhoto = v ?? true),
            title: const Text('Camera Proof of Loading Photo Captured'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final token = ref.read(authControllerProvider).riderRoleToken;
              final res = await ref.read(apiClientProvider).post(
                '/rider/panel/parcel/${widget.parcelId}/pickup',
                roleToken: token,
                body: {
                  'actualWeightKg': double.tryParse(_weightCtrl.text) ?? 2.0,
                  'pickupPhotoUrl': '/uploads/front-rack-proof.jpg',
                },
              );
              final eligible = res['multiServiceEligible'] == true;
              final reason = res['ineligibleReason'] as String?;
              if (!context.mounted) return;
              if (eligible) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ParcelDeliverScreen(parcelId: widget.parcelId, multiServiceEligible: true),
                  ),
                );
              } else {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MultiServiceUnavailableScreen(reason: reason ?? 'Exceeds front-carrier limit or not a Normal parcel-first leg.'),
                  ),
                );
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ParcelDeliverScreen(parcelId: widget.parcelId, multiServiceEligible: false, reason: reason),
                    ),
                  );
                }
              }
            },
            child: const Text('Slide / Confirm Picked Up ->'),
          ),
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
      appBar: AppBar(title: const Text('Multi-Service Status'), actions: const [TwoBeeHomeAction()]),
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
                    Text('Why Co-Rides Are Locked on This Task:', style: TextStyle(fontWeight: FontWeight.w800)),
                    SizedBox(height: 8),
                    Text('• Multi-service ONLY pairs NORMAL Front-Carrier parcels (<= 8.0 kg & <= 31,500 cm3).'),
                    SizedBox(height: 4),
                    Text('• Express/Urgent parcels, Food orders, or Ride-first trips never combine with another service.'),
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
  ConsumerState<ParcelDeliverScreen> createState() => _ParcelDeliverScreenState();
}

class _ParcelDeliverScreenState extends ConsumerState<ParcelDeliverScreen> {
  final _pinCtrl = TextEditingController();
  List<dynamic> _addons = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.multiServiceEligible) _checkRadar();
  }

  Future<void> _checkRadar() async {
    final token = ref.read(authControllerProvider).riderRoleToken;
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/rider/panel/dispatch/open', roleToken: token);
      if (mounted) setState(() => _addons = (res['multiServiceRideAddons'] as List?) ?? []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parcel Deliver (Multi-Service)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.emergency_rounded, color: TwoBeeColors.errorText),
            onPressed: () => showSosSafetySheet(context, ref, role: 'RIDER', orderId: widget.parcelId),
          ),
          const TwoBeeHomeAction(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const TwoBeeMapPreview(height: 180),
          const SizedBox(height: 12),
          VerificationBanner(
            title: widget.multiServiceEligible ? 'RIDE RADAR ACTIVE · Zone A → Zone B Corridor' : 'Single-Service Delivery',
            subtitle: widget.multiServiceEligible
                ? 'Front rack holding normal parcel; scanning Zone A → Zone B passenger ride add-ons.'
                : (widget.reason ?? 'Single-service lock active'),
            isErrorStyle: !widget.multiServiceEligible,
          ),
          const SizedBox(height: 12),
          if (widget.multiServiceEligible) ...[
            if (_loading) const LinearProgressIndicator(),
            if (_addons.isNotEmpty)
              ..._addons.map((r) => Card(
                    color: TwoBeeColors.surfaceTonal,
                    child: ListTile(
                      title: Text('12s Ride Add-On: ${r['tripCode']} (+${bdt(r['riderPayoutBdt'] as num)})',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('Stop 1 Drop Pax (${r['dropoffAddress']}) -> Stop 2 Parcel'),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(minimumSize: const Size(86, 38)),
                        onPressed: () async {
                          final token = ref.read(authControllerProvider).riderRoleToken;
                          final batchRes = await ref.read(apiClientProvider).post(
                            '/rider/panel/multi-service/accept-ride-addon',
                            roleToken: token,
                            body: {'rideTripId': r['id'], 'parcelId': widget.parcelId},
                          );
                          if (context.mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PassengerPickupScreen(batch: Map<String, dynamic>.from(batchRes['batch'] as Map)),
                              ),
                            );
                          }
                        },
                        child: const Text('Accept'),
                      ),
                    ),
                  ))
            else
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(apiClientProvider).post('/common/demo/seed-dispatch');
                  await _checkRadar();
                },
                icon: const Icon(Icons.radar_rounded),
                label: const Text('Scan / Seed Matching Zone A → B Ride Add-On'),
              ),
            const SizedBox(height: 12),
          ],
          TextField(controller: _pinCtrl, maxLength: 4, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Customer 4-Digit Delivery PIN')),
          ElevatedButton(
            onPressed: () async {
              final token = ref.read(authControllerProvider).riderRoleToken;
              await ref.read(apiClientProvider).post('/rider/panel/parcel/${widget.parcelId}/deliver', roleToken: token, body: {
                'deliveryPin': _pinCtrl.text.trim(),
              });
              if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst);
            },
            child: const Text('Slide when Arrived · Complete Solo Parcel Delivery ->'),
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
  ConsumerState<MultiServiceBatchScreen> createState() => _MultiServiceBatchScreenState();
}

class _MultiServiceBatchScreenState extends ConsumerState<MultiServiceBatchScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_route);
  }

  Future<void> _route() async {
    final token = ref.read(authControllerProvider).riderRoleToken;
    final res = await ref.read(apiClientProvider).get('/rider/panel/jobs/batch/${widget.batchId}', roleToken: token);
    final b = Map<String, dynamic>.from(res['batch'] as Map);
    final st = b['status'] as String;
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
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => target));
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

/// Dedicated Screen: Passenger Pickup (Multi-Service)
class PassengerPickupScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> batch;
  const PassengerPickupScreen({super.key, required this.batch});

  @override
  ConsumerState<PassengerPickupScreen> createState() => _PassengerPickupScreenState();
}

class _PassengerPickupScreenState extends ConsumerState<PassengerPickupScreen> {
  final _pinCtrl = TextEditingController();
  bool _paxHelmet = true;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.batch;
    final ride = b['rideTrip'] as Map;
    return Scaffold(
      appBar: AppBar(title: const Text('Passenger Pickup (Multi-Service)'), actions: const [TwoBeeHomeAction()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const VerificationBanner(
            title: 'Front Carrier Occupied · Rear Pillion Reserved',
            subtitle: 'Check Passenger 4-digit Start PIN and helmet before departing.',
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: TwoBeeColors.surfaceTonal, child: Icon(Icons.person_pin_circle, color: TwoBeeColors.primary)),
              title: Text('${ride['user']?['fullName'] ?? 'Passenger'} · Trip ${ride['tripCode']}', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('Pickup: ${ride['pickupAddress']}\nExpected Start PIN: ${ride['startPin']}'),
              isThreeLine: true,
              trailing: IconButton(
                icon: const Icon(Icons.chat_outlined, color: TwoBeeColors.primary),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InAppChatScreen(serviceType: 'RIDE', orderId: ride['id'] as String, peerTitle: 'Passenger'))),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(controller: _pinCtrl, maxLength: 4, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Enter Passenger 4-Digit Start PIN')),
          CheckboxListTile(value: _paxHelmet, onChanged: (v) => setState(() => _paxHelmet = v ?? false), title: const Text('Passenger wearing verified helmet')),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    try {
                      final token = ref.read(authControllerProvider).riderRoleToken;
                      await ref.read(apiClientProvider).post(
                        '/rider/panel/multi-service/${b['id']}/passenger-pickup',
                        roleToken: token,
                        body: {'startPin': _pinCtrl.text.trim(), 'passengerHasHelmet': _paxHelmet},
                      );
                      final refreshed = await ref.read(apiClientProvider).get('/rider/panel/jobs/batch/${b['id']}', roleToken: token);
                      if (context.mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => MultiServiceLiveScreen(batch: Map<String, dynamic>.from(refreshed['batch'] as Map))),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
            child: const Text('Start Trip · Stop 1 Passenger Leg ->'),
          ),
        ],
      ),
    );
  }
}

/// Dedicated Screen: Multi-Service Live (Stop 1 Passenger -> Stop 2 Parcel)
class MultiServiceLiveScreen extends StatelessWidget {
  final Map<String, dynamic> batch;
  const MultiServiceLiveScreen({super.key, required this.batch});

  @override
  Widget build(BuildContext context) {
    final ride = batch['rideTrip'] as Map;
    final parcel = batch['parcelShipment'] as Map;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Multi-Service'),
        actions: [
          IconButton(
            tooltip: 'Open in Maps',
            icon: const Icon(Icons.map_outlined),
            onPressed: () => launchUrl(
              Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${ride['dropoffLat'] ?? 23.8726},${ride['dropoffLng'] ?? 90.3983}'),
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
            decoration: BoxDecoration(color: TwoBeeColors.obsidian, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CORRIDOR ${batch['originZoneId']} → ${batch['destinationZoneId']}', style: const TextStyle(color: TwoBeeColors.primarySoft, fontSize: 12, fontWeight: FontWeight.w700)),
                Text('Combined Payout: ${bdt(batch['totalPayoutBdt'] as num)}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                const Text('Safety Rule: Passenger drops FIRST at Stop 1 before Stop 2 Parcel.', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const TwoBeeMapPreview(height: 170),
          const SizedBox(height: 12),
          Card(
            color: TwoBeeColors.surfaceTonal,
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: TwoBeeColors.primary, child: Text('1', style: TextStyle(color: Colors.white))),
              title: Text('STOP 1 · Drop Passenger First (${ride['dropoffAddress']})', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Active Passenger Leg'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Text('2')),
              title: Text('STOP 2 · Deliver Front-Rack Parcel (${parcel['dropoffAddress']})'),
              subtitle: const Text('Queued until Stop 1 Passenger dropoff completes'),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => PassengerDropoffScreen(batch: batch)),
            ),
            child: const Text('Arrived at Stop 1 (Drop Passenger) ->'),
          ),
        ],
      ),
    );
  }
}

/// Dedicated Screen: Passenger Dropoff & Fare Collection
class PassengerDropoffScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> batch;
  const PassengerDropoffScreen({super.key, required this.batch});

  @override
  ConsumerState<PassengerDropoffScreen> createState() => _PassengerDropoffScreenState();
}

class _PassengerDropoffScreenState extends ConsumerState<PassengerDropoffScreen> {
  bool _cashOk = true;
  bool _helmetRet = true;
  bool _curbOk = true;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.batch;
    final ride = b['rideTrip'] as Map;
    final parcel = b['parcelShipment'] as Map;
    return Scaffold(
      appBar: AppBar(title: const Text('Passenger Dropoff & Fare'), actions: const [TwoBeeHomeAction()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: TwoBeeColors.obsidian,
            child: ListTile(
              title: const Text('RIDE FARE TO COLLECT', style: TextStyle(color: TwoBeeColors.primarySoft, fontSize: 12, fontWeight: FontWeight.w700)),
              subtitle: Text('Payment Method: ${ride['paymentMethod']}', style: const TextStyle(color: Colors.white70)),
              trailing: Text(bdt(ride['totalFareBdt'] as num), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(value: _cashOk, onChanged: (v) => setState(() => _cashOk = v ?? false), title: const Text('Passenger Ride Fare Settled')),
          CheckboxListTile(value: _helmetRet, onChanged: (v) => setState(() => _helmetRet = v ?? false), title: const Text('Safety 1/2 · Helmet returned & sanitized')),
          CheckboxListTile(value: _curbOk, onChanged: (v) => setState(() => _curbOk = v ?? false), title: const Text('Safety 2/2 · Passenger dismounted safely on curb')),
          const SizedBox(height: 10),
          Card(
            color: TwoBeeColors.surfaceTonal,
            child: ListTile(
              title: Text('Next Leg · Parcel ${parcel['trackingCode']}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('Dropoff: ${parcel['dropoffAddress']} · Parcel Leg Payout ${bdt(parcel['riderPayoutBdt'] as num)}'),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    final token = ref.read(authControllerProvider).riderRoleToken;
                    await ref.read(apiClientProvider).post(
                      '/rider/panel/multi-service/${b['id']}/passenger-dropoff',
                      roleToken: token,
                      body: {'helmetReturnedOk': _helmetRet, 'curbDismountOk': _curbOk},
                    );
                    if (context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => FinalParcelDeliveryScreen(batch: b)),
                      );
                    }
                  },
            child: const Text('Complete Dropoff & Head to Parcel ->'),
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
  ConsumerState<FinalParcelDeliveryScreen> createState() => _FinalParcelDeliveryScreenState();
}

class _FinalParcelDeliveryScreenState extends ConsumerState<FinalParcelDeliveryScreen> {
  final _pinCtrl = TextEditingController();
  bool _codCollected = true;
  bool _podPhoto = true;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.batch;
    final parcel = b['parcelShipment'] as Map;
    return Scaffold(
      appBar: AppBar(title: const Text('Final Parcel Delivery (Stop 2)'), actions: const [TwoBeeHomeAction()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: TwoBeeColors.surfaceTonal,
            child: ListTile(
              title: Text('Recipient: ${parcel['recipientName']}', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${parcel['dropoffAddress']}\nCOD Collect: ${bdt(parcel['codCollectBdt'] ?? 0)} · PIN: ${parcel['deliveryPin']}'),
              isThreeLine: true,
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(value: _codCollected, onChanged: (v) => setState(() => _codCollected = v ?? false), title: Text('COD Cash (${bdt(parcel['codCollectBdt'] ?? 0)}) Collected')),
          CheckboxListTile(value: _podPhoto, onChanged: (v) => setState(() => _podPhoto = v ?? false), title: const Text('Geo-tagged Proof of Delivery (POD) Photo Captured')),
          const SizedBox(height: 8),
          TextField(controller: _pinCtrl, maxLength: 4, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Customer 4-Digit Delivery OTP')),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    try {
                      final token = ref.read(authControllerProvider).riderRoleToken;
                      await ref.read(apiClientProvider).post(
                        '/rider/panel/parcel/${parcel['id']}/deliver',
                        roleToken: token,
                        body: {'deliveryPin': _pinCtrl.text.trim(), 'codCollectedConfirm': _codCollected},
                      );
                      if (context.mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => BatchCompletionSummaryScreen(batch: b)),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
            child: const Text('Complete Delivery & Finish Batch ->'),
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
      appBar: AppBar(title: const Text('Batch Completed'), actions: const [TwoBeeHomeAction()]),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 36,
              backgroundColor: TwoBeeColors.surfaceTonal,
              child: Icon(Icons.verified_rounded, color: TwoBeeColors.primary, size: 42),
            ),
            const SizedBox(height: 12),
            Text('Multi-Service Batch ${batch['batchCode']} Completed!', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Card(
              color: TwoBeeColors.obsidian,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    const Text('TOTAL BATCH EARNINGS', style: TextStyle(color: TwoBeeColors.primarySoft, fontWeight: FontWeight.w700, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(bdt(batch['totalPayoutBdt'] as num), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text('Leg 1 Ride (${ride['tripCode']}) + Leg 2 Normal Parcel (${parcel['trackingCode']})', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Card(
              child: ListTile(
                leading: Icon(Icons.check_circle_outline, color: TwoBeeColors.primary),
                title: Text('Front Carrier Emptied & Rear Pillion Free'),
                subtitle: Text('Ready for next single or multi-service dispatch.'),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LookingForRequestsScreen())),
              child: const Text('Find Next Request (Stay Online) ->'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              child: const Text('Take a Break (Rider Home)'),
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
  ConsumerState<RiderFoodExecutionScreen> createState() => _RiderFoodExecutionScreenState();
}

class _RiderFoodExecutionScreenState extends ConsumerState<RiderFoodExecutionScreen> {
  Map<String, dynamic>? _order;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = ref.read(authControllerProvider).riderRoleToken;
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/rider/panel/food/${widget.orderId}', roleToken: token);
      setState(() => _order = Map<String, dynamic>.from(res['order'] as Map));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _order == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final o = _order!;
    final status = o['status'] as String;
    return Scaffold(
      appBar: AppBar(title: Text('Food Delivery ${o['orderCode']}'), actions: const [TwoBeeHomeAction()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: TwoBeeColors.surfaceTonal,
            child: ListTile(
              title: Text('Status: $status', style: const TextStyle(fontWeight: FontWeight.w800, color: TwoBeeColors.primary)),
              subtitle: Text('Pickup: ${o['merchant']?['businessName']}\nDropoff: ${o['deliveryAddress']}\nPayment: ${o['paymentMethod']} · Total ${bdt(o['totalBdt'] as num)}'),
              isThreeLine: true,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: Text('Customer: ${o['user']?['fullName'] ?? ''}'),
              trailing: IconButton(
                icon: const Icon(Icons.chat_outlined, color: TwoBeeColors.primary),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InAppChatScreen(
                      serviceType: 'FOOD',
                      orderId: widget.orderId,
                      peerTitle: o['user']?['fullName']?.toString() ?? 'Customer',
                      senderRole: 'RIDER',
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (status != 'PICKED_UP' && status != 'DELIVERED')
            ElevatedButton(
              onPressed: () async {
                final token = ref.read(authControllerProvider).riderRoleToken;
                await ref.read(apiClientProvider).post('/rider/panel/food/${widget.orderId}/pickup', roleToken: token);
                _load();
              },
              child: const Text('Confirm Picked Up from Restaurant'),
            )
          else if (status == 'PICKED_UP')
            ElevatedButton(
              onPressed: () async {
                final token = ref.read(authControllerProvider).riderRoleToken;
                await ref.read(apiClientProvider).post('/rider/panel/food/${widget.orderId}/deliver', roleToken: token);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text('Complete Delivery & Collect (${bdt(o['riderPayoutBdt'] as num)} Payout)'),
            ),
        ],
      ),
    );
  }
}

class RiderRideExecutionScreen extends ConsumerStatefulWidget {
  final String tripId;
  const RiderRideExecutionScreen({super.key, required this.tripId});

  @override
  ConsumerState<RiderRideExecutionScreen> createState() => _RiderRideExecutionScreenState();
}

class _RiderRideExecutionScreenState extends ConsumerState<RiderRideExecutionScreen> {
  Map<String, dynamic>? _trip;
  final _pinCtrl = TextEditingController();
  bool _loading = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = ref.read(authControllerProvider).riderRoleToken;
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/rider/panel/ride/${widget.tripId}', roleToken: token);
      setState(() => _trip = Map<String, dynamic>.from(res['trip'] as Map));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _trip == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final t = _trip!;
    final status = t['status'] as String;
    return Scaffold(
      appBar: AppBar(title: Text('Ride ${t['tripCode']}'), actions: const [TwoBeeHomeAction()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: TwoBeeColors.surfaceTonal,
            child: ListTile(
              title: Text('Status: $status', style: const TextStyle(fontWeight: FontWeight.w800, color: TwoBeeColors.primary)),
              subtitle: Text('${t['pickupAddress']} → ${t['dropoffAddress']}\nPassenger: ${t['user']?['fullName'] ?? ''} · Fare ${bdt(t['totalFareBdt'] as num)} (PIN: ${t['startPin']})'),
              isThreeLine: true,
            ),
          ),
          const SizedBox(height: 16),
          if (status == 'RIDER_ASSIGNED') ...[
            TextField(controller: _pinCtrl, maxLength: 4, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Enter Passenger 4-Digit Start PIN')),
            if (_err != null) Text(_err!, style: const TextStyle(color: TwoBeeColors.errorText)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                try {
                  final token = ref.read(authControllerProvider).riderRoleToken;
                  await ref.read(apiClientProvider).post('/rider/panel/ride/${widget.tripId}/start', roleToken: token, body: {'startPin': _pinCtrl.text.trim()});
                  _load();
                } catch (e) {
                  setState(() => _err = e.toString());
                }
              },
              child: const Text('Start Ride Trip ->'),
            ),
          ] else if (status == 'ON_TRIP') ...[
            ElevatedButton(
              onPressed: () async {
                final token = ref.read(authControllerProvider).riderRoleToken;
                await ref.read(apiClientProvider).post('/rider/panel/ride/${widget.tripId}/complete', roleToken: token);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text('Complete Dropoff (${bdt(t['riderPayoutBdt'] as num)} Payout)'),
            ),
          ],
        ],
      ),
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = ref.read(authControllerProvider).riderRoleToken;
    if (token == null) return;
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/rider/panel/jobs', roleToken: token);
      setState(() => _jobs = res);
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
        ? allBatches.where((b) => _matchesQuery(b as Map, ['batchCode', 'originZoneId', 'destinationZoneId', 'status'])).toList()
        : [];
    final parcels = (_cat == 'ALL' || _cat == 'PARCEL')
        ? allParcels.where((p) => _matchesQuery(p as Map, ['trackingCode', 'pickupAddress', 'dropoffAddress', 'status'])).toList()
        : [];
    final food = (_cat == 'ALL' || _cat == 'FOOD')
        ? allFood.where((f) => _matchesQuery(f as Map, ['orderCode', 'deliveryAddress', 'status'])).toList()
        : [];
    final rides = (_cat == 'ALL' || _cat == 'RIDE')
        ? allRides.where((r) => _matchesQuery(r as Map, ['tripCode', 'pickupAddress', 'dropoffAddress', 'status'])).toList()
        : [];

    return Scaffold(
      appBar: AppBar(title: const Text('Service History'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh)), const TwoBeeHomeAction()]),
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
                    label: Text(c == 'MULTI' ? 'Multi-Service' : c[0] + c.substring(1).toLowerCase()),
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
                      ...batches.map((b) => Card(
                            color: TwoBeeColors.surfaceTonal,
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              title: Text('Parcel & Ride (${b['batchCode']})', style: const TextStyle(fontWeight: FontWeight.w800)),
                              subtitle: Text('${b['originZoneId']} → ${b['destinationZoneId']} · ${b['status']}'),
                              trailing: Text(bdt(b['totalPayoutBdt'] as num), style: const TextStyle(fontWeight: FontWeight.w800, color: TwoBeeColors.primary)),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _showLive
                                      ? MultiServiceBatchScreen(batchId: b['id'] as String)
                                      : RiderServiceDetailScreen(
                                          serviceType: 'MULTI',
                                          title: 'Multi-Service Batch ${b['batchCode']}',
                                          data: Map<String, dynamic>.from(b as Map),
                                        ),
                                ),
                              ),
                            ),
                          )),
                      ...parcels.map((p) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text('Parcel ${p['trackingCode']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text('${p['pickupAddress']} → ${p['dropoffAddress']} · ${p['status']}'),
                              trailing: Text(bdt(p['riderPayoutBdt'] as num)),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _showLive
                                      ? ParcelPickupScreen(parcelId: p['id'] as String)
                                      : RiderServiceDetailScreen(
                                          serviceType: 'PARCEL',
                                          title: 'Parcel ${p['trackingCode']}',
                                          data: Map<String, dynamic>.from(p as Map),
                                        ),
                                ),
                              ),
                            ),
                          )),
                      ...food.map((f) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text('Food ${f['orderCode']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text('${f['merchant']?['businessName'] ?? ''} · ${f['status']}'),
                              trailing: Text(bdt(f['riderPayoutBdt'] as num)),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _showLive
                                      ? RiderFoodExecutionScreen(orderId: f['id'] as String)
                                      : RiderServiceDetailScreen(
                                          serviceType: 'FOOD',
                                          title: 'Food ${f['orderCode']}',
                                          data: Map<String, dynamic>.from(f as Map),
                                        ),
                                ),
                              ),
                            ),
                          )),
                      ...rides.map((r) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text('Ride ${r['tripCode']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text('${r['pickupAddress']} → ${r['dropoffAddress']} · ${r['status']}'),
                              trailing: Text(bdt(r['riderPayoutBdt'] as num)),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _showLive
                                      ? RiderRideExecutionScreen(tripId: r['id'] as String)
                                      : RiderServiceDetailScreen(
                                          serviceType: 'RIDE',
                                          title: 'Ride ${r['tripCode']}',
                                          data: Map<String, dynamic>.from(r as Map),
                                        ),
                                ),
                              ),
                            ),
                          )),
                      if (batches.isEmpty && parcels.isEmpty && food.isEmpty && rides.isEmpty)
                        const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No jobs matching filter in this tab.'))),
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
  const RiderServiceDetailScreen({super.key, required this.serviceType, required this.title, required this.data});

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
            decoration: BoxDecoration(color: TwoBeeColors.obsidian, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$serviceType JOB DETAIL', style: const TextStyle(color: TwoBeeColors.primarySoft, fontSize: 12, fontWeight: FontWeight.w700)),
                Text(bdt(payout as num), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                Text('Status: ${data['status']}', style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (serviceType == 'MULTI' && ride != null && parcel != null) ...[
            Card(
              color: TwoBeeColors.surfaceTonal,
              child: ListTile(
                title: Text('Stop 1 · Passenger Ride (${ride['tripCode']})', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${ride['pickupAddress']} -> ${ride['dropoffAddress']} · ${bdt(ride['riderPayoutBdt'] as num)}'),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                title: Text('Stop 2 · Front-Rack Parcel (${parcel['trackingCode']})', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${parcel['pickupAddress']} -> ${parcel['dropoffAddress']} · ${bdt(parcel['riderPayoutBdt'] as num)}'),
              ),
            ),
          ] else
            Card(
              child: ListTile(
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${data['pickupAddress'] ?? data['merchant']?['businessName'] ?? ''} -> ${data['dropoffAddress'] ?? data['deliveryAddress'] ?? ''}'),
              ),
            ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportLegalScreen(title: 'Report Route Issue'))),
            icon: const Icon(Icons.report_problem_outlined),
            label: const Text('Report Route / Payout Issue'),
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = ref.read(authControllerProvider).riderRoleToken;
    if (token == null) return;
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/rider/panel/wallet', roleToken: token);
      setState(() => _data = res);
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
      appBar: AppBar(title: const Text('Wallet & Earnings'), actions: const [TwoBeeHomeAction()]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Wallet & Payouts')),
                      ButtonSegment(value: true, label: Text('Earnings Analytics')),
                    ],
                    selected: {_showAnalytics},
                    onSelectionChanged: (v) => setState(() => _showAnalytics = v.first),
                  ),
                  const SizedBox(height: 14),
                  if (!_showAnalytics) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: TwoBeeColors.obsidian, borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Available Balance', style: TextStyle(color: TwoBeeColors.primarySoft)),
                          Text(bdt(wallet['balanceBdt'] ?? 0), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text('COD Cash-in-Hand: ${bdt(wallet['codCashInHandBdt'] ?? 0)}', style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                    if (rental != null) ...[
                      const SizedBox(height: 12),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.electric_moped_rounded, color: TwoBeeColors.primary),
                          title: Text('Bike Rent Due: ${bdt(rental['dailyRateBdt'] ?? 250)}/day'),
                          subtitle: Text('${rental['bikeModel']} · Auto-debit active'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Text('Recent Ledger', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    ...txs.map((t) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(t['description']?.toString() ?? ''),
                            trailing: Text(
                              '${(t['amountBdt'] as num) >= 0 ? '+' : ''}${bdt(t['amountBdt'] as num)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: (t['amountBdt'] as num) >= 0 ? TwoBeeColors.primary : TwoBeeColors.errorText,
                              ),
                            ),
                          ),
                        )),
                  ] else ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Ledger Earnings: ${bdt(analytics['earningsTotal'] ?? 0)}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: TwoBeeColors.primary)),
                            const SizedBox(height: 6),
                            Text('Rental & Other Deductions: ${bdt(analytics['deductionsTotal'] ?? 0)}'),
                            Text('Completed Lifetime Trips: ${analytics['totalTrips'] ?? 0}'),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Rider Profile'), actions: const [TwoBeeHomeAction()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: TwoBeeColors.surfaceTonal, child: Icon(Icons.two_wheeler_rounded, color: TwoBeeColors.primary)),
              title: Text(user?['fullName']?.toString() ?? 'Rider Partner', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Verified Rider · 4-Digit Passcode Active'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.inventory_2_outlined, color: TwoBeeColors.primary),
                  title: const Text('Carrying Setup & Multi-Service Mode'),
                  subtitle: const Text('Front carrier <=8kg + spare helmet'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CarryingSetupScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.electric_moped_outlined, color: TwoBeeColors.primary),
                  title: const Text('Bike Rental Hub'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BikeRentalHomeScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.security_rounded, color: TwoBeeColors.primary),
                  title: const Text('Security Settings (4-Digit PIN & 48h Payout Guard)'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiderSecurityScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.swap_horiz_rounded, color: TwoBeeColors.primary),
                  title: const Text('Switch Role'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.go('/roles'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help_outline_rounded, color: TwoBeeColors.primary),
                  title: const Text('Help, Support & Terms'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportLegalScreen(title: 'Rider Support & Policy'))),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.account_tree_outlined, color: TwoBeeColors.primary),
                  title: const Text('Preview All 2Bee Screens & Step Flows'),
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

class CarryingSetupScreen extends ConsumerStatefulWidget {
  const CarryingSetupScreen({super.key});

  @override
  ConsumerState<CarryingSetupScreen> createState() => _CarryingSetupScreenState();
}

class _CarryingSetupScreenState extends ConsumerState<CarryingSetupScreen> {
  bool _multi = true;
  bool _helmet = true;
  String? _err;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Today's Carrying Setup"), actions: const [TwoBeeHomeAction()]),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Card(
              color: TwoBeeColors.surfaceTonal,
              child: ListTile(
                title: Text('Front Carrier: 35×30×30 cm · Max 8 kg'),
                subtitle: Text('Multi-Service Rules: Normal parcels only · 1 passenger max · Zone A → B match · Passenger dropped first.'),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(value: _multi, onChanged: (v) => setState(() => _multi = v), title: const Text('Parcels + Passengers (Multi-Service)')),
            CheckboxListTile(value: _helmet, onChanged: (v) => setState(() => _helmet = v ?? false), title: const Text('I have a spare helmet for passenger')),
            if (_err != null) Text(_err!, style: const TextStyle(color: TwoBeeColors.errorText)),
            const Spacer(),
            ElevatedButton(
              onPressed: () async {
                try {
                  final token = ref.read(authControllerProvider).riderRoleToken;
                  await ref.read(apiClientProvider).patch('/rider/panel/carrying-setup', roleToken: token, body: {
                    'multiServiceEnabled': _multi,
                    'spareHelmetConfirmed': _helmet,
                  });
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
  ConsumerState<BikeRentalHomeScreen> createState() => _BikeRentalHomeScreenState();
}

class _BikeRentalHomeScreenState extends ConsumerState<BikeRentalHomeScreen> {
  Map<String, dynamic>? _activeRental;
  List<dynamic> _bikes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = ref.read(authControllerProvider).riderRoleToken;
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/rider/panel/rentals', roleToken: token);
      if (mounted) {
        setState(() {
          _activeRental = res['activeRental'] as Map<String, dynamic>?;
          _bikes = (res['fleetBikes'] as List?) ?? [];
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _rentBike(String bikeId) async {
    final token = ref.read(authControllerProvider).riderRoleToken;
    try {
      await ref.read(apiClientProvider).post('/rider/panel/rentals/book', roleToken: token, body: {'bikeId': bikeId, 'planType': 'DAILY'});
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('EV Rental activated cleanly!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('2Bee EV Bike Rental'), actions: const [TwoBeeHomeAction()]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_activeRental != null) ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: TwoBeeColors.obsidian, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ACTIVE RENTAL', style: TextStyle(color: TwoBeeColors.primarySoft, fontSize: 11, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(_activeRental!['bikeModel'].toString(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                        Text('${_activeRental!['hubName']} · ${_activeRental!['plateNo']}', style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 6),
                        Text('Plan: ${bdt(_activeRental!['dailyRateBdt'] ?? 250)}/day', style: const TextStyle(color: TwoBeeColors.primarySoft)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text('Available 2Bee EVs for Rent', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 8),
                ..._bikes.map((b) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const Icon(Icons.electric_moped_rounded, color: TwoBeeColors.primary, size: 32),
                        title: Text(b['modelName'].toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('${b['hubName']} · ${b['rangeKm']}km range · ${bdt(b['dailyRateBdt'] as num)}/day'),
                        trailing: FilledButton(
                          onPressed: () => _rentBike(b['id'] as String),
                          child: const Text('Rent'),
                        ),
                      ),
                    )),
              ],
            ),
    );
  }
}

class RiderSecurityScreen extends ConsumerStatefulWidget {
  const RiderSecurityScreen({super.key});

  @override
  ConsumerState<RiderSecurityScreen> createState() => _RiderSecurityScreenState();
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
    final res = await ref.read(apiClientProvider).get('/rider/panel/security', roleToken: token);
    if (mounted) setState(() => _secData = res);
  }

  @override
  Widget build(BuildContext context) {
    final payout = _secData?['payoutAccount'] as Map?;
    final devices = (_secData?['devices'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Rider Security (4-Digit PIN)'), actions: const [TwoBeeHomeAction()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            color: TwoBeeColors.surfaceTonal,
            child: ListTile(
              leading: Icon(Icons.shield_outlined, color: TwoBeeColors.primary),
              title: Text('4-Digit Passcode + 15-min Auto-Lock'),
              subtitle: Text('Payout method updates require SMS OTP + 48-hour hold.'),
            ),
          ),
          if (payout?['pendingEffectiveAt'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: VerificationBanner(
                title: '48-Hour Payout Hold Active',
                subtitle: 'Pending change takes effect at ${payout!['pendingEffectiveAt']}',
              ),
            ),
          const SizedBox(height: 14),
          const Text('Change 4-Digit Passcode', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(controller: _cur, maxLength: 4, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Current 4-digit PIN')),
          const SizedBox(height: 8),
          TextField(controller: _next, maxLength: 4, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'New 4-digit PIN')),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () async {
              final token = ref.read(authControllerProvider).riderRoleToken;
              await ref.read(apiClientProvider).post('/rider/panel/security/change-pin', roleToken: token, body: {
                'currentPasscode': _cur.text.trim(),
                'newPasscode': _next.text.trim(),
              });
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('4-digit Rider PIN updated!')));
            },
            child: const Text('Update 4-Digit Passcode'),
          ),
          const SizedBox(height: 20),
          const Text('Request Payout Change (SMS OTP + 48h Hold)', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              final phone = ref.read(authControllerProvider).user?['phone'] as String;
              final res = await ref.read(apiClientProvider).post('/auth/otp/request', body: {'phone': phone, 'purpose': 'PAYOUT_CHANGE'});
              if (res['devOtpHint'] != null) _otpCtrl.text = res['devOtpHint'] as String;
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SMS OTP requested')));
            },
            child: const Text('Send Payout Verification OTP'),
          ),
          const SizedBox(height: 8),
          TextField(controller: _otpCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '6-digit SMS OTP')),
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
          TextField(controller: _payoutNoCtrl, decoration: const InputDecoration(labelText: 'New Wallet / Account Number')),
          const SizedBox(height: 8),
          TextField(controller: _holderCtrl, decoration: const InputDecoration(labelText: 'Holder Name (Match NID)')),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () async {
              final token = ref.read(authControllerProvider).riderRoleToken;
              await ref.read(apiClientProvider).post('/rider/panel/payout/change-request', roleToken: token, body: {
                'otpCode': _otpCtrl.text.trim(),
                'provider': _provider,
                'accountNumber': _payoutNoCtrl.text.trim(),
                'holderName': _holderCtrl.text.trim(),
              });
              _load();
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submitted! 48-hour hold applied.')));
            },
            child: const Text('Submit Payout Change (48h Hold)'),
          ),
          if (devices.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Authorized Devices', style: TextStyle(fontWeight: FontWeight.w800)),
            ...devices.map((d) => Card(
                  margin: const EdgeInsets.only(top: 8),
                  child: ListTile(
                    title: Text(d['deviceName'].toString()),
                    trailing: TextButton(
                      onPressed: () async {
                        final token = ref.read(authControllerProvider).riderRoleToken;
                        await ref.read(apiClientProvider).delete('/rider/panel/security/devices/${d['id']}', roleToken: token);
                        _load();
                      },
                      child: const Text('Remove'),
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

