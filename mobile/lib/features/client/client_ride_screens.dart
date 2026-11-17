import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/twobee_theme.dart';
import '../../core/widgets/common_widgets.dart';
import '../common/shared_screens.dart';

const _rideZoneSpots = [
  {'id': 'zone-banani', 'name': 'Banani Road 11', 'lat': 23.7937, 'lng': 90.4066},
  {'id': 'zone-gulshan', 'name': 'Gulshan 2 Circle', 'lat': 23.7925, 'lng': 90.4158},
  {'id': 'zone-uttara', 'name': 'Uttara Sector 3', 'lat': 23.8648, 'lng': 90.3974},
  {'id': 'zone-mirpur', 'name': 'Mirpur 10 Circle', 'lat': 23.8069, 'lng': 90.3687},
  {'id': 'zone-dhanmondi', 'name': 'Dhanmondi 27', 'lat': 23.7461, 'lng': 90.3742},
];

/// Ride 1: Map Radar & Location Selector (custom bottom pill nav removed per Unified Navigation!)
class RideLocationScreen extends ConsumerStatefulWidget {
  const RideLocationScreen({super.key});

  @override
  ConsumerState<RideLocationScreen> createState() => _RideLocationScreenState();
}

class _RideLocationScreenState extends ConsumerState<RideLocationScreen> {
  Map<String, dynamic> _pickup = _rideZoneSpots[0];
  Map<String, dynamic> _dropoff = _rideZoneSpots[2];
  bool _loading = false;

  Future<void> _searchPlaceDialog({required bool forPickup}) async {
    final qCtrl = TextEditingController();
    List<Map<String, dynamic>> results = List<Map<String, dynamic>>.from(_rideZoneSpots);
    bool searching = false;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(forPickup ? 'Search Pickup Spot (OSM)' : 'Search Destination (OSM)'),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search Banani, Uttara, Gulshan...',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () async {
                        setD(() => searching = true);
                        try {
                          final res = await ref.read(apiClientProvider).get('/common/places/search?q=${Uri.encodeComponent(qCtrl.text.trim())}');
                          final list = (res['places'] as List?) ?? [];
                          setD(() {
                            results = list
                                .map((p) => {
                                      'id': p['zoneId'] ?? 'zone-banani',
                                      'name': p['name'] ?? p['displayName'] ?? 'Dhaka Spot',
                                      'lat': (p['lat'] as num?)?.toDouble() ?? 23.7937,
                                      'lng': (p['lng'] as num?)?.toDouble() ?? 90.4066,
                                    })
                                .toList();
                          });
                        } finally {
                          setD(() => searching = false);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (searching) const LinearProgressIndicator(),
                SizedBox(
                  height: 200,
                  child: ListView(
                    children: results
                        .map((r) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.place_outlined, color: TwoBeeColors.primary),
                              title: Text(r['name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis),
                              onTap: () {
                                setState(() {
                                  if (forPickup) {
                                    _pickup = r;
                                  } else {
                                    _dropoff = r;
                                  }
                                });
                                Navigator.pop(ctx);
                              },
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        ),
      ),
    );
  }

  Future<void> _estimate() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).post('/rides/estimate', body: {
        'pickupLat': _pickup['lat'],
        'pickupLng': _pickup['lng'],
        'pickupZoneId': _pickup['id'],
        'dropoffLat': _dropoff['lat'],
        'dropoffLng': _dropoff['lng'],
        'dropoffZoneId': _dropoff['id'],
      });
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RideTierScreen(
            pickup: _pickup,
            dropoff: _dropoff,
            estimate: res,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not estimate route: $e'), backgroundColor: TwoBeeColors.errorText),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('2Bee Ride'),
        actions: const [TwoBeeHomeAction()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Stack(
            children: [
              TwoBeeMapPreview(
                pickupLat: (_pickup['lat'] as num).toDouble(),
                pickupLng: (_pickup['lng'] as num).toDouble(),
                dropoffLat: (_dropoff['lat'] as num).toDouble(),
                dropoffLng: (_dropoff['lng'] as num).toDouble(),
                height: 210,
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: TwoBeeColors.obsidian.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.electric_moped_rounded, color: TwoBeeColors.primarySoft, size: 15),
                      SizedBox(width: 6),
                      Text('4 EV Riders Nearby · 2m', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: TwoBeeColors.surfaceTonal,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: TwoBeeColors.primary.withValues(alpha: 0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.eco_rounded, color: TwoBeeColors.primary, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '100% Zero-Emission Electric EV Fleet · Glafit GFR-02 & LOM EV',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: TwoBeeColors.primary),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('PICKUP SPOT', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: TwoBeeColors.textSecondary, letterSpacing: 0.7)),
                      TextButton.icon(
                        onPressed: () => _searchPlaceDialog(forPickup: true),
                        icon: const Icon(Icons.search, size: 16),
                        label: const Text('Search Map'),
                      ),
                    ],
                  ),
                  DropdownButton<Map<String, dynamic>>(
                    isExpanded: true,
                    value: _rideZoneSpots.contains(_pickup) ? _pickup : null,
                    hint: Text(_pickup['name'] as String),
                    items: _rideZoneSpots.map((z) => DropdownMenuItem(value: z, child: Text(z['name'] as String))).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _pickup = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('WHERE TO?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: TwoBeeColors.textSecondary, letterSpacing: 0.7)),
                      TextButton.icon(
                        onPressed: () => _searchPlaceDialog(forPickup: false),
                        icon: const Icon(Icons.search, size: 16),
                        label: const Text('Search Map'),
                      ),
                    ],
                  ),
                  DropdownButton<Map<String, dynamic>>(
                    isExpanded: true,
                    value: _rideZoneSpots.contains(_dropoff) ? _dropoff : null,
                    hint: Text(_dropoff['name'] as String),
                    items: _rideZoneSpots.map((z) => DropdownMenuItem(value: z, child: Text(z['name'] as String))).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _dropoff = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('SAVED & RECENT DESTINATIONS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: TwoBeeColors.textSecondary, letterSpacing: 0.7)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(avatar: const Icon(Icons.home_outlined, size: 16), label: const Text('Uttara'), onPressed: () => setState(() => _dropoff = _rideZoneSpots[2])),
                      ActionChip(avatar: const Icon(Icons.work_outline, size: 16), label: const Text('Gulshan 2'), onPressed: () => setState(() => _dropoff = _rideZoneSpots[1])),
                      ActionChip(avatar: const Icon(Icons.history_rounded, size: 16), label: const Text('Mirpur 10'), onPressed: () => setState(() => _dropoff = _rideZoneSpots[3])),
                      ActionChip(avatar: const Icon(Icons.place_outlined, size: 16), label: const Text('Dhanmondi 27'), onPressed: () => setState(() => _dropoff = _rideZoneSpots[4])),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _loading ? null : _estimate,
            child: Text(_loading ? 'Calculating Route...' : 'Find Rides ->'),
          ),
        ],
      ),
    );
  }
}

/// Ride 2: Vehicle & Fleet Tier Selection
class RideTierScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> pickup;
  final Map<String, dynamic> dropoff;
  final Map<String, dynamic> estimate;

  const RideTierScreen({super.key, required this.pickup, required this.dropoff, required this.estimate});

  @override
  ConsumerState<RideTierScreen> createState() => _RideTierScreenState();
}

class _RideTierScreenState extends ConsumerState<RideTierScreen> {
  String _selectedTier = '2BEE_EV_SOLO';
  String _payment = 'COD';
  final _promoCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _confirm() async {
    final tiers = (widget.estimate['tiers'] as List).cast<Map<String, dynamic>>();
    final chosen = tiers.firstWhere((t) => t['id'] == _selectedTier);
    if (_payment == 'STRIPE_SANDBOX') {
      final paid = await showStripeSandboxDialog(
        context,
        amountBdt: chosen['totalFareBdt'] as num,
        title: 'Ride · ${chosen['name']}',
      );
      if (!paid) return;
    }

    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).post('/rides/request', body: {
        'fleetTier': _selectedTier,
        'pickupAddress': widget.pickup['name'],
        'pickupLat': widget.pickup['lat'],
        'pickupLng': widget.pickup['lng'],
        'pickupZoneId': widget.pickup['id'],
        'dropoffAddress': widget.dropoff['name'],
        'dropoffLat': widget.dropoff['lat'],
        'dropoffLng': widget.dropoff['lng'],
        'dropoffZoneId': widget.dropoff['id'],
        'promoCode': _promoCtrl.text.trim().isNotEmpty ? _promoCtrl.text.trim() : null,
        'paymentMethod': _payment,
      });
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => RideMatchingRadarScreen(tripId: res['trip']['id'] as String)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not dispatch ride: $e'), backgroundColor: TwoBeeColors.errorText),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tiers = (widget.estimate['tiers'] as List).cast<Map<String, dynamic>>();
    final distKm = (widget.estimate['distanceKm'] as num?) ?? 5.0;
    final co2SavedKg = (distKm * 0.14).toStringAsFixed(2);
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Fleet Tier'), actions: const [TwoBeeHomeAction()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: TwoBeeColors.surfaceTonal,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.route_rounded, color: TwoBeeColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${widget.pickup['name']} → ${widget.dropoff['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text('${distKm.toStringAsFixed(1)} km · Fixed Price Guarantee', style: const TextStyle(fontSize: 12, color: TwoBeeColors.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: TwoBeeColors.primary, borderRadius: BorderRadius.circular(12)),
                    child: Text('$co2SavedKg kg CO2 saved', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...tiers.map((t) {
            final sel = _selectedTier == t['id'];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              color: sel ? TwoBeeColors.surfaceTonal : TwoBeeColors.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: sel ? TwoBeeColors.primary : TwoBeeColors.borderSoft, width: sel ? 2 : 1),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: sel ? TwoBeeColors.primary : TwoBeeColors.surfaceTonal,
                  child: Icon(Icons.electric_moped_rounded, color: sel ? Colors.white : TwoBeeColors.primary),
                ),
                title: Text(t['name'] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${t['subtitle']} · ETA ${t['etaMins']} mins'),
                trailing: Text(bdt(t['totalFareBdt'] as num), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: TwoBeeColors.primary)),
                onTap: () => setState(() => _selectedTier = t['id'] as String),
              ),
            );
          }),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(controller: _promoCtrl, decoration: const InputDecoration(hintText: 'Promo code (try 2BEE10)')),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  final ok = _promoCtrl.text.trim().toUpperCase() == '2BEE10';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? 'Promo 2BEE10 applied (10% discount calculated on confirm)!' : 'Try promo code 2BEE10')),
                  );
                },
                child: const Text('Apply'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PaymentSelectorCard(selectedMethod: _payment, onSelected: (m) => setState(() => _payment = m)),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _loading ? null : _confirm,
            child: Text(_loading ? 'Dispatching...' : 'Confirm Ride Request'),
          ),
        ],
      ),
    );
  }
}

/// Ride 3: Courier & Rider Matching Radar
class RideMatchingRadarScreen extends ConsumerStatefulWidget {
  final String tripId;
  const RideMatchingRadarScreen({super.key, required this.tripId});

  @override
  ConsumerState<RideMatchingRadarScreen> createState() => _RideMatchingRadarScreenState();
}

class _RideMatchingRadarScreenState extends ConsumerState<RideMatchingRadarScreen> {
  Map<String, dynamic>? _trip;
  int _secondsLeft = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    final sock = ref.read(socketServiceProvider);
    sock.joinTracking('ride', widget.tripId);
    sock.socket?.off('ride:status');
    sock.socket?.on('ride:status', (_) => _load());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft = _secondsLeft > 0 ? _secondsLeft - 1 : 0);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final res = await ref.read(apiClientProvider).get('/rides/${widget.tripId}');
    final t = Map<String, dynamic>.from(res['trip'] as Map);
    if (!mounted) return;
    if (t['status'] != 'MATCHING') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => RideActiveTripScreen(tripId: widget.tripId)),
      );
      return;
    }
    setState(() => _trip = t);
  }

  Future<void> _simulateMatch() async {
    await ref.read(apiClientProvider).post('/common/demo/advance-ride/${widget.tripId}');
    await _load();
  }

  Future<void> _cancel() async {
    await ref.read(apiClientProvider).post('/rides/${widget.tripId}/cancel');
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = _trip;
    return Scaffold(
      appBar: AppBar(title: const Text('3. Rider Matching Radar'), actions: const [TwoBeeHomeAction()]),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (t != null)
              TwoBeeMapPreview(
                pickupLat: (t['pickupLat'] as num).toDouble(),
                pickupLng: (t['pickupLng'] as num).toDouble(),
                dropoffLat: (t['dropoffLat'] as num).toDouble(),
                dropoffLng: (t['dropoffLng'] as num).toDouble(),
                height: 180,
              ),
            const Spacer(),
            Container(
              width: 144,
              height: 144,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TwoBeeColors.surfaceTonal,
                border: Border.all(color: TwoBeeColors.primary, width: 3),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.radar_rounded, color: TwoBeeColors.primary, size: 44),
                  const SizedBox(height: 4),
                  Text('${_secondsLeft}s', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: TwoBeeColors.primary)),
                  const Text('< 45s match', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: TwoBeeColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Searching Nearest 2Bee EV Riders...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              t != null ? '${t['pickupAddress']} → ${t['dropoffAddress']}' : 'Dispatching to Banani/Gulshan hub...',
              textAlign: TextAlign.center,
              style: const TextStyle(color: TwoBeeColors.textSecondary),
            ),
            if (t != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: TwoBeeColors.surfaceTonal, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  'Fixed Price Guarantee · ${bdt(t['totalFareBdt'] as num)} (${t['paymentMethod']})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: TwoBeeColors.primary),
                ),
              ),
            ],
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: TwoBeeColors.obsidian),
              onPressed: _simulateMatch,
              icon: const Icon(Icons.fast_forward_rounded),
              label: const Text('Preview: Simulate Rider Accepts ->'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _cancel,
              child: Text('Cancel Request (${_secondsLeft}s)'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ride 4: Active Trip & Driver En-Route (Isolated from Multi-Service!)
class RideActiveTripScreen extends ConsumerStatefulWidget {
  final String tripId;
  const RideActiveTripScreen({super.key, required this.tripId});

  @override
  ConsumerState<RideActiveTripScreen> createState() => _RideActiveTripScreenState();
}

class _RideActiveTripScreenState extends ConsumerState<RideActiveTripScreen> {
  Map<String, dynamic>? _trip;
  double? _riderLat;
  double? _riderLng;
  bool _loading = true;
  int _elapsedSeconds = 0;
  Timer? _waitTimer;
  bool _cancellingDriver = false;

  @override
  void initState() {
    super.initState();
    _load();
    _startWaitTimer();
    final sock = ref.read(socketServiceProvider);
    sock.joinTracking('ride', widget.tripId);
    sock.socket?.off('ride:status');
    sock.socket?.on('ride:status', (_) => _load());
    sock.socket?.off('tracking:location');
    sock.socket?.on('tracking:location', (loc) {
      if (mounted && loc is Map && loc['orderId'] == widget.tripId) {
        setState(() {
          _riderLat = (loc['lat'] as num).toDouble();
          _riderLng = (loc['lng'] as num).toDouble();
        });
      }
    });
  }

  @override
  void dispose() {
    _waitTimer?.cancel();
    super.dispose();
  }

  void _startWaitTimer() {
    _waitTimer?.cancel();
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_trip?['status'] == 'RIDER_ASSIGNED') {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  String _formatWaitTimer(int totalSecs) {
    final mins = (totalSecs ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSecs % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiClientProvider).get('/rides/${widget.tripId}');
      final t = Map<String, dynamic>.from(res['trip'] as Map);
      if (!mounted) return;
      if (t['status'] == 'MATCHING') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => RideMatchingRadarScreen(tripId: widget.tripId)),
        );
        return;
      }
      final assignedAt = DateTime.tryParse(t['updatedAt']?.toString() ?? '');
      if (assignedAt != null && t['status'] == 'RIDER_ASSIGNED') {
        final diff = DateTime.now().difference(assignedAt).inSeconds;
        if (diff > _elapsedSeconds) {
          _elapsedSeconds = diff;
        }
      }
      setState(() {
        _trip = t;
        _riderLat ??= (_trip?['driver']?['lat'] as num?)?.toDouble();
        _riderLng ??= (_trip?['driver']?['lng'] as num?)?.toDouble();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel() async {
    await ref.read(apiClientProvider).post('/rides/${widget.tripId}/cancel');
    await _load();
  }

  Future<void> _showCancelDelayedDriverSheet() async {
    final reasons = [
      'Driver delayed / taking too long to reach pickup',
      'Driver is not moving / stuck in traffic',
      'Driver asked me to cancel',
      'Driver heading in wrong direction',
      'Selected wrong pickup location',
      'Other reason',
    ];
    String selected = reasons[0];

    final confirmed = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Reason for Cancellation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select why you are cancelling this rider. We will unassign this driver and return to radar to find a closer 2Bee rider.',
                  style: TextStyle(fontSize: 12, color: TwoBeeColors.textSecondary),
                ),
                const SizedBox(height: 14),
                RadioGroup<String>(
                  groupValue: selected,
                  onChanged: (v) {
                    if (v != null) setModalState(() => selected = v);
                  },
                  child: Column(
                    children: reasons
                        .map((r) => RadioListTile<String>(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              value: r,
                              title: Text(r, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Keep Waiting'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TwoBeeColors.errorText,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(ctx, selected),
                        child: const Text('Confirm & Find Rider'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed == null || !mounted) return;

    setState(() => _cancellingDriver = true);
    try {
      await ref.read(apiClientProvider).post(
        '/rides/${widget.tripId}/cancel-delayed-driver',
        body: {'reason': confirmed},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rider unassigned ($confirmed). Searching for a new 2Bee rider...'),
          backgroundColor: TwoBeeColors.primary,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => RideMatchingRadarScreen(tripId: widget.tripId)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not re-match rider: $e'), backgroundColor: TwoBeeColors.errorText),
        );
      }
    } finally {
      if (mounted) setState(() => _cancellingDriver = false);
    }
  }

  Future<void> _advanceDemo() async {
    await ref.read(apiClientProvider).post('/common/demo/advance-ride/${widget.tripId}');
    await _load();
  }

  Future<void> _openCompletion() async {
    if (_trip == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RideCompletionRatingScreen(trip: _trip!)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _trip == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final t = _trip!;
    final driver = t['driver'] as Map?;
    final status = t['status'] as String;
    final phaseText = status == 'RIDER_ASSIGNED'
        ? 'Driver En-Route to Pickup'
        : status == 'ARRIVED_PICKUP'
            ? 'Driver Arrived · Share Start PIN'
            : status == 'ON_TRIP'
                ? 'Trip In Progress -> Destination'
                : status;

    return Scaffold(
      appBar: AppBar(
        title: Text('Ride ${t['tripCode']}'),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: TwoBeeColors.errorBg, borderRadius: BorderRadius.circular(20)),
            child: TextButton.icon(
              onPressed: () => showSosSafetySheet(context, ref, role: 'CLIENT', orderId: widget.tripId),
              icon: const Icon(Icons.emergency_rounded, color: TwoBeeColors.errorText, size: 16),
              label: const Text('SOS', style: TextStyle(color: TwoBeeColors.errorText, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ),
          const TwoBeeHomeAction(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: TwoBeeColors.obsidian, borderRadius: BorderRadius.circular(20)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: TwoBeeColors.primarySoft, size: 8),
                      SizedBox(width: 6),
                      Text('LIVE TELEMETRY', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.7)),
                    ],
                  ),
                ),
                const Spacer(),
                Text(phaseText, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: TwoBeeColors.primary)),
              ],
            ),
            const SizedBox(height: 8),
            TwoBeeMapPreview(
              pickupLat: (t['pickupLat'] as num).toDouble(),
              pickupLng: (t['pickupLng'] as num).toDouble(),
              dropoffLat: (t['dropoffLat'] as num).toDouble(),
              dropoffLng: (t['dropoffLng'] as num).toDouble(),
              riderLat: _riderLat,
              riderLng: _riderLng,
              height: 205,
            ),
            const SizedBox(height: 14),
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
                        const Text('START TRIP PIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.7, color: TwoBeeColors.primary)),
                        PinDigitsRow(pin: t['startPin'].toString()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('LIVE ITINERARY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.7, color: TwoBeeColors.textSecondary)),
                    const SizedBox(height: 6),
                    Text('1. Rider En-Route · ${status == 'RIDER_ASSIGNED' ? 'Active' : 'Done'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    Text('2. Pickup at ${t['pickupAddress']} · ${status == 'ARRIVED_PICKUP' ? 'Waiting PIN' : (status == 'ON_TRIP' || status == 'COMPLETED' ? 'Boarded' : 'Next')}', style: const TextStyle(fontSize: 12)),
                    Text('3. Dropoff at ${t['dropoffAddress']} · ${status == 'COMPLETED' ? 'Arrived' : (status == 'ON_TRIP' ? 'In Transit' : 'Pending')}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (driver != null)
              Card(
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: TwoBeeColors.surfaceTonal, child: Icon(Icons.two_wheeler_rounded, color: TwoBeeColors.primary)),
                  title: Text('${driver['name']} · ★${driver['rating']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${driver['vehicle']} · ${driver['plateNo']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.chat_outlined, color: TwoBeeColors.primary),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InAppChatScreen(
                          serviceType: 'RIDE',
                          orderId: widget.tripId,
                          peerTitle: driver['name'] as String,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else if (status == 'MATCHING')
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 10),
                      const Text('Matching nearest 2Bee rider...', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      OutlinedButton(onPressed: _cancel, child: const Text('Cancel Request')),
                    ],
                  ),
                ),
              ),
            if (status == 'RIDER_ASSIGNED') ...[
              const SizedBox(height: 10),
              if (_elapsedSeconds < 600)
                Card(
                  color: TwoBeeColors.surfaceTonal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: TwoBeeColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, color: TwoBeeColors.primary, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Driver En-Route · Waiting ${_formatWaitTimer(_elapsedSeconds)} / 10:00 mins',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: TwoBeeColors.primary),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'If driver does not arrive within 10 min, cancellation button unlocks to find a new rider.',
                                style: TextStyle(fontSize: 11, color: TwoBeeColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _elapsedSeconds = 601),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Simulate 10m', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Card(
                  color: TwoBeeColors.warningBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: TwoBeeColors.warningBorder),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: TwoBeeColors.warningText, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Driver Delayed (> 10 mins elapsed)',
                              style: TextStyle(fontWeight: FontWeight.w800, color: TwoBeeColors.warningText, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Driver has not reached your pickup location within 10 minutes (${_formatWaitTimer(_elapsedSeconds)} elapsed). You can cancel this rider and search for a new 2Bee rider.',
                          style: const TextStyle(fontSize: 12, color: TwoBeeColors.obsidian),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TwoBeeColors.errorText,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _cancellingDriver ? null : _showCancelDelayedDriverSheet,
                            icon: const Icon(Icons.person_off_rounded),
                            label: Text(_cancellingDriver ? 'Cancelling...' : 'Cancel Delayed Rider & Find New Rider'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Live trip link copied: https://2bee.app/ride/${t['tripCode']}')),
              ),
              icon: const Icon(Icons.share_location_rounded),
              label: const Text('Share Live Trip Link'),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Fare Breakdown', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Base + Distance'), Text(bdt(t['totalFareBdt'] as num))]),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Payment'), Text('${t['paymentMethod']} (${t['paymentStatus']})')]),
                  ],
                ),
              ),
            ),
            if (status != 'COMPLETED' && status != 'CANCELLED') ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: TwoBeeColors.obsidian),
                onPressed: _advanceDemo,
                icon: const Icon(Icons.fast_forward_rounded),
                label: const Text('Preview: Simulate Next Trip Phase ->'),
              ),
            ],
            if (status == 'COMPLETED') ...[
              const SizedBox(height: 14),
              ElevatedButton(onPressed: _openCompletion, child: const Text('Trip Summary, Invoice & Rating ->')),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ride 5: Trip Completion & Fare Rating
class RideCompletionRatingScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> trip;
  const RideCompletionRatingScreen({super.key, required this.trip});

  @override
  ConsumerState<RideCompletionRatingScreen> createState() => _RideCompletionRatingScreenState();
}

class _RideCompletionRatingScreenState extends ConsumerState<RideCompletionRatingScreen> {
  int _stars = 5;
  num _tip = 20;
  final _tags = <String>{'Safe Ride', 'Clean Helmet'};
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final alreadyRated = t['rating'] != null;
    final distKm = (t['distanceKm'] as num?) ?? 5.4;

    return Scaffold(
      appBar: AppBar(title: const Text('5. Trip Completion & Rating'), actions: const [TwoBeeHomeAction()]),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: TwoBeeColors.obsidian, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                const Text('DESTINATION REACHED · ZERO-EMISSION', style: TextStyle(color: TwoBeeColors.primarySoft, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.6)),
                const SizedBox(height: 4),
                Text(bdt(t['totalFareBdt'] as num), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text('${distKm.toStringAsFixed(1)} km · +25 2Bee EcoPoints earned', style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Invoice · ${t['tripCode']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      TextButton.icon(
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('PDF Invoice ready for ${t['tripCode']}')),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Download Invoice'),
                      ),
                    ],
                  ),
                  const Divider(),
                  Text('From: ${t['pickupAddress']}'),
                  Text('To: ${t['dropoffAddress']}'),
                  Text('Fleet Tier: ${t['fleetTier']} · ${t['paymentMethod']}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (!alreadyRated) ...[
            const Text('Rate Your 2Bee Rider', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (i) => IconButton(
                  onPressed: () => setState(() => _stars = i + 1),
                  icon: Icon(i < _stars ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber, size: 34),
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['Safe Ride', 'Clean Helmet', 'On Time', 'Polite'].map((tag) {
                return FilterChip(
                  label: Text(tag),
                  selected: _tags.contains(tag),
                  onSelected: (v) => setState(() => v ? _tags.add(tag) : _tags.remove(tag)),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            const Text('Optional Driver Tip', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [0, 20, 50, 100]
                  .map((amt) => ChoiceChip(label: Text(amt == 0 ? 'No tip' : bdt(amt)), selected: _tip == amt, onSelected: (_) => setState(() => _tip = amt)))
                  .toList(),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _saving
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      await ref.read(apiClientProvider).post('/rides/${t['id']}/rate', body: {
                        'rating': _stars,
                        'tipBdt': _tip,
                        'comment': _tags.join(', '),
                      });
                      if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst);
                    },
              child: Text(_saving ? 'Submitting...' : 'Submit Rating & Done'),
            ),
          ] else
            Card(
              color: TwoBeeColors.surfaceTonal,
              child: ListTile(
                leading: const Icon(Icons.star_rounded, color: Colors.amber),
                title: Text('Rated ${t['rating']}/5 Stars · Tip ${bdt(t['tipBdt'] ?? 0)}'),
              ),
            ),
        ],
      ),
    );
  }
}

