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

  /// Adds an item to cart. If switching restaurants, clears previous items and returns the removed restaurant name.
  String? addItem({
    required String merchantId,
    required String merchantName,
    required double deliveryFee,
    required CartLine line,
  }) {
    String? removedMerchant;
    if (state.merchantId != null && state.merchantId != merchantId) {
      removedMerchant = state.merchantName ?? 'Previous Restaurant';
      state = CartState(merchantId: merchantId, merchantName: merchantName, deliveryFee: deliveryFee, lines: [line]);
      return removedMerchant;
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
    return null;
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
          const TwoBeeHomeAction(),
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
  bool _topRatedOnly = false;
  bool _hkOnly = false;
  bool _fastOnly = false;

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
    final visible = _hits.where((x) {
      if (_topRatedOnly && ((x['rating'] as num?) ?? 0) < 4.8) return false;
      if (_hkOnly && x['merchantType'] != 'HOME_KITCHEN') return false;
      if (_fastOnly && ((x['avgPrepMins'] as num?) ?? 99) > 25) return false;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Search Kacchi, Home Kitchen...', border: InputBorder.none),
          onChanged: _search,
        ),
        actions: const [TwoBeeHomeAction()],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(label: const Text('Top Rated 4.8★+'), selected: _topRatedOnly, onSelected: (v) => setState(() => _topRatedOnly = v)),
                const SizedBox(width: 8),
                FilterChip(label: const Text('Home Kitchens'), selected: _hkOnly, onSelected: (v) => setState(() => _hkOnly = v)),
                const SizedBox(width: 8),
                FilterChip(label: const Text('Fast <=25m'), selected: _fastOnly, onSelected: (v) => setState(() => _fastOnly = v)),
              ],
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? const Center(child: Text('No matching kitchens found.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: visible.length,
                    itemBuilder: (_, i) {
                      final r = visible[i] as Map;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(r['businessName'].toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${r['merchantType']} · ★${r['rating']} · ${r['avgPrepMins']}m'),
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
      appBar: AppBar(title: const Text('Favorites'), actions: const [TwoBeeHomeAction()]),
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
      final removed = ref.read(cartProvider.notifier).addItem(
            merchantId: m['id'] as String,
            merchantName: m['businessName'] as String,
            deliveryFee: (m['deliveryFeeBdt'] as num).toDouble(),
            line: CartLine(
              menuItemId: item['id'] as String,
              name: item['name'] as String,
              basePrice: (item['priceBdt'] as num).toDouble(),
            ),
          );
      if (removed != null && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              duration: const Duration(milliseconds: 1800),
              content: Text('Previous items from $removed were removed'),
            ),
          );
      }
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ItemCustomizationScreen(
          merchant: m,
          item: Map<String, dynamic>.from(item),
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
          const TwoBeeHomeAction(),
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
        appBar: AppBar(title: const Text('Cart'), actions: const [TwoBeeHomeAction()]),
        body: const Center(child: Text('Your cart is empty')),
      );
    }

    final total = cart.subtotal + cart.deliveryFee + 15 + 10;

    return Scaffold(
      appBar: AppBar(title: Text('Cart · ${cart.merchantName}'), actions: const [TwoBeeHomeAction()]),
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
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                if (cart.merchantId != null) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => RestaurantDetailScreen(merchantId: cart.merchantId!)),
                  );
                } else {
                  Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('+ Add more items'),
            ),
          ),
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
      final order = Map<String, dynamic>.from(res['order'] as Map);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => FoodOrderPlacedScreen(order: order)),
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
      appBar: AppBar(title: const Text('Checkout'), actions: const [TwoBeeHomeAction()]),
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

class FoodOrderPlacedScreen extends StatelessWidget {
  final Map<String, dynamic> order;
  const FoodOrderPlacedScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order Placed'), actions: const [TwoBeeHomeAction()]),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: TwoBeeColors.surfaceTonal,
              child: Icon(Icons.check_circle_rounded, color: TwoBeeColors.primary, size: 48),
            ),
            const SizedBox(height: 18),
            Text('Order ${order['orderCode']} Confirmed!', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              'Payment: ${order['paymentMethod']} · ${bdt(order['totalBdt'] as num)}',
              style: const TextStyle(color: TwoBeeColors.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StepDot('Confirmed', true),
                    _StepDot('Cooking', false),
                    _StepDot('On the way', false),
                    _StepDot('Delivered', false),
                  ],
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => FoodLiveTrackingScreen(orderId: order['id'] as String)),
              ),
              child: const Text('Track Live Order ->'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final bool active;
  const _StepDot(this.label, this.active);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(active ? Icons.check_circle : Icons.radio_button_unchecked,
            color: active ? TwoBeeColors.primary : TwoBeeColors.textSecondary, size: 22),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
      ],
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
    if (_order == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FoodDeliveredRatingScreen(order: _order!)),
    );
    _load();
  }

  Future<void> _advanceDemo() async {
    await ref.read(apiClientProvider).post('/common/demo/advance-food/${widget.orderId}');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _order == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final o = _order!;
    final items = (o['items'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(title: Text('Order ${o['orderCode']}'), actions: const [TwoBeeHomeAction()]),
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
                subtitle: Text('${o['merchant']?['businessName']} -> ${o['deliveryAddress']}\nHandover PIN: ${o['deliveryPin'] ?? '----'}'),
                isThreeLine: true,
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
                    _BillRow('Subtotal', bdt(o['subtotalBdt'] ?? 0)),
                    _BillRow('Delivery & Service', bdt(((o['deliveryFeeBdt'] ?? 0) as num) + ((o['packagingFeeBdt'] ?? 0) as num) + ((o['serviceFeeBdt'] ?? 0) as num))),
                    _BillRow('Discount', '-${bdt(o['discountBdt'] ?? 0)}'),
                    const Divider(),
                    _BillRow('Total Paid (${o['paymentMethod']})', bdt(o['totalBdt'] as num), bold: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportLegalScreen(title: 'Order Support'))),
                    icon: const Icon(Icons.help_outline),
                    label: const Text('Need Help'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final m = o['merchant'] as Map?;
                      if (m != null) {
                        for (final it in items) {
                          ref.read(cartProvider.notifier).addItem(
                                merchantId: m['id'] as String,
                                merchantName: m['businessName'] as String,
                                deliveryFee: (o['deliveryFeeBdt'] as num).toDouble(),
                                line: CartLine(
                                  menuItemId: it['menuItemId'] as String,
                                  name: it['itemName'] as String,
                                  basePrice: (it['unitPriceBdt'] as num).toDouble(),
                                  quantity: (it['quantity'] as num).toInt(),
                                ),
                              );
                        }
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
                      }
                    },
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Reorder'),
                  ),
                ),
              ],
            ),
            if (o['status'] != 'DELIVERED' && o['status'] != 'CANCELLED' && o['status'] != 'REJECTED') ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: TwoBeeColors.obsidian),
                onPressed: _advanceDemo,
                icon: const Icon(Icons.fast_forward_rounded),
                label: const Text('Preview: Simulate Next Order Stage ->'),
              ),
            ],
            if (o['status'] == 'DELIVERED') ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _rateFood,
                child: const Text('Rate Restaurant & Rider / View Order Detail ->'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ItemCustomizationScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> merchant;
  final Map<String, dynamic> item;
  const ItemCustomizationScreen({super.key, required this.merchant, required this.item});

  @override
  ConsumerState<ItemCustomizationScreen> createState() => _ItemCustomizationScreenState();
}

class _ItemCustomizationScreenState extends ConsumerState<ItemCustomizationScreen> {
  final Map<String, List<Map<String, dynamic>>> _selected = {};
  final _noteCtrl = TextEditingController();
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final groups = (item['optionGroupsJson'] as List?) ?? [];
    double extra = 0;
    for (final list in _selected.values) {
      for (final o in list) {
        extra += (o['extraBdt'] as num).toDouble();
      }
    }
    final lineTotal = ((item['priceBdt'] as num).toDouble() + extra) * _qty;

    return Scaffold(
      appBar: AppBar(title: Text(item['name'].toString()), actions: const [TwoBeeHomeAction()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: TwoBeeColors.surfaceTonal, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'].toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(item['description']?.toString() ?? '', style: const TextStyle(color: TwoBeeColors.textSecondary)),
                const SizedBox(height: 8),
                Text('Base Price: ${bdt(item['priceBdt'] as num)}', style: const TextStyle(fontWeight: FontWeight.w800, color: TwoBeeColors.primary)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final g in groups) ...[
            Text('${g['title']} ${g['required'] == true ? '(Required)' : '(Optional)'}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 6),
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  for (final opt in (g['options'] as List))
                    CheckboxListTile(
                      title: Text('${opt['name']} (+${bdt(opt['extraBdt'] as num)})'),
                      value: (_selected[g['title']] ?? []).any((o) => o['id'] == opt['id']),
                      onChanged: (v) {
                        setState(() {
                          final list = _selected[g['title']] ?? [];
                          if (g['required'] == true) {
                            _selected[g['title'] as String] = [Map<String, dynamic>.from(opt as Map)];
                          } else if (v == true) {
                            _selected[g['title'] as String] = [...list, Map<String, dynamic>.from(opt as Map)];
                          } else {
                            _selected[g['title'] as String] = list.where((o) => o['id'] != opt['id']).toList();
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
          ],
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'Special Kitchen Instructions (optional)'),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(onPressed: () => setState(() => _qty = (_qty - 1).clamp(1, 20)), icon: const Icon(Icons.remove_circle_outline, size: 30)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text('$_qty', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              IconButton(onPressed: () => setState(() => _qty++), icon: const Icon(Icons.add_circle_outline, size: 30)),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: ElevatedButton(
            onPressed: () {
              final missing = groups.any((g) => g['required'] == true && (_selected[g['title']]?.isEmpty ?? true));
              if (missing) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select required options')));
                return;
              }
              final opts = _selected.entries
                  .expand((e) => e.value.map((o) => {'group': e.key, 'name': o['name'], 'extraBdt': o['extraBdt']}))
                  .toList();
              final removed = ref.read(cartProvider.notifier).addItem(
                    merchantId: widget.merchant['id'] as String,
                    merchantName: widget.merchant['businessName'] as String,
                    deliveryFee: (widget.merchant['deliveryFeeBdt'] as num).toDouble(),
                    line: CartLine(
                      menuItemId: item['id'] as String,
                      name: item['name'] as String,
                      basePrice: (item['priceBdt'] as num).toDouble(),
                      selectedOptions: opts,
                      quantity: _qty,
                    ),
                  );
              if (removed != null) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      duration: const Duration(milliseconds: 1800),
                      content: Text('Previous items from $removed were removed'),
                    ),
                  );
              }
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CartScreen()));
            },
            child: Text('Add to Cart · ${bdt(lineTotal)} ->'),
          ),
        ),
      ),
    );
  }
}

class FoodDeliveredRatingScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> order;
  const FoodDeliveredRatingScreen({super.key, required this.order});

  @override
  ConsumerState<FoodDeliveredRatingScreen> createState() => _FoodDeliveredRatingScreenState();
}

class _FoodDeliveredRatingScreenState extends ConsumerState<FoodDeliveredRatingScreen> {
  int _restStars = 5;
  int _riderStars = 5;
  num _tip = 20;
  final _tags = <String>{'Fresh & Hot', 'Fast Courier'};
  final _commentCtrl = TextEditingController();
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Scaffold(
      appBar: AppBar(title: const Text('Delivered & Rating'), actions: const [TwoBeeHomeAction()]),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const CircleAvatar(
            radius: 36,
            backgroundColor: TwoBeeColors.surfaceTonal,
            child: Icon(Icons.restaurant_rounded, color: TwoBeeColors.primary, size: 38),
          ),
          const SizedBox(height: 12),
          Text('Enjoy your meal from ${o['merchant']?['businessName'] ?? '2Bee Partner'}!',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  const Text('Rate Food & Kitchen', style: TextStyle(fontWeight: FontWeight.w800)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) => IconButton(onPressed: () => setState(() => _restStars = i + 1), icon: Icon(i < _restStars ? Icons.star : Icons.star_border, color: Colors.amber, size: 32))),
                  ),
                  const Divider(),
                  const Text('Rate Courier Service', style: TextStyle(fontWeight: FontWeight.w800)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) => IconButton(onPressed: () => setState(() => _riderStars = i + 1), icon: Icon(i < _riderStars ? Icons.star : Icons.star_border, color: Colors.amber, size: 32))),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Fresh & Hot', 'Great Packaging', 'Fast Courier', 'Polite Handover'].map((t) {
              return FilterChip(
                label: Text(t),
                selected: _tags.contains(t),
                onSelected: (v) => setState(() => v ? _tags.add(t) : _tags.remove(t)),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          const Text('Add Tip for Rider', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [0, 10, 20, 50].map((t) => ChoiceChip(label: Text(t == 0 ? 'No Tip' : bdt(t)), selected: _tip == t, onSelected: (_) => setState(() => _tip = t))).toList(),
          ),
          const SizedBox(height: 12),
          TextField(controller: _commentCtrl, decoration: const InputDecoration(labelText: 'Additional Comment (optional)')),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    await ref.read(apiClientProvider).post('/food/orders/${o['id']}/rate', body: {
                      'restaurantRating': _restStars,
                      'riderRating': _riderStars,
                      'tipBdt': _tip,
                      'comment': '${_tags.join(", ")} ${_commentCtrl.text.trim()}'.trim(),
                    });
                    if (context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => ClientOrderDetailScreen(orderId: o['id'] as String)),
                      );
                    }
                  },
            child: Text(_saving ? 'Submitting...' : 'Submit Review -> Order Detail'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const FoodHomeScreen()),
              (r) => r.isFirst,
            ),
            icon: const Icon(Icons.restaurant_menu_rounded),
            label: const Text('Back to Client Food Home'),
          ),
        ],
      ),
    );
  }
}

class ClientOrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;
  const ClientOrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<ClientOrderDetailScreen> createState() => _ClientOrderDetailScreenState();
}

class _ClientOrderDetailScreenState extends ConsumerState<ClientOrderDetailScreen> {
  Map<String, dynamic>? _order;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiClientProvider).get('/food/orders/${widget.orderId}');
      setState(() => _order = Map<String, dynamic>.from(res['order'] as Map));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _order == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final o = _order!;
    final items = (o['items'] as List?) ?? [];
    final m = o['merchant'] as Map?;

    return Scaffold(
      appBar: AppBar(title: Text('Order Detail · ${o['orderCode']}'), actions: const [TwoBeeHomeAction()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: TwoBeeColors.surfaceTonal,
            child: ListTile(
              leading: const Icon(Icons.receipt_long_rounded, color: TwoBeeColors.primary),
              title: Text(m?['businessName']?.toString() ?? '2Bee Store', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('Status: ${o['status']} · Delivered to ${o['deliveryAddress']}'),
              trailing: Text(bdt(o['totalBdt'] as num), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Itemized Receipt', style: TextStyle(fontWeight: FontWeight.w800)),
                  const Divider(),
                  ...items.map((i) => _BillRow('${i['quantity']}x ${i['itemName']}', bdt(i['lineTotalBdt'] as num))),
                  const Divider(),
                  _BillRow('Subtotal', bdt(o['subtotalBdt'] ?? 0)),
                  _BillRow('Delivery Fee', bdt(o['deliveryFeeBdt'] ?? 0)),
                  _BillRow('Packaging & Service', bdt(((o['packagingFeeBdt'] ?? 0) as num) + ((o['serviceFeeBdt'] ?? 0) as num))),
                  _BillRow('Promo Discount', '-${bdt(o['discountBdt'] ?? 0)}'),
                  const Divider(),
                  _BillRow('Total Paid (${o['paymentMethod']})', bdt(o['totalBdt'] as num), bold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () {
              if (m != null) {
                String? removed;
                for (final it in items) {
                  final r = ref.read(cartProvider.notifier).addItem(
                        merchantId: m['id'] as String,
                        merchantName: m['businessName'] as String,
                        deliveryFee: (o['deliveryFeeBdt'] as num).toDouble(),
                        line: CartLine(
                          menuItemId: it['menuItemId'] as String,
                          name: it['itemName'] as String,
                          basePrice: (it['unitPriceBdt'] as num).toDouble(),
                          quantity: (it['quantity'] as num).toInt(),
                        ),
                      );
                  removed ??= r;
                }
                if (removed != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Previous items from $removed were removed'),
                      duration: const Duration(milliseconds: 1800),
                    ),
                  );
                }
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
              }
            },
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Reorder Same Items'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportLegalScreen(title: 'Order Support'))),
            icon: const Icon(Icons.help_outline),
            label: const Text('Need Help / Issue'),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const FoodHomeScreen()),
              (r) => r.isFirst,
            ),
            icon: const Icon(Icons.restaurant_menu_rounded),
            label: const Text('Back to Client Food Home'),
          ),
        ],
      ),
    );
  }
}

