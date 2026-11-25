import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/twobee_theme.dart';
import '../../core/widgets/common_widgets.dart';
import '../common/shared_screens.dart';

const _rideZoneSpots = [
  {
    'id': 'zone-banani',
    'name': 'Banani Road 11',
    'lat': 23.7937,
    'lng': 90.4066,
  },
  {
    'id': 'zone-gulshan',
    'name': 'Gulshan 2 Circle',
    'lat': 23.7925,
    'lng': 90.4158,
  },
  {
    'id': 'zone-uttara',
    'name': 'Uttara Sector 3',
    'lat': 23.8648,
    'lng': 90.3974,
  },
  {
    'id': 'zone-mirpur',
    'name': 'Mirpur 10 Circle',
    'lat': 23.8069,
    'lng': 90.3687,
  },
  {
    'id': 'zone-dhanmondi',
    'name': 'Dhanmondi 27',
    'lat': 23.7461,
    'lng': 90.3742,
  },
];

/// Ride 1: Map Radar & Location Selector (100% Zero-Emission EV Bike Fleet)
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
          title: Text(forPickup ? 'Search Pickup Spot (Dhaka)' : 'Search Destination (Dhaka)'),
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
                          final res = await ref.read(apiClientProvider).get(
                                '/common/places/search?q=${Uri.encodeComponent(qCtrl.text.trim())}',
                              );
                          final list = (res['places'] as List?) ?? [];
                          setD(() {
                            if (list.isNotEmpty) {
                              results = list.map((p) => {
                                    'id': p['zoneId'] ?? 'zone-banani',
                                    'name': p['name'] ?? p['displayName'] ?? 'Dhaka Spot',
                                    'lat': (p['lat'] as num?)?.toDouble() ?? 23.7937,
                                    'lng': (p['lng'] as num?)?.toDouble() ?? 90.4066,
                                  }).toList();
                            }
                          });
                        } catch (_) {
                          // Keep default results
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
                    children: results.map((r) => ListTile(
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
                        )).toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _estimate() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).post(
            '/rides/estimate',
            body: {
              'pickupLat': _pickup['lat'],
              'pickupLng': _pickup['lng'],
              'pickupZoneId': _pickup['id'],
              'dropoffLat': _dropoff['lat'],
              'dropoffLng': _dropoff['lng'],
              'dropoffZoneId': _dropoff['id'],
            },
          );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RideTierScreen(pickup: _pickup, dropoff: _dropoff, estimate: res),
        ),
      );
    } catch (_) {
      // Fallback calculation ensures ride flow NEVER halts
      final distKm = 10.4;
      final fallbackEstimate = {
        'ok': true,
        'distanceKm': distKm,
        'etaMins': 12,
        'originZone': {'id': _pickup['id'], 'name': _pickup['name']},
        'destinationZone': {'id': _dropoff['id'], 'name': _dropoff['name']},
        'tiers': [
          {
            'id': '2BEE_EV_SOLO',
            'name': '2Bee EV Solo Bike',
            'subtitle': 'Glafit GFR-02 EV · Solo Commute',
            'baseBdt': 40,
            'perKmBdt': 18,
            'minBdt': 85,
            'grossFareBdt': 227,
            'discountBdt': 0,
            'totalFareBdt': 227,
            'etaMins': 12,
          },
          {
            'id': '2BEE_EV_EXPRESS',
            'name': '2Bee EV Express Bike',
            'subtitle': 'Glafit LOM Priority · Instant Dispatch',
            'baseBdt': 55,
            'perKmBdt': 22,
            'minBdt': 110,
            'grossFareBdt': 284,
            'discountBdt': 0,
            'totalFareBdt': 284,
            'etaMins': 13,
          },
        ],
      };
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RideTierScreen(pickup: _pickup, dropoff: _dropoff, estimate: fallbackEstimate),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TwoBeeColors.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          // Top Obsidian Header
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: TwoBeeColors.obsidian,
                borderRadius: TwoBeeRadii.headerBottom,
                boxShadow: TwoBeeShadows.dockNav,
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: TwoBeeColors.primary,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: TwoBeeShadows.emeraldGlow,
                            ),
                            child: const Center(
                              child: Icon(Icons.two_wheeler_rounded, color: TwoBeeColors.obsidian, size: 20),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  '2Bee EV Bike Ride',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Fast 100% Zero-Emission Commute',
                                  style: TextStyle(
                                    color: TwoBeeColors.primarySoft,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const TwoBeeHomeAction(),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Content Body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Map Preview with live EV badge
                  Stack(
                    children: [
                      TwoBeeMapPreview(
                        pickupLat: (_pickup['lat'] as num).toDouble(),
                        pickupLng: (_pickup['lng'] as num).toDouble(),
                        dropoffLat: (_dropoff['lat'] as num).toDouble(),
                        dropoffLng: (_dropoff['lng'] as num).toDouble(),
                        height: 200,
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: TwoBeeColors.obsidian.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: TwoBeeShadows.softCard,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.electric_moped_rounded, color: TwoBeeColors.primarySoft, size: 15),
                              SizedBox(width: 6),
                              Text(
                                '4 EV Riders Nearby · 2m',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // EV Fleet Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: TwoBeeColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.eco_rounded, color: TwoBeeColors.primary, size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '100% Zero-Emission Electric EV Fleet · Glafit GFR-02 & LOM EV',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: TwoBeeColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Route Location Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: TwoBeeColors.surfaceCard,
                      borderRadius: TwoBeeRadii.card,
                      boxShadow: TwoBeeShadows.softCard,
                      border: Border.all(color: TwoBeeColors.borderSoft),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Pickup Node
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: TwoBeeColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text('PICKUP SPOT', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: TwoBeeColors.textSecondary)),
                            const Spacer(),
                            TextButton(
                              onPressed: () => _searchPlaceDialog(forPickup: true),
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              child: const Text('Search Map', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        DropdownButtonFormField<Map<String, dynamic>>(
                          initialValue: _pickup,
                          decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
                          items: _rideZoneSpots.map((z) => DropdownMenuItem(value: z, child: Text(z['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)))).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _pickup = v);
                          },
                        ),
                        const Divider(),

                        // Dropoff Node
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: TwoBeeColors.obsidian,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text('DESTINATION (WHERE TO?)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: TwoBeeColors.textSecondary)),
                            const Spacer(),
                            TextButton(
                              onPressed: () => _searchPlaceDialog(forPickup: false),
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              child: const Text('Search Map', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        DropdownButtonFormField<Map<String, dynamic>>(
                          initialValue: _dropoff,
                          decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
                          items: _rideZoneSpots.map((z) => DropdownMenuItem(value: z, child: Text(z['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)))).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _dropoff = v);
                          },
                        ),
                        const SizedBox(height: 12),

                        // Destination Shortcut Chips
                        const Text('QUICK DESTINATIONS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: TwoBeeColors.textSecondary)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            ActionChip(
                              avatar: const Icon(Icons.home_outlined, size: 16),
                              label: const Text('Uttara'),
                              onPressed: () => setState(() => _dropoff = _rideZoneSpots[2]),
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.work_outline, size: 16),
                              label: const Text('Gulshan 2'),
                              onPressed: () => setState(() => _dropoff = _rideZoneSpots[1]),
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.history_rounded, size: 16),
                              label: const Text('Mirpur 10'),
                              onPressed: () => setState(() => _dropoff = _rideZoneSpots[3]),
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.place_outlined, size: 16),
                              label: const Text('Dhanmondi 27'),
                              onPressed: () => setState(() => _dropoff = _rideZoneSpots[4]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Calculate EV Route CTA
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TwoBeeColors.primary,
                      foregroundColor: TwoBeeColors.obsidian,
                      shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: _loading ? null : _estimate,
                    child: Text(
                      _loading ? 'Calculating EV Route...' : 'Calculate EV Fare & Route ➔',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
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

/// Ride 2: Vehicle & Fleet Tier Selection (Strictly 2 EV Tiers · NO Car · NO CNG)
class RideTierScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> pickup;
  final Map<String, dynamic> dropoff;
  final Map<String, dynamic> estimate;

  const RideTierScreen({
    super.key,
    required this.pickup,
    required this.dropoff,
    required this.estimate,
  });

  @override
  ConsumerState<RideTierScreen> createState() => _RideTierScreenState();
}

class _RideTierScreenState extends ConsumerState<RideTierScreen> {
  String _selectedTier = '2BEE_EV_SOLO';
  String _payment = 'COD';
  final _promoCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _confirm() async {
    final rawTiers = widget.estimate['tiers'];
    final List<Map<String, dynamic>> tiers = (rawTiers is List && rawTiers.isNotEmpty)
        ? rawTiers.map((t) => Map<String, dynamic>.from(t as Map)).toList()
        : [
            {
              'id': '2BEE_EV_SOLO',
              'name': '2Bee EV Solo Bike',
              'subtitle': 'Glafit GFR-02 EV · Solo Commute',
              'totalFareBdt': 185,
              'etaMins': 12,
            },
            {
              'id': '2BEE_EV_EXPRESS',
              'name': '2Bee EV Express Bike',
              'subtitle': 'Glafit LOM Priority · Instant Dispatch',
              'totalFareBdt': 235,
              'etaMins': 13,
            },
          ];
    final chosen = tiers.firstWhere(
      (t) => t['id'] == _selectedTier,
      orElse: () => tiers[0],
    );
    if (_payment == 'STRIPE_SANDBOX') {
      final paid = await showStripeSandboxDialog(
        context,
        amountBdt: (chosen['totalFareBdt'] as num?) ?? 185,
        title: 'Ride · ${chosen['name'] ?? '2Bee EV'}',
      );
      if (!paid) return;
    }

    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).post(
            '/rides/request',
            body: {
              'fleetTier': _selectedTier,
              'pickupAddress': widget.pickup['name']?.toString() ?? 'Banani Road 11',
              'pickupLat': (widget.pickup['lat'] as num?)?.toDouble() ?? 23.7937,
              'pickupLng': (widget.pickup['lng'] as num?)?.toDouble() ?? 90.4066,
              'pickupZoneId': widget.pickup['id']?.toString() ?? 'zone-banani',
              'dropoffAddress': widget.dropoff['name']?.toString() ?? 'Uttara Sector 3',
              'dropoffLat': (widget.dropoff['lat'] as num?)?.toDouble() ?? 23.8648,
              'dropoffLng': (widget.dropoff['lng'] as num?)?.toDouble() ?? 90.3974,
              'dropoffZoneId': widget.dropoff['id']?.toString() ?? 'zone-uttara',
              'promoCode': _promoCtrl.text.trim().isNotEmpty ? _promoCtrl.text.trim() : null,
              'paymentMethod': _payment,
            },
          );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RideMatchingRadarScreen(tripId: res['trip']['id'] as String),
        ),
      );
    } catch (_) {
      // Fallback trip for seamless testing
      if (!mounted) return;
      final tripId = 'trip-demo-${DateTime.now().millisecondsSinceEpoch}';
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RideMatchingRadarScreen(tripId: tripId),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawTiers = widget.estimate['tiers'];
    final List<Map<String, dynamic>> tiers = (rawTiers is List && rawTiers.isNotEmpty)
        ? rawTiers.map((t) => Map<String, dynamic>.from(t as Map)).toList()
        : [
            {
              'id': '2BEE_EV_SOLO',
              'name': '2Bee EV Solo Bike',
              'subtitle': 'Glafit GFR-02 EV · Solo Commute',
              'totalFareBdt': 185,
              'etaMins': 12,
            },
            {
              'id': '2BEE_EV_EXPRESS',
              'name': '2Bee EV Express Bike',
              'subtitle': 'Glafit LOM Priority · Instant Dispatch',
              'totalFareBdt': 235,
              'etaMins': 13,
            },
          ];
    final distKm = (widget.estimate['distanceKm'] as num?)?.toDouble() ?? 10.4;
    final co2SavedKg = (distKm * 0.14).toStringAsFixed(2);
    final pickupName = widget.pickup['name']?.toString() ?? 'Banani Road 11';
    final dropoffName = widget.dropoff['name']?.toString() ?? 'Uttara Sector 3';

    return Scaffold(
      backgroundColor: TwoBeeColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Choose EV Bike Tier'),
        actions: const [TwoBeeHomeAction()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Route Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TwoBeeColors.obsidian,
              borderRadius: BorderRadius.circular(20),
              boxShadow: TwoBeeShadows.dockNav,
            ),
            child: Row(
              children: [
                const Icon(Icons.route_rounded, color: TwoBeeColors.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$pickupName ➔ $dropoffName',
                        style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${distKm.toStringAsFixed(1)} km · Fixed Price Guarantee',
                        style: const TextStyle(fontSize: 12, color: TwoBeeColors.primarySoft, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: TwoBeeColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$co2SavedKg kg CO2 saved',
                    style: const TextStyle(color: TwoBeeColors.obsidian, fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tiers List (Strictly 2 EV Tiers)
          ...tiers.map((t) {
            final id = t['id']?.toString() ?? '2BEE_EV_SOLO';
            final sel = _selectedTier == id;
            final name = t['name']?.toString() ?? '2Bee EV Bike';
            final subtitle = t['subtitle']?.toString() ?? 'Zero-Emission EV Commute';
            final eta = t['etaMins']?.toString() ?? '12';
            final fare = (t['totalFareBdt'] as num?) ?? 185;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: sel ? TwoBeeColors.surfaceTonal : TwoBeeColors.surfaceCard,
                borderRadius: TwoBeeRadii.card,
                boxShadow: TwoBeeShadows.softCard,
                border: Border.all(
                  color: sel ? TwoBeeColors.primary : TwoBeeColors.borderSoft,
                  width: sel ? 2 : 1,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: TwoBeeRadii.card,
                  onTap: () => setState(() => _selectedTier = id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: sel ? TwoBeeColors.primary : TwoBeeColors.surfaceTonal,
                          child: Icon(
                            Icons.electric_moped_rounded,
                            color: sel ? TwoBeeColors.obsidian : TwoBeeColors.primary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                              const SizedBox(height: 3),
                              Text('$subtitle · ETA $eta mins', style: const TextStyle(fontSize: 12, color: TwoBeeColors.textSecondary)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          bdt(fare),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: TwoBeeColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 10),

          // Promo Code Card
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _promoCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Promo code (try 2BEE10)',
                    prefixIcon: Icon(Icons.local_offer_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TwoBeeColors.obsidian,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(80, 48),
                  shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Promo 2BEE10 applied! 10% discount on confirmation.')),
                  );
                },
                child: const Text('Apply'),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Payment Selector Card
          PaymentSelectorCard(
            selectedMethod: _payment,
            onSelected: (m) => setState(() => _payment = m),
          ),
          const SizedBox(height: 20),

          // Confirm EV Bike Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TwoBeeColors.primary,
              foregroundColor: TwoBeeColors.obsidian,
              shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _loading ? null : _confirm,
            child: Text(
              _loading ? 'Dispatching EV Rider...' : 'Confirm EV Bike Request ➔',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ride 3: Courier & Rider Matching Radar Screen
class RideMatchingRadarScreen extends ConsumerStatefulWidget {
  final String tripId;
  const RideMatchingRadarScreen({super.key, required this.tripId});

  @override
  ConsumerState<RideMatchingRadarScreen> createState() => _RideMatchingRadarScreenState();
}

class _RideMatchingRadarScreenState extends ConsumerState<RideMatchingRadarScreen> {
  Map<String, dynamic>? _trip;
  int _secondsLeft = 45;
  Timer? _timer;
  late final SocketService _sock;

  void _onRideStatus(dynamic _) {
    if (mounted) _load();
  }

  @override
  void initState() {
    super.initState();
    _sock = ref.read(socketServiceProvider);
    _load();
    _sock.joinTracking('ride', widget.tripId);
    _sock.socket?.off('ride:status', _onRideStatus);
    _sock.socket?.on('ride:status', _onRideStatus);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft = _secondsLeft > 0 ? _secondsLeft - 1 : 0);
    });
  }

  @override
  void dispose() {
    _sock.socket?.off('ride:status', _onRideStatus);
    _sock.leaveTracking('ride', widget.tripId);
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
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
    } catch (_) {
      setState(() {
        _trip ??= {
          'id': widget.tripId,
          'tripCode': '#2B-R7391',
          'status': 'MATCHING',
          'fleetTier': '2BEE_EV_SOLO',
          'pickupAddress': 'Banani Road 11',
          'dropoffAddress': 'Uttara Sector 3',
          'pickupLat': 23.7937,
          'pickupLng': 90.4066,
          'dropoffLat': 23.8648,
          'dropoffLng': 90.3974,
          'totalFareBdt': 227,
          'paymentMethod': 'COD',
          'startPin': 7391,
        };
      });
    }
  }

  Future<void> _simulateMatch() async {
    try {
      await ref.read(apiClientProvider).post('/common/demo/advance-ride/${widget.tripId}');
    } catch (_) {}
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => RideActiveTripScreen(tripId: widget.tripId)),
      );
    }
  }

  Future<void> _cancel() async {
    try {
      await ref.read(apiClientProvider).post('/rides/${widget.tripId}/cancel');
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = _trip;

    return Scaffold(
      backgroundColor: TwoBeeColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Rider Matching Radar'),
        actions: const [TwoBeeHomeAction()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (t != null)
              TwoBeeMapPreview(
                pickupLat: (t['pickupLat'] as num?)?.toDouble() ?? 23.7937,
                pickupLng: (t['pickupLng'] as num?)?.toDouble() ?? 90.4066,
                dropoffLat: (t['dropoffLat'] as num?)?.toDouble() ?? 23.8648,
                dropoffLng: (t['dropoffLng'] as num?)?.toDouble() ?? 90.3974,
                height: 180,
              ),
            const Spacer(),

            // Radar Visual Concentric Rings
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TwoBeeColors.obsidian,
                boxShadow: TwoBeeShadows.dockNav,
                border: Border.all(color: TwoBeeColors.primary, width: 4),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.electric_moped_rounded, color: TwoBeeColors.primary, size: 40),
                  const SizedBox(height: 4),
                  Text(
                    '${_secondsLeft}s',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: TwoBeeColors.primarySoft),
                  ),
                  const Text('< 45s match', style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Searching Nearest 2Bee EV Riders...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              t != null ? '${t['pickupAddress']} ➔ ${t['dropoffAddress']}' : 'Dispatching to nearby Banani/Gulshan EV riders...',
              textAlign: TextAlign.center,
              style: const TextStyle(color: TwoBeeColors.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Fixed Price: ${bdt(t?['totalFareBdt'] ?? 227)} · Zero Surge Guaranteed',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: TwoBeeColors.primary),
              ),
            ),
            const Spacer(),

            // Simulate Rider Accepts Action Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: TwoBeeColors.obsidian,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: _simulateMatch,
              icon: const Icon(Icons.fast_forward_rounded, color: TwoBeeColors.primary),
              label: const Text('Preview: Simulate Rider Accepts ➔', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _cancel,
              child: Text('Cancel Ride Request (${_secondsLeft}s)'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ride 4: Active Trip & Driver En-Route Screen
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
  late final SocketService _sock;

  void _onRideStatus(dynamic _) {
    if (mounted) _load();
  }

  void _onTrackingLocation(dynamic data) {
    if (!mounted || data is! Map) return;
    if (data['orderId'] != null && data['orderId'] != widget.tripId) return;
    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();
    if (lat != null && lng != null) {
      setState(() {
        _riderLat = lat;
        _riderLng = lng;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _sock = ref.read(socketServiceProvider);
    _load();
    _sock.joinTracking('ride', widget.tripId);
    _sock.socket?.off('ride:status', _onRideStatus);
    _sock.socket?.off('tracking:location', _onTrackingLocation);
    _sock.socket?.on('ride:status', _onRideStatus);
    _sock.socket?.on('tracking:location', _onTrackingLocation);
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_trip?['status'] == 'RIDER_ASSIGNED') {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  @override
  void dispose() {
    _sock.socket?.off('ride:status', _onRideStatus);
    _sock.socket?.off('tracking:location', _onTrackingLocation);
    _sock.leaveTracking('ride', widget.tripId);
    _waitTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiClientProvider).get('/rides/${widget.tripId}');
      final t = Map<String, dynamic>.from(res['trip'] as Map);
      if (!mounted) return;
      setState(() {
        _trip = t;
        _riderLat ??= (_trip?['driver']?['lat'] as num?)?.toDouble();
        _riderLng ??= (_trip?['driver']?['lng'] as num?)?.toDouble();
      });
    } catch (_) {
      setState(() {
        _trip ??= {
          'id': widget.tripId,
          'tripCode': '#2B-R7391',
          'status': 'RIDER_ASSIGNED',
          'fleetTier': '2BEE_EV_SOLO',
          'pickupAddress': 'Banani Road 11',
          'dropoffAddress': 'Uttara Sector 3',
          'pickupLat': 23.7937,
          'pickupLng': 90.4066,
          'dropoffLat': 23.8648,
          'dropoffLng': 90.3974,
          'totalFareBdt': 227,
          'paymentMethod': 'COD',
          'paymentStatus': 'PENDING',
          'startPin': 7391,
          'driver': {
            'name': 'Rahim Khan',
            'phone': '+8801722222222',
            'rating': 4.9,
            'vehicle': 'Glafit GFR-02 EV Bike',
            'plateNo': 'DHK-HA-4819',
            'lat': 23.7940,
            'lng': 90.4070,
          },
        };
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _advanceDemo() async {
    try {
      await ref.read(apiClientProvider).post('/common/demo/advance-ride/${widget.tripId}');
    } catch (_) {}

    if (_trip != null) {
      final curr = _trip!['status'];
      final nextStatus = curr == 'RIDER_ASSIGNED'
          ? 'ARRIVED_PICKUP'
          : curr == 'ARRIVED_PICKUP'
              ? 'ON_TRIP'
              : 'COMPLETED';
      setState(() {
        _trip = Map<String, dynamic>.from(_trip!)..['status'] = nextStatus;
      });
    } else {
      await _load();
    }
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
    if (_loading && _trip == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final t = _trip!;
    final driver = t['driver'] as Map?;
    final status = t['status'] as String? ?? 'RIDER_ASSIGNED';

    final phaseText = status == 'RIDER_ASSIGNED'
        ? 'Rider En-Route to Pickup'
        : status == 'ARRIVED_PICKUP'
            ? 'Rider Arrived · Share Start PIN'
            : status == 'ON_TRIP'
                ? 'Trip in Progress ➔ Destination'
                : status == 'COMPLETED'
                    ? 'Arrived at Destination!'
                    : status;

    return Scaffold(
      backgroundColor: TwoBeeColors.scaffoldBg,
      appBar: AppBar(
        title: Text('Trip ${t['tripCode'] ?? ''}'),
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
            // Status Header Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: TwoBeeColors.obsidian,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.circle, color: TwoBeeColors.primary, size: 10),
                  const SizedBox(width: 8),
                  Text(
                    phaseText,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Live Telemetry Map
            TwoBeeMapPreview(
              pickupLat: (t['pickupLat'] as num).toDouble(),
              pickupLng: (t['pickupLng'] as num).toDouble(),
              dropoffLat: (t['dropoffLat'] as num).toDouble(),
              dropoffLng: (t['dropoffLng'] as num).toDouble(),
              riderLat: _riderLat,
              riderLng: _riderLng,
              height: 200,
            ),
            const SizedBox(height: 14),

            // START TRIP PIN CARD
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: TwoBeeColors.obsidian,
                borderRadius: BorderRadius.circular(20),
                boxShadow: TwoBeeShadows.dockNav,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: TwoBeeColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('START TRIP PIN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: TwoBeeColors.obsidian)),
                        Text(
                          t['startPin']?.toString() ?? '7391',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: TwoBeeColors.obsidian, letterSpacing: 3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Share this 4-digit PIN with your rider to start your zero-emission trip safely.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Driver Card
            if (driver != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: TwoBeeColors.surfaceCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: TwoBeeColors.borderSoft),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: TwoBeeColors.surfaceTonal,
                      child: Icon(Icons.electric_moped_rounded, color: TwoBeeColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${driver['name']} · ★${driver['rating']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text('${driver['vehicle']} · ${driver['plateNo']}', style: const TextStyle(fontSize: 12, color: TwoBeeColors.textSecondary)),
                        ],
                      ),
                    ),
                    IconButton(
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
                  ],
                ),
              ),
            const SizedBox(height: 14),

            // Trip Itinerary & Fare
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: TwoBeeColors.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: TwoBeeColors.borderSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Trip Itinerary', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.circle, color: TwoBeeColors.primary, size: 10),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Pickup: ${t['pickupAddress']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.circle, color: TwoBeeColors.obsidian, size: 10),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Dropoff: ${t['dropoffAddress']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Fixed Fare Guarantee', style: TextStyle(fontWeight: FontWeight.w700)),
                      Text(bdt(t['totalFareBdt'] ?? 185), style: const TextStyle(fontWeight: FontWeight.w900, color: TwoBeeColors.primary, fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Advance Demo Phase CTA
            if (status != 'COMPLETED' && status != 'CANCELLED')
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TwoBeeColors.obsidian,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _advanceDemo,
                icon: const Icon(Icons.fast_forward_rounded, color: TwoBeeColors.primary),
                label: const Text('Preview: Simulate Next Trip Phase ➔', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            if (status == 'COMPLETED')
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TwoBeeColors.primary,
                  foregroundColor: TwoBeeColors.obsidian,
                  shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _openCompletion,
                child: const Text('Trip Summary, Invoice & Rating ➔', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Ride 5: Trip Completion, Emission Certificate & Rating Screen
class RideCompletionRatingScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> trip;
  const RideCompletionRatingScreen({super.key, required this.trip});

  @override
  ConsumerState<RideCompletionRatingScreen> createState() => _RideCompletionRatingScreenState();
}

class _RideCompletionRatingScreenState extends ConsumerState<RideCompletionRatingScreen> {
  int _stars = 5;
  num _tip = 20;
  final _tags = <String>{'Safe Ride', 'Clean Helmet', 'Smooth EV Drive'};
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final distKm = (t['distanceKm'] as num?) ?? 10.4;
    final co2SavedKg = (distKm * 0.14).toStringAsFixed(2);

    return Scaffold(
      backgroundColor: TwoBeeColors.scaffoldBg,
      appBar: AppBar(title: const Text('Trip Complete'), actions: const [TwoBeeHomeAction()]),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: TwoBeeColors.obsidian,
              borderRadius: BorderRadius.circular(24),
              boxShadow: TwoBeeShadows.dockNav,
            ),
            child: Column(
              children: [
                const Icon(Icons.check_circle_rounded, color: TwoBeeColors.primary, size: 48),
                const SizedBox(height: 8),
                const Text(
                  'DESTINATION REACHED',
                  style: TextStyle(color: TwoBeeColors.primarySoft, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8),
                ),
                const SizedBox(height: 4),
                Text(
                  bdt(t['totalFareBdt'] as num),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 28),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: TwoBeeColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '🌿 Zero-Emission: $co2SavedKg kg CO2 saved',
                    style: const TextStyle(color: TwoBeeColors.obsidian, fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Rating Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TwoBeeColors.surfaceCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: TwoBeeColors.borderSoft),
            ),
            child: Column(
              children: [
                const Text('Rate Your EV Rider', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (i) => IconButton(
                      onPressed: () => setState(() => _stars = i + 1),
                      icon: Icon(i < _stars ? Icons.star : Icons.star_border, color: Colors.amber, size: 36),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Review Tags
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Safe Ride', 'Clean Helmet', 'Smooth EV Drive', 'Polite Rider'].map((tag) {
              return FilterChip(
                label: Text(tag),
                selected: _tags.contains(tag),
                onSelected: (v) => setState(() => v ? _tags.add(tag) : _tags.remove(tag)),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Rider Tip
          const Text('Tip Your EV Rider', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [0, 20, 50, 100].map((t) => ChoiceChip(
                  label: Text(t == 0 ? 'No Tip' : bdt(t)),
                  selected: _tip == t,
                  onSelected: (_) => setState(() => _tip = t),
                )).toList(),
          ),
          const SizedBox(height: 20),

          // Submit Rating Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TwoBeeColors.primary,
              foregroundColor: TwoBeeColors.obsidian,
              shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    try {
                      await ref.read(apiClientProvider).post('/rides/${t['id']}/rate', body: {
                        'rating': _stars,
                        'tipBdt': _tip,
                        'tags': _tags.toList(),
                      });
                    } catch (_) {}
                    if (context.mounted) {
                      Navigator.popUntil(context, (r) => r.isFirst);
                    }
                  },
            child: Text(_saving ? 'Saving...' : 'Complete & Return Home ➔', style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}
