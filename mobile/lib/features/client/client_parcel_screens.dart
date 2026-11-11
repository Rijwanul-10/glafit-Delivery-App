import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/twobee_theme.dart';
import '../../core/widgets/common_widgets.dart';
import '../common/shared_screens.dart';

const _parcelZones = [
  {'id': 'zone-banani', 'name': 'Road 11, Banani', 'lat': 23.7937, 'lng': 90.4066},
  {'id': 'zone-uttara', 'name': 'Road 13, Sector 7, Uttara', 'lat': 23.8726, 'lng': 90.3983},
  {'id': 'zone-dhanmondi', 'name': 'Dhanmondi 27, Dhaka', 'lat': 23.7529, 'lng': 90.3736},
  {'id': 'zone-gulshan', 'name': 'Gulshan 1 Avenue, Dhaka', 'lat': 23.7798, 'lng': 90.4167},
];

/// Parcel 1, 2, 3 cleanly stepped without custom bottom nav bar (relocated into Unified Activity!)
class ParcelHubScreen extends ConsumerStatefulWidget {
  const ParcelHubScreen({super.key});

  @override
  ConsumerState<ParcelHubScreen> createState() => _ParcelHubScreenState();
}

class _ParcelHubScreenState extends ConsumerState<ParcelHubScreen> {
  int _step = 0; // 0: Rate Calc, 1: Package Specs, 2: Addresses & Payment
  Map<String, dynamic> _pickup = _parcelZones[0];
  Map<String, dynamic> _dropoff = _parcelZones[1];
  String _tier = 'NORMAL_ECO'; // NORMAL_ECO | NEXT_DAY | EXPRESS
  String _sizeClass = 'MEDIUM';
  String _category = 'Electronics & Gadgets';
  double _weightKg = 2.0;
  bool _protected = false;
  final _senderName = TextEditingController(text: 'Tanvir Ahmed');
  final _senderPhone = TextEditingController(text: '+8801711111111');
  final _recipientName = TextEditingController(text: 'Farhana Yasmin');
  final _recipientPhone = TextEditingController(text: '+8801811111111');
  final _codGoodsCtrl = TextEditingController(text: '1200');
  String _payment = 'COD';
  Map<String, dynamic>? _estimate;
  bool _loading = false;

  Future<void> _fetchEstimate() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).post('/parcels/estimate', body: {
        'pickupLat': _pickup['lat'],
        'pickupLng': _pickup['lng'],
        'pickupZoneId': _pickup['id'],
        'dropoffLat': _dropoff['lat'],
        'dropoffLng': _dropoff['lng'],
        'dropoffZoneId': _dropoff['id'],
        'tier': _tier,
        'weightKg': _weightKg,
        'isProtected': _protected,
      });
      setState(() => _estimate = res);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitBooking() async {
    final total = (_estimate?['breakdown']?['deliveryChargeBdt'] as num?) ?? 95;
    if (_payment == 'STRIPE_SANDBOX') {
      final paid = await showStripeSandboxDialog(context, amountBdt: total, title: 'Parcel Delivery Charge');
      if (!paid) return;
    }
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).post('/parcels/book', body: {
        'tier': _tier,
        'packageSizeClass': _sizeClass,
        'category': _category,
        'weightKg': _weightKg,
        'isProtected': _protected,
        'senderName': _senderName.text.trim(),
        'senderPhone': _senderPhone.text.trim(),
        'pickupAddress': _pickup['name'],
        'pickupZoneId': _pickup['id'],
        'pickupLat': _pickup['lat'],
        'pickupLng': _pickup['lng'],
        'recipientName': _recipientName.text.trim(),
        'recipientPhone': _recipientPhone.text.trim(),
        'dropoffAddress': _dropoff['name'],
        'dropoffZoneId': _dropoff['id'],
        'dropoffLat': _dropoff['lat'],
        'dropoffLng': _dropoff['lng'],
        'codCollectBdt': double.tryParse(_codGoodsCtrl.text.trim()) ?? 0,
        'paymentMethod': _payment,
      });
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ParcelTrackingScreen(parcelId: res['shipment']['id'] as String)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_step == 0 ? 'Send Parcel' : _step == 1 ? 'Package Specs (1/2)' : 'Addresses & Pay (2/2)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_step == 0) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pickup Hub / Location', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    DropdownButton<Map<String, dynamic>>(
                      isExpanded: true,
                      value: _pickup,
                      items: _parcelZones.map((z) => DropdownMenuItem(value: z, child: Text(z['name'] as String))).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _pickup = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    const Text('Dropoff Location', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    DropdownButton<Map<String, dynamic>>(
                      isExpanded: true,
                      value: _dropoff,
                      items: _parcelZones.map((z) => DropdownMenuItem(value: z, child: Text(z['name'] as String))).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _dropoff = v);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Delivery Speed Tier', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _tier,
              onChanged: (v) {
                if (v != null) setState(() => _tier = v);
              },
              child: Column(
                children: [
                  ('NORMAL_ECO', 'Standard Eco (~2–12h)', 'Starts ৳60 · Normal front-carrier eligible'),
                  ('NEXT_DAY', 'Next-Day Saver', 'Starts ৳45 · Best value'),
                  ('EXPRESS', 'Express Dedicated (~45m)', 'Starts ৳110 · Dedicated urgent courier'),
                ]
                    .map((item) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: _tier == item.$1 ? TwoBeeColors.surfaceTonal : TwoBeeColors.surfaceCard,
                          child: RadioListTile<String>(
                            value: item.$1,
                            title: Text(item.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(item.$3),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await _fetchEstimate();
                if (mounted) setState(() => _step = 1);
              },
              child: const Text('Continue to Package Specs ->'),
            ),
          ] else if (_step == 1) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Category', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Documents', 'Electronics & Gadgets', 'Clothing', 'Food/Dry Goods']
                          .map((c) => ChoiceChip(label: Text(c), selected: _category == c, onSelected: (_) => setState(() => _category = c)))
                          .toList(),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Weight (kg)', style: TextStyle(fontWeight: FontWeight.w700)),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => setState(() => _weightKg = (_weightKg - 0.5).clamp(0.5, 15.0)),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text('${_weightKg.toStringAsFixed(1)} kg', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            IconButton(
                              onPressed: () => setState(() => _weightKg = (_weightKg + 0.5).clamp(0.5, 15.0)),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'DOC', label: Text('Doc')),
                        ButtonSegment(value: 'SMALL', label: Text('Small')),
                        ButtonSegment(value: 'MEDIUM', label: Text('Medium')),
                        ButtonSegment(value: 'LARGE', label: Text('Large')),
                      ],
                      selected: {_sizeClass},
                      onSelectionChanged: (v) => setState(() => _sizeClass = v.first),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('2Bee Parcel Protection (+৳15)'),
                      value: _protected,
                      onChanged: (v) => setState(() => _protected = v),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 0), child: const Text('Back'))),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await _fetchEstimate();
                      if (mounted) setState(() => _step = 2);
                    },
                    child: const Text('Next: Addresses ->'),
                  ),
                ),
              ],
            ),
          ] else ...[
            TwoBeeMapPreview(
              pickupLat: (_pickup['lat'] as num).toDouble(),
              pickupLng: (_pickup['lng'] as num).toDouble(),
              dropoffLat: (_dropoff['lat'] as num).toDouble(),
              dropoffLng: (_dropoff['lng'] as num).toDouble(),
              height: 150,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    TextField(controller: _senderName, decoration: const InputDecoration(labelText: 'Sender Name')),
                    const SizedBox(height: 8),
                    TextField(controller: _senderPhone, decoration: const InputDecoration(labelText: 'Sender Phone')),
                    const SizedBox(height: 12),
                    TextField(controller: _recipientName, decoration: const InputDecoration(labelText: 'Recipient Name')),
                    const SizedBox(height: 8),
                    TextField(controller: _recipientPhone, decoration: const InputDecoration(labelText: 'Recipient Phone')),
                    const SizedBox(height: 8),
                    TextField(controller: _codGoodsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Goods COD Collect Amount (৳, 0 if prepaid)')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            PaymentSelectorCard(selectedMethod: _payment, onSelected: (m) => setState(() => _payment = m)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 1), child: const Text('Back'))),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submitBooking,
                    child: Text(_loading
                        ? 'Dispatching...'
                        : 'Confirm · ${bdt((_estimate?['breakdown']?['deliveryChargeBdt'] as num?) ?? 95)}'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Parcel 4: Active Shipment & Tracking (STRICT PRIVACY: ZERO passenger or multi-route disclosure!)
class ParcelTrackingScreen extends ConsumerStatefulWidget {
  final String parcelId;
  const ParcelTrackingScreen({super.key, required this.parcelId});

  @override
  ConsumerState<ParcelTrackingScreen> createState() => _ParcelTrackingScreenState();
}

class _ParcelTrackingScreenState extends ConsumerState<ParcelTrackingScreen> {
  Map<String, dynamic>? _shipment;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    final sock = ref.read(socketServiceProvider);
    sock.joinTracking('parcel', widget.parcelId);
    sock.socket?.off('parcel:status');
    sock.socket?.on('parcel:status', (_) => _load());
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiClientProvider).get('/parcels/${widget.parcelId}');
      setState(() => _shipment = Map<String, dynamic>.from(res['shipment'] as Map));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _rateParcel() async {
    int stars = 5;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Rate Parcel Delivery'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (i) => IconButton(
                onPressed: () => setS(() => stars = i + 1),
                icon: Icon(i < stars ? Icons.star : Icons.star_border, color: Colors.amber),
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                await ref.read(apiClientProvider).post('/parcels/${widget.parcelId}/rate', body: {'rating': stars});
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('Submit Rating'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _shipment == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final s = _shipment!;
    final courier = s['courier'] as Map?;

    return Scaffold(
      appBar: AppBar(title: Text('Parcel ${s['trackingCode']}')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: TwoBeeColors.surfaceTonal,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s['statusBanner']?.toString() ?? 'Courier En-Route',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: TwoBeeColors.primary)),
                    const SizedBox(height: 6),
                    Text('${s['pickupAddress']} → ${s['dropoffAddress']}'),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Delivery Security PIN', style: TextStyle(fontWeight: FontWeight.w700)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(color: TwoBeeColors.obsidian, borderRadius: BorderRadius.circular(10)),
                          child: Text(s['deliveryPin'].toString(),
                              style: const TextStyle(color: TwoBeeColors.primarySoft, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 4)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (courier != null)
              Card(
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: TwoBeeColors.surfaceTonal, child: Icon(Icons.two_wheeler_rounded, color: TwoBeeColors.primary)),
                  title: Text('${courier['name']} · ★${courier['rating']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${courier['vehicle']} · ${courier['plateNo']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.chat_outlined, color: TwoBeeColors.primary),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InAppChatScreen(
                          serviceType: 'PARCEL',
                          orderId: widget.parcelId,
                          peerTitle: courier['name'] as String,
                        ),
                      ),
                    ),
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
                    Text('Package: ${s['category']} (${s['weightKg']} kg)', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('Delivery Fee: ${bdt(s['deliveryChargeBdt'] as num)} (${s['paymentMethod']})'),
                    if ((s['codCollectBdt'] as num) > 0) Text('Recipient COD Due: ${bdt(s['codCollectBdt'] as num)}'),
                  ],
                ),
              ),
            ),
            if (['BOOKED', 'MATCHING', 'RIDER_ASSIGNED'].contains(s['status'])) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  await ref.read(apiClientProvider).post('/parcels/${widget.parcelId}/cancel');
                  _load();
                },
                child: const Text('Cancel Shipment & Refund'),
              ),
            ],
            if (s['status'] == 'DELIVERED' && s['rating'] == null) ...[
              const SizedBox(height: 14),
              ElevatedButton(onPressed: _rateParcel, child: const Text('Rate Parcel Service')),
            ],
          ],
        ),
      ),
    );
  }
}

