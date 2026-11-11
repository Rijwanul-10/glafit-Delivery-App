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
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('2Bee Ride')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TwoBeeMapPreview(
            pickupLat: (_pickup['lat'] as num).toDouble(),
            pickupLng: (_pickup['lng'] as num).toDouble(),
            dropoffLat: (_dropoff['lat'] as num).toDouble(),
            dropoffLng: (_dropoff['lng'] as num).toDouble(),
            height: 220,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Pickup Spot', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: TwoBeeColors.textSecondary)),
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
                      const Text('Where to?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: TwoBeeColors.textSecondary)),
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
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(label: const Text('Uttara'), onPressed: () => setState(() => _dropoff = _rideZoneSpots[2])),
                      ActionChip(label: const Text('Mirpur 10'), onPressed: () => setState(() => _dropoff = _rideZoneSpots[3])),
                      ActionChip(label: const Text('Dhanmondi 27'), onPressed: () => setState(() => _dropoff = _rideZoneSpots[4])),
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
        MaterialPageRoute(builder: (_) => RideActiveTripScreen(tripId: res['trip']['id'] as String)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tiers = (widget.estimate['tiers'] as List).cast<Map<String, dynamic>>();
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Fleet Tier')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${widget.pickup['name']} → ${widget.dropoff['name']} · ${widget.estimate['distanceKm']} km',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...tiers.map((t) {
            final sel = _selectedTier == t['id'];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              color: sel ? TwoBeeColors.surfaceTonal : TwoBeeColors.surfaceCard,
              child: ListTile(
                leading: const Icon(Icons.electric_moped_rounded, color: TwoBeeColors.primary, size: 30),
                title: Text(t['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${t['subtitle']} · ${t['etaMins']}m'),
                trailing: Text(bdt(t['totalFareBdt'] as num), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: TwoBeeColors.primary)),
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

/// Ride 3 & 4 & 5: Matching Radar -> Active Trip (Isolated from Multi-Service!) -> Rating
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

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _load() async {
    try {
      final res = await ref.read(apiClientProvider).get('/rides/${widget.tripId}');
      setState(() {
        _trip = Map<String, dynamic>.from(res['trip'] as Map);
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

  Future<void> _rateDialog() async {
    int stars = 5;
    num tip = 20;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Trip Complete! Rate Your Ride', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => IconButton(
                    onPressed: () => setM(() => stars = i + 1),
                    icon: Icon(i < stars ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber, size: 34),
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                children: [0, 20, 50, 100]
                    .map((t) => ChoiceChip(label: Text(t == 0 ? 'No tip' : bdt(t)), selected: tip == t, onSelected: (_) => setM(() => tip = t)))
                    .toList(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await ref.read(apiClientProvider).post('/rides/${widget.tripId}/rate', body: {'rating': stars, 'tipBdt': tip});
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                },
                child: const Text('Submit Rating & Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _trip == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final t = _trip!;
    final driver = t['driver'] as Map?;
    final status = t['status'] as String;

    return Scaffold(
      appBar: AppBar(
        title: Text('Ride ${t['tripCode']}'),
        actions: [
          TextButton.icon(
            onPressed: () => showSosSafetySheet(context, ref, role: 'CLIENT', orderId: widget.tripId),
            icon: const Icon(Icons.emergency_rounded, color: TwoBeeColors.errorText),
            label: const Text('SOS', style: TextStyle(color: TwoBeeColors.errorText, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TwoBeeMapPreview(
              pickupLat: (t['pickupLat'] as num).toDouble(),
              pickupLng: (t['pickupLng'] as num).toDouble(),
              dropoffLat: (t['dropoffLat'] as num).toDouble(),
              dropoffLng: (t['dropoffLng'] as num).toDouble(),
              riderLat: _riderLat,
              riderLng: _riderLng,
              height: 210,
            ),
            const SizedBox(height: 14),
            Card(
              color: TwoBeeColors.surfaceTonal,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('STATUS: $status', style: const TextStyle(fontWeight: FontWeight.w800, color: TwoBeeColors.primary)),
                        Text('${t['pickupAddress']} → ${t['dropoffAddress']}', style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('START PIN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                        Text(t['startPin'].toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 3)),
                      ],
                    ),
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
                        const Text('Fare Breakdown', style: TextStyle(fontWeight: FontWeight.w700)),
                        TextButton.icon(
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text('Ride Invoice · ${t['tripCode']}'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Pickup: ${t['pickupAddress']}'),
                                  Text('Dropoff: ${t['dropoffAddress']}'),
                                  Text('Tier: ${t['fleetTier']}'),
                                  const Divider(),
                                  Text('Total Fare: ${bdt(t['totalFareBdt'] as num)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                  Text('Payment: ${t['paymentMethod']} (${t['paymentStatus']})'),
                                ],
                              ),
                              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
                            ),
                          ),
                          icon: const Icon(Icons.receipt_outlined, size: 16),
                          label: const Text('Invoice'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Base + Distance'), Text(bdt(t['totalFareBdt'] as num))]),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Payment'), Text('${t['paymentMethod']} (${t['paymentStatus']})')]),
                  ],
                ),
              ),
            ),
            if (status == 'COMPLETED' && t['rating'] == null) ...[
              const SizedBox(height: 14),
              ElevatedButton(onPressed: _rateDialog, child: const Text('Rate & Tip Driver')),
            ],
          ],
        ),
      ),
    );
  }
}

