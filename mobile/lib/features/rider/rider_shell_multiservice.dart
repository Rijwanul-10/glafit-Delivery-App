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
      final res = await ref.read(apiClientProvider).get('/rider/panel/home', roleToken: token);
      setState(() => _home = res);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleOnline(bool goOnline) async {
    final token = ref.read(authControllerProvider).riderRoleToken;
    try {
      await ref.read(apiClientProvider).post('/rider/panel/online', roleToken: token, body: {
        'isOnline': goOnline,
        'lat': 23.7937,
        'lng': 90.4066,
      });
      final riderId = _home?['rider']?['id'] as String?;
      if (goOnline && riderId != null) {
        ref.read(socketServiceProvider).streamRiderLocation(riderId: riderId, lat: 23.7937, lng: 90.4066);
      }
      _load();
      if (goOnline && mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const LookingForRequestsScreen()));
      }
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
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!approved) ...[
              const VerificationBanner(
                title: 'Verification in progress',
                subtitle: 'You can go online once approved by 2Bee KYC team.',
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

  @override
  Widget build(BuildContext context) {
    final parcels = (_open?['parcel'] as List?) ?? [];
    final rides = (_open?['ride'] as List?) ?? [];
    final food = (_open?['food'] as List?) ?? [];
    final addons = (_open?['multiServiceRideAddons'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Looking for Requests'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const TwoBeeMapPreview(height: 170),
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
                            child: const Text('Accept'),
                          ),
                        ),
                      )),
                ],
                const Text('Parcel Requests', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 8),
                if (parcels.isEmpty)
                  const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('No waiting parcels right now.')))
                else
                  ...parcels.map((p) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text('${p['tier']} · ${p['trackingCode']} (${p['weightKg']} kg)', style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${p['pickupAddress']} → ${p['dropoffAddress']}\nFits front carrier: ${p['fitsFrontCarrier']}'),
                          isThreeLine: true,
                          trailing: FilledButton(
                            onPressed: () async {
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
                            final token = ref.read(authControllerProvider).riderRoleToken;
                            await ref.read(apiClientProvider).post('/rider/panel/food/${f['id']}/accept', roleToken: token);
                            await ref.read(apiClientProvider).post('/rider/panel/food/${f['id']}/pickup', roleToken: token);
                            await ref.read(apiClientProvider).post('/rider/panel/food/${f['id']}/deliver', roleToken: token);
                            _load();
                          },
                          child: Text('Run ${bdt(f['riderPayoutBdt'] as num)}'),
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
                            final token = ref.read(authControllerProvider).riderRoleToken;
                            await ref.read(apiClientProvider).post('/rider/panel/ride/${r['id']}/accept', roleToken: token);
                            _load();
                          },
                          child: Text(bdt(r['riderPayoutBdt'] as num)),
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
  final _weightCtrl = TextEditingController(text: '2.1');
  final _pinCtrl = TextEditingController();
  bool _pickedUp = false;
  bool _msEligible = false;
  String? _ineligibleReason;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parcel Pickup & Front Rack')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_pickedUp) ...[
            TextField(controller: _weightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Actual Verified Weight (kg, Max 8.0 front)')),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                final token = ref.read(authControllerProvider).riderRoleToken;
                final res = await ref.read(apiClientProvider).post('/rider/panel/parcel/${widget.parcelId}/pickup', roleToken: token, body: {
                  'actualWeightKg': double.tryParse(_weightCtrl.text) ?? 2.0,
                  'pickupPhotoUrl': '/uploads/front-rack-proof.jpg',
                });
                setState(() {
                  _pickedUp = true;
                  _msEligible = res['multiServiceEligible'] == true;
                  _ineligibleReason = res['ineligibleReason'] as String?;
                });
              },
              child: const Text('Confirm Picked Up & Proof Photo'),
            ),
          ] else ...[
            VerificationBanner(
              title: _msEligible ? 'Multi-Service Ride Radar Active (Zone A → B)' : 'Single-Service Locked',
              subtitle: _msEligible
                  ? 'Matching Zone A -> Zone B passenger rides can now be added!'
                  : (_ineligibleReason ?? 'Not eligible for co-ride'),
              isErrorStyle: !_msEligible,
            ),
            const SizedBox(height: 14),
            if (_msEligible)
              OutlinedButton.icon(
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LookingForRequestsScreen())),
                icon: const Icon(Icons.radar_rounded),
                label: const Text('Check Matching Zone A → B Ride Add-ons'),
              ),
            const SizedBox(height: 16),
            TextField(controller: _pinCtrl, maxLength: 4, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Customer 4-digit Delivery PIN')),
            ElevatedButton(
              onPressed: () async {
                final token = ref.read(authControllerProvider).riderRoleToken;
                await ref.read(apiClientProvider).post('/rider/panel/parcel/${widget.parcelId}/deliver', roleToken: token, body: {
                  'deliveryPin': _pinCtrl.text.trim(),
                });
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Complete Parcel Delivery'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Rider Multi-Service Execution Screen (Stop 1: Drop Passenger FIRST -> Stop 2: Deliver Parcel SECOND)
/// Visible EXCLUSIVELY on Rider side!
class MultiServiceBatchScreen extends ConsumerStatefulWidget {
  final String batchId;
  const MultiServiceBatchScreen({super.key, required this.batchId});

  @override
  ConsumerState<MultiServiceBatchScreen> createState() => _MultiServiceBatchScreenState();
}

class _MultiServiceBatchScreenState extends ConsumerState<MultiServiceBatchScreen> {
  Map<String, dynamic>? _batch;
  final _startPinCtrl = TextEditingController();
  final _deliveryPinCtrl = TextEditingController();
  bool _paxHelmet = true;
  bool _helmetReturned = true;
  bool _curbOk = true;
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
      final res = await ref.read(apiClientProvider).get('/rider/panel/jobs/batch/${widget.batchId}', roleToken: token);
      setState(() => _batch = Map<String, dynamic>.from(res['batch'] as Map));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _batch == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final b = _batch!;
    final status = b['status'] as String;
    final ride = b['rideTrip'] as Map;
    final parcel = b['parcelShipment'] as Map;

    return Scaffold(
      appBar: AppBar(
        title: Text('Multi-Service ${b['batchCode']}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${ride['dropoffLat']},${ride['dropoffLng']}')),
          ),
        ],
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
                  Text('Corridor: ${b['originZoneId']} → ${b['destinationZoneId']}', style: const TextStyle(color: TwoBeeColors.primarySoft, fontWeight: FontWeight.w700)),
                  Text('Total Batch Payout: ${bdt(b['totalPayoutBdt'] as num)}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  Text('Stage: $status', style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: Text('STOP 1 · Drop Passenger FIRST: ${ride['user']?['fullName'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${ride['pickupAddress']} → ${ride['dropoffAddress']} · PIN: ${ride['startPin']}'),
              trailing: Text(ride['status'].toString(), style: const TextStyle(fontWeight: FontWeight.w700, color: TwoBeeColors.primary)),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: Text('STOP 2 · Deliver Parcel SECOND: ${parcel['recipientName']}', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${parcel['dropoffAddress']} · COD ${bdt(parcel['codCollectBdt'] ?? 0)} · PIN: ${parcel['deliveryPin']}'),
              trailing: Text(parcel['status'].toString()),
            ),
          ),
          const SizedBox(height: 16),
          if (status == 'PASSENGER_PICKUP_PENDING') ...[
            TextField(controller: _startPinCtrl, maxLength: 4, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Enter Passenger 4-Digit Start PIN')),
            CheckboxListTile(value: _paxHelmet, onChanged: (v) => setState(() => _paxHelmet = v ?? false), title: const Text('Passenger wearing helmet')),
            ElevatedButton(
              onPressed: () async {
                final token = ref.read(authControllerProvider).riderRoleToken;
                await ref.read(apiClientProvider).post('/rider/panel/multi-service/${widget.batchId}/passenger-pickup',
                    roleToken: token, body: {'startPin': _startPinCtrl.text.trim(), 'passengerHasHelmet': _paxHelmet});
                _load();
              },
              child: const Text('Start Ride Leg 1 ->'),
            ),
          ] else if (status == 'PASSENGER_ONBOARD') ...[
            CheckboxListTile(value: _helmetReturned, onChanged: (v) => setState(() => _helmetReturned = v ?? false), title: const Text('Helmet returned & sanitized')),
            CheckboxListTile(value: _curbOk, onChanged: (v) => setState(() => _curbOk = v ?? false), title: const Text('Dismounted safely on curb')),
            ElevatedButton(
              onPressed: () async {
                final token = ref.read(authControllerProvider).riderRoleToken;
                await ref.read(apiClientProvider).post('/rider/panel/multi-service/${widget.batchId}/passenger-dropoff',
                    roleToken: token, body: {'helmetReturnedOk': _helmetReturned, 'curbDismountOk': _curbOk});
                _load();
              },
              child: const Text('Complete Passenger Dropoff -> Head to Parcel'),
            ),
          ] else if (status == 'PASSENGER_DROPPED') ...[
            TextField(controller: _deliveryPinCtrl, maxLength: 4, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Enter Customer 4-Digit Delivery PIN')),
            ElevatedButton(
              onPressed: () async {
                final token = ref.read(authControllerProvider).riderRoleToken;
                await ref.read(apiClientProvider).post('/rider/panel/parcel/${parcel['id']}/deliver',
                    roleToken: token, body: {'deliveryPin': _deliveryPinCtrl.text.trim(), 'codCollectedConfirm': true});
                _load();
              },
              child: const Text('Complete Stop 2 Parcel Delivery & Finish Batch'),
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

  @override
  Widget build(BuildContext context) {
    final bucket = (_jobs?[_showLive ? 'live' : 'completed'] as Map?) ?? {};
    final batches = (bucket['multiServiceBatches'] as List?) ?? [];
    final parcels = (bucket['parcels'] as List?) ?? [];
    final food = (bucket['food'] as List?) ?? [];
    final rides = (bucket['rides'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Service History'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Live')),
                ButtonSegment(value: false, label: Text('Completed')),
              ],
              selected: {_showLive},
              onSelectionChanged: (v) => setState(() => _showLive = v.first),
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
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MultiServiceBatchScreen(batchId: b['id'] as String))),
                            ),
                          )),
                      ...parcels.map((p) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text('Parcel ${p['trackingCode']}'),
                              subtitle: Text('${p['pickupAddress']} → ${p['dropoffAddress']}'),
                              trailing: Text(bdt(p['riderPayoutBdt'] as num)),
                            ),
                          )),
                      ...food.map((f) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text('Food ${f['orderCode']}'),
                              subtitle: Text('${f['merchant']?['businessName'] ?? ''} · ${f['status']}'),
                              trailing: Text(bdt(f['riderPayoutBdt'] as num)),
                            ),
                          )),
                      ...rides.map((r) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text('Ride ${r['tripCode']}'),
                              subtitle: Text('${r['pickupAddress']} → ${r['dropoffAddress']}'),
                              trailing: Text(bdt(r['riderPayoutBdt'] as num)),
                            ),
                          )),
                      if (batches.isEmpty && parcels.isEmpty && food.isEmpty && rides.isEmpty)
                        const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No jobs in this tab yet.'))),
                    ],
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
      appBar: AppBar(title: const Text('Wallet & Earnings')),
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
      appBar: AppBar(title: const Text('Rider Profile')),
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
      appBar: AppBar(title: const Text("Today's Carrying Setup")),
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
  List<dynamic> _bikes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = ref.read(authControllerProvider).riderRoleToken;
    final res = await ref.read(apiClientProvider).get('/rider/panel/rentals', roleToken: token);
    if (mounted) setState(() => _bikes = (res['fleetBikes'] as List?) ?? []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('2Bee EV Bike Rental')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: _bikes
            .map((b) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const Icon(Icons.electric_moped_rounded, color: TwoBeeColors.primary, size: 32),
                    title: Text(b['modelName'].toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${b['hubName']} · ${b['rangeKm']}km range · ${b['availableQty']} available'),
                    trailing: Text('${bdt(b['dailyRateBdt'] as num)}/day', style: const TextStyle(fontWeight: FontWeight.w800, color: TwoBeeColors.primary)),
                  ),
                ))
            .toList(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rider Security (4-Digit PIN)')),
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
          const SizedBox(height: 14),
          TextField(controller: _cur, maxLength: 4, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Current 4-digit PIN')),
          const SizedBox(height: 8),
          TextField(controller: _next, maxLength: 4, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'New 4-digit PIN')),
          const SizedBox(height: 12),
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
        ],
      ),
    );
  }
}

