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
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _ClientHomeTab(onOpenActivity: () => setState(() => _tab = 1)),
      const _ClientActivityTab(),
      const _ClientWalletTab(),
      const _ClientProfileTab(),
    ];

    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: AppBottomNav(
        role: AppUserRole.client,
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
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

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      final zones = (_home?['zones'] as List?) ?? [];
                      showModalBottomSheet(
                        context: context,
                        builder: (ctx) => ListView(
                          shrinkWrap: true,
                          children: zones.map((z) {
                            return ListTile(
                              leading: const Icon(Icons.location_on_outlined, color: TwoBeeColors.primary),
                              title: Text('${z['name']}, Dhaka'),
                              onTap: () {
                                setState(() => _selectedZone = '${z['name']}, Dhaka');
                                Navigator.pop(ctx);
                              },
                            );
                          }).toList(),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('2Bee', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: TwoBeeColors.primary)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: TwoBeeColors.surfaceTonal, borderRadius: BorderRadius.circular(6)),
                              child: const Text('CLIENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: TwoBeeColors.primary)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, size: 15, color: TwoBeeColors.primary),
                            const SizedBox(width: 4),
                            Text(_selectedZone, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationsScreen(roleFilter: 'CLIENT')),
                  ),
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Good day, $greeting', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodSearchScreen())),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: TwoBeeColors.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: TwoBeeColors.borderSoft),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search_rounded, color: TwoBeeColors.textSecondary),
                    SizedBox(width: 10),
                    Text('Search biryani, home kitchens, shops...', style: TextStyle(color: TwoBeeColors.textSecondary)),
                  ],
                ),
              ),
            ),
            if (activeCount > 0) ...[
              const SizedBox(height: 12),
              VerificationBanner(
                title: 'You have $activeCount active order(s) / trip(s)',
                subtitle: 'Tap to track live progress in Activity',
                onTap: widget.onOpenActivity,
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: TwoBeeColors.obsidian,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ZERO-EMISSION FLEET', style: TextStyle(color: TwoBeeColors.primarySoft, fontSize: 11, fontWeight: FontWeight.w700)),
                        SizedBox(height: 4),
                        Text('2Bee Express & Everyday Delivery', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                        SizedBox(height: 4),
                        Text('Use promo 2BEE100 for food · Stripe Sandbox & COD ready', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: TwoBeeColors.primaryAccent),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ParcelHubScreen())),
                    child: const Text('Send'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text('2Bee Services', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ServiceTile(
                    label: 'Ride',
                    sub: 'EV Solo · Auto',
                    icon: Icons.two_wheeler_rounded,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RideLocationScreen())),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ServiceTile(
                    label: 'Parcel',
                    sub: 'Normal · Express',
                    icon: Icons.inventory_2_rounded,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ParcelHubScreen())),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ServiceTile(
                    label: 'Food',
                    sub: 'Dine & Home',
                    icon: Icons.restaurant_rounded,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodHomeScreen())),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Trending Kitchens', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodHomeScreen())),
                  child: const Text('See all'),
                ),
              ],
            ),
            if (_loading)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else
              ...trending.map((m) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: CircleAvatar(
                        radius: 26,
                        backgroundColor: TwoBeeColors.surfaceTonal,
                        child: Icon(
                          m['merchantType'] == 'HOME_KITCHEN' ? Icons.home_work_outlined : Icons.storefront_rounded,
                          color: TwoBeeColors.primary,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(child: Text(m['businessName'].toString(), style: const TextStyle(fontWeight: FontWeight.w700))),
                          if (m['merchantType'] == 'HOME_KITCHEN')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: TwoBeeColors.primarySoft.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(6)),
                              child: const Text('Home Kitchen', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                      subtitle: Text('★ ${m['rating']} · ${m['avgPrepMins']}m · Fee ${bdt(m['deliveryFeeBdt'] ?? 45)}'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => RestaurantDetailScreen(merchantId: m['id'] as String)),
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final String label;
  final String sub;
  final IconData icon;
  final VoidCallback onTap;

  const _ServiceTile({required this.label, required this.sub, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: TwoBeeColors.surfaceTonal,
                child: Icon(icon, color: TwoBeeColors.primary, size: 26),
              ),
              const SizedBox(height: 10),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 2),
              Text(sub, style: const TextStyle(fontSize: 11, color: TwoBeeColors.textSecondary), textAlign: TextAlign.center),
            ],
          ),
        ),
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
      Navigator.push(context, MaterialPageRoute(builder: (_) => ParcelTrackingScreen(parcelId: id)));
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
      appBar: AppBar(title: const Text('Activity'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
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
      appBar: AppBar(title: const Text('Wallet')),
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
      appBar: AppBar(title: const Text('Profile')),
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
      appBar: AppBar(title: const Text('Edit Profile')),
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
      appBar: AppBar(title: const Text('Saved Addresses')),
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

