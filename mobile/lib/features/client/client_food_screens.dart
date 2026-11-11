import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/twobee_theme.dart';
import '../../core/widgets/common_widgets.dart';
import '../common/shared_screens.dart';

class CartLine {
  final String menuItemId;
  final String name;
  final double basePrice;
  final List<Map<String, dynamic>> selectedOptions;
  final int quantity;

  const CartLine({
    required this.menuItemId,
    required this.name,
    required this.basePrice,
    this.selectedOptions = const [],
    this.quantity = 1,
  });

  double get unitPrice => basePrice + selectedOptions.fold(0.0, (s, o) => s + ((o['extraBdt'] as num?) ?? 0).toDouble());
  double get lineTotal => unitPrice * quantity;

  CartLine copyWith({int? quantity}) => CartLine(
        menuItemId: menuItemId,
        name: name,
        basePrice: basePrice,
        selectedOptions: selectedOptions,
        quantity: quantity ?? this.quantity,
      );
}

class CartState {
  final String? merchantId;
  final String? merchantName;
  final double deliveryFee;
  final List<CartLine> lines;
  final String? promoCode;

  const CartState({
    this.merchantId,
    this.merchantName,
    this.deliveryFee = 45,
    this.lines = const [],
    this.promoCode,
  });

  double get subtotal => lines.fold(0.0, (s, l) => s + l.lineTotal);
  int get totalItems => lines.fold(0, (s, l) => s + l.quantity);
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  void addItem({
    required String merchantId,
    required String merchantName,
    required double deliveryFee,
    required CartLine line,
  }) {
    if (state.merchantId != null && state.merchantId != merchantId) {
      state = CartState(merchantId: merchantId, merchantName: merchantName, deliveryFee: deliveryFee, lines: [line]);
      return;
    }
    final next = [...state.lines];
    final idx = next.indexWhere((x) => x.menuItemId == line.menuItemId && x.selectedOptions.length == line.selectedOptions.length);
    if (idx >= 0) {
      next[idx] = next[idx].copyWith(quantity: next[idx].quantity + line.quantity);
    } else {
      next.add(line);
    }
    state = CartState(
      merchantId: merchantId,
      merchantName: merchantName,
      deliveryFee: deliveryFee,
      lines: next,
      promoCode: state.promoCode,
    );
  }

  void updateQty(int index, int delta) {
    final next = [...state.lines];
    final newQty = next[index].quantity + delta;
    if (newQty <= 0) {
      next.removeAt(index);
    } else {
      next[index] = next[index].copyWith(quantity: newQty);
    }
    state = CartState(
      merchantId: next.isEmpty ? null : state.merchantId,
      merchantName: next.isEmpty ? null : state.merchantName,
      deliveryFee: state.deliveryFee,
      lines: next,
      promoCode: state.promoCode,
    );
  }

  void applyPromo(String? code) {
    state = CartState(
      merchantId: state.merchantId,
      merchantName: state.merchantName,
      deliveryFee: state.deliveryFee,
      lines: state.lines,
      promoCode: code?.trim().toUpperCase(),
    );
  }

  void clear() => state = const CartState();
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) => CartNotifier());

class FoodHomeScreen extends ConsumerStatefulWidget {
  const FoodHomeScreen({super.key});

  @override
  ConsumerState<FoodHomeScreen> createState() => _FoodHomeScreenState();
}

class _FoodHomeScreenState extends ConsumerState<FoodHomeScreen> {
  List<dynamic> _restaurants = [];
  String _filterType = 'ALL';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get(
            '/food/restaurants',
            query: _filterType == 'ALL' ? null : {'type': _filterType},
          );
      setState(() => _restaurants = (res['restaurants'] as List?) ?? []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('2Bee Food'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodSearchScreen())),
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen())),
            icon: const Icon(Icons.favorite_border_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: ['ALL', 'PHYSICAL', 'HOME_KITCHEN'].map((t) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(t == 'ALL' ? 'All' : t == 'PHYSICAL' ? 'Restaurants' : 'Home Kitchens'),
                    selected: _filterType == t,
                    onSelected: (_) {
                      setState(() => _filterType = t);
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
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _restaurants.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final r = _restaurants[i] as Map;
                      final isHk = r['merchantType'] == 'HOME_KITCHEN';
                      final open = r['isStoreOpen'] == true;
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(14),
                          leading: CircleAvatar(
                            radius: 28,
                            backgroundColor: TwoBeeColors.surfaceTonal,
                            child: Icon(isHk ? Icons.home_work_outlined : Icons.restaurant, color: TwoBeeColors.primary),
                          ),
                          title: Row(
                            children: [
                              Expanded(child: Text(r['businessName'].toString(), style: const TextStyle(fontWeight: FontWeight.w800))),
                              if (isHk)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: TwoBeeColors.primarySoft.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(6)),
                                  child: Text('Slots: ${r['remainingDailySlots'] ?? 0}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            '★ ${r['rating']} · ${r['avgPrepMins']} min · Delivery ${bdt(r['deliveryFeeBdt'] ?? 45)} · ${open ? 'OPEN' : 'CLOSED'}',
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => RestaurantDetailScreen(merchantId: r['id'] as String)),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: cart.totalItems > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
                  child: Text('${cart.totalItems} item(s) · ${bdt(cart.subtotal)} · View Cart'),
                ),
              ),
            )
          : null,
    );
  }
}

class FoodSearchScreen extends ConsumerStatefulWidget {
  const FoodSearchScreen({super.key});

  @override
  ConsumerState<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends ConsumerState<FoodSearchScreen> {
  final _ctrl = TextEditingController();
  List<dynamic> _hits = [];

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Future<void> _search(String q) async {
    final res = await ref.read(apiClientProvider).get('/food/restaurants', query: q.isEmpty ? null : {'q': q});
    if (mounted) setState(() => _hits = (res['restaurants'] as List?) ?? []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Search Kacchi, Home Kitchen...', border: InputBorder.none),
          onChanged: _search,
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _hits.length,
        itemBuilder: (_, i) {
          final r = _hits[i] as Map;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text(r['businessName'].toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${r['merchantType']} · ★${r['rating']}'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RestaurantDetailScreen(merchantId: r['id'] as String)),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Favorites Screen (BDT ৳ enforced — fixes $ currency bug in design!)
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  List<dynamic> _restaurants = [];
  List<dynamic> _dishes = [];
  bool _showRestaurants = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/client/favorites');
      setState(() {
        _restaurants = (res['restaurants'] as List?) ?? [];
        _dishes = (res['dishes'] as List?) ?? [];
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text('Restaurants (${_restaurants.length})')),
                ButtonSegment(value: false, label: Text('Saved Dishes (${_dishes.length})')),
              ],
              selected: {_showRestaurants},
              onSelectionChanged: (v) => setState(() => _showRestaurants = v.first),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _showRestaurants
                    ? (_restaurants.isEmpty
                        ? const Center(child: Text('No favorite kitchens yet.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _restaurants.length,
                            itemBuilder: (_, i) {
                              final r = _restaurants[i] as Map;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  title: Text(r['businessName'].toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text('Min ${bdt(r['minOrderBdt'] ?? 150)} · Delivery ${bdt(r['deliveryFeeBdt'] ?? 45)}'),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => RestaurantDetailScreen(merchantId: r['id'] as String)),
                                  ),
                                ),
                              );
                            },
                          ))
                    : (_dishes.isEmpty
                        ? const Center(child: Text('No saved dishes yet.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _dishes.length,
                            itemBuilder: (_, i) {
                              final d = _dishes[i] as Map;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  title: Text(d['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text('${d['merchant']?['businessName'] ?? ''} · ${bdt(d['priceBdt'] as num)}'),
                                ),
                              );
                            },
                          )),
          ),
        ],
      ),
    );
  }
}

class RestaurantDetailScreen extends ConsumerStatefulWidget {
  final String merchantId;
  const RestaurantDetailScreen({super.key, required this.merchantId});

  @override
  ConsumerState<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends ConsumerState<RestaurantDetailScreen> {
  Map<String, dynamic>? _merchant;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/food/restaurants/${widget.merchantId}');
      setState(() => _merchant = Map<String, dynamic>.from(res['merchant'] as Map));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCustomization(Map item) async {
    final groups = (item['optionGroupsJson'] as List?) ?? [];
    final m = _merchant!;
    if (groups.isEmpty) {
      ref.read(cartProvider.notifier).addItem(
            merchantId: m['id'] as String,
            merchantName: m['businessName'] as String,
            deliveryFee: (m['deliveryFeeBdt'] as num).toDouble(),
            line: CartLine(
              menuItemId: item['id'] as String,
              name: item['name'] as String,
              basePrice: (item['priceBdt'] as num).toDouble(),
            ),
          );
      return;
    }

    final selected = <String, List<Map<String, dynamic>>>{};
    int qty = 1;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item['name'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              for (final g in groups) ...[
                Text('${g['title']} ${g['required'] == true ? '(Required)' : '(Optional)'}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                for (final opt in (g['options'] as List))
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${opt['name']} (+${bdt(opt['extraBdt'] as num)})'),
                    value: (selected[g['title']] ?? []).any((o) => o['id'] == opt['id']),
                    onChanged: (v) {
                      setS(() {
                        final list = selected[g['title']] ?? [];
                        if (g['required'] == true) {
                          selected[g['title'] as String] = [Map<String, dynamic>.from(opt as Map)];
                        } else if (v == true) {
                          selected[g['title'] as String] = [...list, Map<String, dynamic>.from(opt as Map)];
                        } else {
                          selected[g['title'] as String] = list.where((o) => o['id'] != opt['id']).toList();
                        }
                      });
                    },
                  ),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(onPressed: () => setS(() => qty = (qty - 1).clamp(1, 20)), icon: const Icon(Icons.remove_circle_outline)),
                      Text('$qty', style: const TextStyle(fontWeight: FontWeight.w800)),
                      IconButton(onPressed: () => setS(() => qty++), icon: const Icon(Icons.add_circle_outline)),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final missing = groups.any((g) => g['required'] == true && (selected[g['title']]?.isEmpty ?? true));
                      if (missing) return;
                      final opts = selected.entries
                          .expand((e) => e.value.map((o) => {'group': e.key, 'name': o['name'], 'extraBdt': o['extraBdt']}))
                          .toList();
                      ref.read(cartProvider.notifier).addItem(
                            merchantId: m['id'] as String,
                            merchantName: m['businessName'] as String,
                            deliveryFee: (m['deliveryFeeBdt'] as num).toDouble(),
                            line: CartLine(
                              menuItemId: item['id'] as String,
                              name: item['name'] as String,
                              basePrice: (item['priceBdt'] as num).toDouble(),
                              selectedOptions: opts,
                              quantity: qty,
                            ),
                          );
                      Navigator.pop(ctx);
                    },
                    child: const Text('Add to cart'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _merchant == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final m = _merchant!;
    final cats = (m['categories'] as List?) ?? [];
    final promos = (m['promotions'] as List?) ?? [];
    final cart = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(m['businessName'].toString()),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border_rounded),
            onPressed: () async {
              final res = await ref.read(apiClientProvider).post('/client/favorites/toggle', body: {
                'targetType': 'RESTAURANT',
                'targetId': m['id'],
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(res['favorited'] == true ? 'Added to Favorites' : 'Removed from Favorites')),
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: TwoBeeColors.surfaceTonal,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${m['merchantType']} · ★ ${m['rating']} · ${m['avgPrepMins']} mins · Min ${bdt(m['minOrderBdt'] ?? 150)}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (m['merchantType'] == 'HOME_KITCHEN')
                    Text('Remaining Daily Slots: ${m['remainingDailySlots'] ?? 0} · Cutoff ${m['dailyCutoffTime']}',
                        style: const TextStyle(color: TwoBeeColors.primary, fontWeight: FontWeight.w700)),
                  if (promos.isNotEmpty)
                    Text('Promo: ${promos.first['promoCode']} — ${promos.first['title']}',
                        style: const TextStyle(color: TwoBeeColors.primaryAccent, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final cat in cats) ...[
            Text(cat['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            for (final item in (cat['items'] as List))
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(item['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${item['description'] ?? ''}\n${bdt(item['priceBdt'] as num)}'),
                  isThreeLine: true,
                  trailing: FilledButton(
                    onPressed: item['inStock'] == true ? () => _openCustomization(item as Map) : null,
                    child: Text(item['inStock'] == true ? '+ Add' : 'Out'),
                  ),
                ),
              ),
          ],
        ],
      ),
      bottomNavigationBar: cart.totalItems > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
                  child: Text('${cart.totalItems} item(s) · ${bdt(cart.subtotal)} · View Cart'),
                ),
              ),
            )
          : null,
    );
  }
}

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _promoCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    if (cart.lines.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cart')),
        body: const Center(child: Text('Your cart is empty')),
      );
    }

    final total = cart.subtotal + cart.deliveryFee + 15 + 10;

    return Scaffold(
      appBar: AppBar(title: Text('Cart · ${cart.merchantName}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...List.generate(cart.lines.length, (i) {
            final l = cart.lines[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(l.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${bdt(l.unitPrice)} each'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(onPressed: () => ref.read(cartProvider.notifier).updateQty(i, -1), icon: const Icon(Icons.remove_circle_outline)),
                    Text('${l.quantity}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    IconButton(onPressed: () => ref.read(cartProvider.notifier).updateQty(i, 1), icon: const Icon(Icons.add_circle_outline)),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
          TextField(controller: _noteCtrl, decoration: const InputDecoration(labelText: 'Cooking instructions')),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: TextField(controller: _promoCtrl, decoration: const InputDecoration(labelText: 'Promo (try 2BEE100)'))),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => ref.read(cartProvider.notifier).applyPromo(_promoCtrl.text),
                child: const Text('Apply'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _BillRow('Subtotal', bdt(cart.subtotal)),
                  _BillRow('Delivery Fee', bdt(cart.deliveryFee)),
                  _BillRow('Packaging + Service', bdt(25)),
                  const Divider(),
                  _BillRow('Estimated Total', bdt(total), bold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CheckoutScreen(cookingNote: _noteCtrl.text))),
            child: const Text('Go to Checkout ->'),
          ),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _BillRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w400)),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        ],
      ),
    );
  }
}

class CheckoutScreen extends ConsumerStatefulWidget {
  final String cookingNote;
  const CheckoutScreen({super.key, this.cookingNote = ''});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _addressCtrl = TextEditingController(text: 'House 42, Road 11, Banani');
  String _scheduleMode = 'NOW';
  String _payment = 'COD';
  bool _loading = false;

  Future<void> _placeOrder() async {
    final cart = ref.read(cartProvider);
    final estTotal = cart.subtotal + cart.deliveryFee + 25;
    if (_payment == 'STRIPE_SANDBOX') {
      final ok = await showStripeSandboxDialog(context, amountBdt: estTotal, title: 'Food · ${cart.merchantName}');
      if (!ok) return;
    }

    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).post('/food/orders/checkout', body: {
        'merchantId': cart.merchantId,
        'items': cart.lines
            .map((l) => {'menuItemId': l.menuItemId, 'quantity': l.quantity, 'selectedOptions': l.selectedOptions})
            .toList(),
        'deliveryAddress': _addressCtrl.text.trim(),
        'scheduleMode': _scheduleMode,
        'cookingNote': widget.cookingNote,
        if (cart.promoCode != null && cart.promoCode!.isNotEmpty) 'promoCode': cart.promoCode,
        'paymentMethod': _payment,
      });
      ref.read(cartProvider.notifier).clear();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => FoodLiveTrackingScreen(orderId: res['order']['id'] as String)),
        (r) => r.isFirst,
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Delivery Address')),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'NOW', label: Text('Deliver Now (25–35m)')),
              ButtonSegment(value: 'SCHEDULED', label: Text('Schedule')),
            ],
            selected: {_scheduleMode},
            onSelectionChanged: (v) => setState(() => _scheduleMode = v.first),
          ),
          const SizedBox(height: 12),
          PaymentSelectorCard(selectedMethod: _payment, onSelected: (m) => setState(() => _payment = m)),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _loading ? null : _placeOrder,
            child: Text(_loading ? 'Placing Order...' : 'Place Order'),
          ),
        ],
      ),
    );
  }
}

class FoodLiveTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;
  const FoodLiveTrackingScreen({super.key, required this.orderId});

  @override
  ConsumerState<FoodLiveTrackingScreen> createState() => _FoodLiveTrackingScreenState();
}

class _FoodLiveTrackingScreenState extends ConsumerState<FoodLiveTrackingScreen> {
  Map<String, dynamic>? _order;
  double? _riderLat;
  double? _riderLng;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    final sock = ref.read(socketServiceProvider);
    sock.joinTracking('food', widget.orderId);
    sock.socket?.off('order:status');
    sock.socket?.on('order:status', (_) => _load());
    sock.socket?.off('tracking:location');
    sock.socket?.on('tracking:location', (loc) {
      if (mounted && loc is Map && loc['orderId'] == widget.orderId) {
        setState(() {
          _riderLat = (loc['lat'] as num).toDouble();
          _riderLng = (loc['lng'] as num).toDouble();
        });
      }
    });
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiClientProvider).get('/food/orders/${widget.orderId}');
      setState(() => _order = Map<String, dynamic>.from(res['order'] as Map));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _rateFood() async {
    int restStars = 5;
    int riderStars = 5;
    num tip = 20;
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Delivered! Rate Restaurant & Rider', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => IconButton(onPressed: () => setS(() => restStars = i + 1), icon: Icon(i < restStars ? Icons.star : Icons.star_border, color: Colors.amber))),
              ),
              const Text('Rider Tip'),
              Wrap(
                spacing: 8,
                children: [0, 10, 20, 50].map((t) => ChoiceChip(label: Text(bdt(t)), selected: tip == t, onSelected: (_) => setS(() => tip = t))).toList(),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  await ref.read(apiClientProvider).post('/food/orders/${widget.orderId}/rate', body: {
                    'restaurantRating': restStars,
                    'riderRating': riderStars,
                    'tipBdt': tip,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Submit Review'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _order == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final o = _order!;
    final items = (o['items'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(title: Text('Order ${o['orderCode']}')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TwoBeeMapPreview(
              pickupLat: (o['merchant']?['lat'] as num?)?.toDouble() ?? 23.7942,
              pickupLng: (o['merchant']?['lng'] as num?)?.toDouble() ?? 90.4071,
              dropoffLat: (o['deliveryLat'] as num?)?.toDouble() ?? 23.7937,
              dropoffLng: (o['deliveryLng'] as num?)?.toDouble() ?? 90.4066,
              riderLat: _riderLat,
              riderLng: _riderLng,
            ),
            const SizedBox(height: 12),
            Card(
              color: TwoBeeColors.surfaceTonal,
              child: ListTile(
                title: Text('Status: ${o['status']}', style: const TextStyle(fontWeight: FontWeight.w800, color: TwoBeeColors.primary)),
                subtitle: Text('${o['merchant']?['businessName']} -> ${o['deliveryAddress']}'),
                trailing: Text(bdt(o['totalBdt'] as num), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            if (o['rider'] != null)
              Card(
                child: ListTile(
                  title: Text('Courier: ${o['rider']['user']['fullName']}'),
                  subtitle: Text('${o['rider']['vehicleBrandModel']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.chat_outlined, color: TwoBeeColors.primary),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InAppChatScreen(
                          serviceType: 'FOOD',
                          orderId: widget.orderId,
                          peerTitle: o['rider']['user']['fullName'] as String,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Order Receipt', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    ...items.map((i) => _BillRow('${i['quantity']}x ${i['itemName']}', bdt(i['lineTotalBdt'] as num))),
                    const Divider(),
                    _BillRow('Total Paid (${o['paymentMethod']})', bdt(o['totalBdt'] as num), bold: true),
                  ],
                ),
              ),
            ),
            if (o['status'] == 'DELIVERED') ...[
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _rateFood, child: const Text('Rate & Tip')),
            ],
          ],
        ),
      ),
    );
  }
}

