import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/twobee_theme.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/common_widgets.dart';

/// Merchant Home Pending (No passcode needed while KYC is pending; store locked closed!)
class MerchantHomePendingScreen extends ConsumerStatefulWidget {
  const MerchantHomePendingScreen({super.key});

  @override
  ConsumerState<MerchantHomePendingScreen> createState() => _MerchantHomePendingScreenState();
}

class _MerchantHomePendingScreenState extends ConsumerState<MerchantHomePendingScreen> {
  Map<String, dynamic>? _pendingData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/merchant/pending-home');
      setState(() => _pendingData = res);
      await ref.read(authControllerProvider.notifier).refreshRoles();
      final p = res['profile'] as Map?;
      if (mounted && p?['requiresPostApprovalPinSetup'] == true) {
        context.go('/merchant/post-approval-pin');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _pendingData?['profile'] as Map?;
    return Scaffold(
      appBar: AppBar(
        title: Text(p?['businessName']?.toString() ?? 'Merchant Pending'),
        actions: [
          TextButton(onPressed: () => context.go('/roles'), child: const Text('Switch Role')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const VerificationBanner(
                  title: 'Verification in progress · Store stays closed until approval',
                  subtitle: 'Once admin verifies your documents, your phone receives an approval notice to create your 6-digit passcode.',
                  isErrorStyle: true,
                ),
                const SizedBox(height: 16),
                Card(
                  child: SwitchListTile(
                    value: false,
                    onChanged: null,
                    title: const Text('Store Accepting Orders (Locked Closed)'),
                    subtitle: Text('Store Type: ${p?['merchantType'] ?? ''} · KYC: ${p?['kycStatus'] ?? 'PENDING'}'),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Today Snapshot', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text('Net Sales: ${bdt(0)} · Orders: 0'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Check Live Approval Status'),
                ),
              ],
            ),
    );
  }
}

/// Split Merchant Panel Shell (Option B: 4-tab AppBottomNav `Home | Orders | Wallet | Store`).
class MerchantShell extends ConsumerStatefulWidget {
  const MerchantShell({super.key});

  @override
  ConsumerState<MerchantShell> createState() => _MerchantShellState();
}

class _MerchantShellState extends ConsumerState<MerchantShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);
    if (session.lockModalNeeded || session.merchantRoleToken == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_clock_rounded, size: 52, color: TwoBeeColors.primary),
                const SizedBox(height: 12),
                const Text('Merchant Session Locked', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Re-enter your 6-digit passcode to resume.', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: () => context.go('/merchant/passcode'), child: const Text('Unlock with 6-Digit PIN')),
              ],
            ),
          ),
        ),
      );
    }

    final pages = [
      _MerchantSplitHomeTab(onOpenOrders: () => setState(() => _tab = 1)),
      const _MerchantOrdersTab(),
      const _MerchantWalletTab(),
      const _MerchantSplitStoreTab(),
    ];

    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: AppBottomNav(
        role: AppUserRole.merchant,
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _MerchantSplitHomeTab extends ConsumerStatefulWidget {
  final VoidCallback onOpenOrders;
  const _MerchantSplitHomeTab({required this.onOpenOrders});

  @override
  ConsumerState<_MerchantSplitHomeTab> createState() => _MerchantSplitHomeTabState();
}

class _MerchantSplitHomeTabState extends ConsumerState<_MerchantSplitHomeTab> {
  Map<String, dynamic>? _home;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    ref.read(socketServiceProvider).socket?.on('merchant:new_order', (_) => _load());
  }

  Future<void> _load() async {
    final roleToken = ref.read(authControllerProvider).merchantRoleToken;
    if (roleToken == null) return;
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/merchant/panel/home', roleToken: roleToken);
      setState(() => _home = res);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleStore(bool open) async {
    final roleToken = ref.read(authControllerProvider).merchantRoleToken;
    await ref.read(apiClientProvider).patch('/merchant/panel/store/toggle', roleToken: roleToken, body: {'isStoreOpen': open});
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _home == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final m = _home!['merchant'] as Map;
    final stats = _home!['stats'] as Map;
    final hk = _home!['homeKitchenPanel'] as Map?;
    final isHk = m['merchantType'] == 'HOME_KITCHEN' && hk != null;
    final newOrders = (_home!['newOrders'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(m['businessName'].toString()),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: TwoBeeColors.surfaceTonal, borderRadius: BorderRadius.circular(10)),
            child: Text(isHk ? 'HOME KITCHEN' : 'RESTAURANT', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: TwoBeeColors.primary)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: m['isStoreOpen'] == true ? TwoBeeColors.surfaceTonal : TwoBeeColors.errorBg,
              child: SwitchListTile(
                value: m['isStoreOpen'] == true,
                onChanged: _toggleStore,
                title: Text(
                  isHk
                      ? (m['isStoreOpen'] == true ? 'Kitchen is Open' : 'Kitchen Closed')
                      : (m['isStoreOpen'] == true ? 'Accepting Orders' : 'Store Closed'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(isHk
                    ? 'Cutoff ${hk['dailyCutoffTime']} · Quota ${hk['usedQuota']} / ${hk['dailyOrderLimit']}'
                    : 'Avg Prep: ${m['avgPrepMins']} mins · ★${m['rating']}'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _StatCard('Orders', '${stats['todayOrders']}')),
                const SizedBox(width: 8),
                Expanded(child: _StatCard('Sales', bdt(stats['todaySalesBdt'] as num))),
                const SizedBox(width: 8),
                Expanded(child: _StatCard(isHk ? 'Quota Left' : 'Avg Prep', isHk ? '${hk['remainingQuota']}' : '${stats['avgPrepMins']}m')),
              ],
            ),
            if (isHk) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Daily Kitchen Batch Quota (${hk['usedQuota']} / ${hk['dailyOrderLimit']})', style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: ((hk['usedQuota'] as num) / ((hk['dailyOrderLimit'] as num).clamp(1, 999))).toDouble(),
                        color: TwoBeeColors.primary,
                      ),
                      const SizedBox(height: 10),
                      const Text('Available Tonight Stock', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ...(hk['availableTonightItems'] as List).map((item) => SwitchListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(item['name'].toString()),
                            value: item['availableTonight'] == true,
                            onChanged: (v) async {
                              final roleToken = ref.read(authControllerProvider).merchantRoleToken;
                              await ref.read(apiClientProvider).patch('/merchant/panel/menu/items/${item['id']}',
                                  roleToken: roleToken, body: {'availableTonight': v});
                              _load();
                            },
                          )),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Prominent Menu quick access replacing 5th Menu bottom tab!
            Card(
              color: TwoBeeColors.obsidian,
              child: ListTile(
                leading: const Icon(Icons.restaurant_menu_rounded, color: TwoBeeColors.primarySoft),
                title: const Text('Manage Menu & Add-ons', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                subtitle: const Text('Add items, prices & stock status', style: TextStyle(color: Colors.white70, fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MerchantMenuScreen())),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Incoming New Orders (${newOrders.length})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                TextButton(onPressed: widget.onOpenOrders, child: const Text('All Orders ->')),
              ],
            ),
            if (newOrders.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No pending new orders right now.')))
            else
              ...newOrders.map((o) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text('${o['orderCode']} · ${bdt(o['totalBdt'] as num)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${(o['items'] as List).length} item(s) · ${o['deliveryAddress']}'),
                      trailing: FilledButton(onPressed: widget.onOpenOrders, child: const Text('Respond')),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String val;
  const _StatCard(this.label, this.val);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: TwoBeeColors.textSecondary)),
            const SizedBox(height: 4),
            Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: TwoBeeColors.primary)),
          ],
        ),
      ),
    );
  }
}

class _MerchantOrdersTab extends ConsumerStatefulWidget {
  const _MerchantOrdersTab();

  @override
  ConsumerState<_MerchantOrdersTab> createState() => _MerchantOrdersTabState();
}

class _MerchantOrdersTabState extends ConsumerState<_MerchantOrdersTab> {
  String _bucket = 'newOrders';
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = ref.read(authControllerProvider).merchantRoleToken;
    if (token == null) return;
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/merchant/panel/orders', roleToken: token);
      setState(() => _data = res);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept(String orderId) async {
    final token = ref.read(authControllerProvider).merchantRoleToken;
    await ref.read(apiClientProvider).post('/merchant/panel/orders/$orderId/accept', roleToken: token, body: {'prepTimeMins': 20});
    _load();
  }

  Future<void> _reject(String orderId) async {
    final token = ref.read(authControllerProvider).merchantRoleToken;
    await ref.read(apiClientProvider).post('/merchant/panel/orders/$orderId/reject', roleToken: token, body: {'reason': 'Kitchen too busy'});
    _load();
  }

  Future<void> _markReady(String orderId) async {
    final token = ref.read(authControllerProvider).merchantRoleToken;
    await ref.read(apiClientProvider).post('/merchant/panel/orders/$orderId/ready', roleToken: token);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final list = (_data?[_bucket] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MerchantMenuScreen())),
            icon: const Icon(Icons.restaurant_menu_rounded),
            label: const Text('Menu'),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ('newOrders', 'New'),
                ('preparingOrders', 'Preparing'),
                ('readyOrders', 'Ready'),
                ('historyOrders', 'History'),
              ].map((b) {
                final count = ((_data?[b.$1] as List?) ?? []).length;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('${b.$2} ($count)'),
                    selected: _bucket == b.$1,
                    onSelected: (_) => setState(() => _bucket = b.$1),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? const Center(child: Text('No orders in this queue.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final o = list[i] as Map;
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${o['orderCode']} · ${o['user']?['fullName'] ?? ''}',
                                          style: const TextStyle(fontWeight: FontWeight.w800)),
                                      Text(bdt(o['totalBdt'] as num), style: const TextStyle(fontWeight: FontWeight.w800, color: TwoBeeColors.primary)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('${(o['items'] as List).length} item(s) · ${o['status']} · ${o['paymentMethod']}'),
                                  const SizedBox(height: 10),
                                  if (o['status'] == 'PLACED')
                                    Row(
                                      children: [
                                        Expanded(child: OutlinedButton(onPressed: () => _reject(o['id'] as String), child: const Text('Reject'))),
                                        const SizedBox(width: 8),
                                        Expanded(child: ElevatedButton(onPressed: () => _accept(o['id'] as String), child: const Text('Accept (20m)'))),
                                      ],
                                    )
                                  else if (o['status'] == 'PREPARING')
                                    ElevatedButton(onPressed: () => _markReady(o['id'] as String), child: const Text('Mark Ready for Pickup')),
                                ],
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

class _MerchantWalletTab extends ConsumerStatefulWidget {
  const _MerchantWalletTab();

  @override
  ConsumerState<_MerchantWalletTab> createState() => _MerchantWalletTabState();
}

class _MerchantWalletTabState extends ConsumerState<_MerchantWalletTab> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = ref.read(authControllerProvider).merchantRoleToken;
    if (token == null) return;
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/merchant/panel/wallet', roleToken: token);
      setState(() => _data = res);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = (_data?['summary'] as Map?) ?? {};
    final wallet = (_data?['wallet'] as Map?) ?? {};

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet & Earnings')),
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
                        const Text('Available Merchant Balance', style: TextStyle(color: TwoBeeColors.primarySoft)),
                        const SizedBox(height: 4),
                        Text(bdt(wallet['balanceBdt'] ?? 0), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text('Settlement: ${summary['payoutSchedule'] ?? 'Weekly Friday'}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Gross Delivered Sales'), Text(bdt(summary['grossSalesBdt'] ?? 0))]),
                          const SizedBox(height: 6),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Platform Commission (${summary['commissionRatePct'] ?? 15}%)'), Text('-${bdt(summary['commissionBdt'] ?? 0)}')]),
                          const Divider(),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Net Earnings', style: TextStyle(fontWeight: FontWeight.w800)), Text(bdt(summary['netEarningsBdt'] ?? 0), style: const TextStyle(fontWeight: FontWeight.w800, color: TwoBeeColors.primary))]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _MerchantSplitStoreTab extends ConsumerWidget {
  const _MerchantSplitStoreTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchant = ref.watch(authControllerProvider).roles?['merchant'] as Map?;
    final isHk = merchant?['merchantType'] == 'HOME_KITCHEN';

    return Scaffold(
      appBar: AppBar(title: Text(isHk ? 'Home Kitchen Store' : 'Restaurant Store')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(backgroundColor: TwoBeeColors.surfaceTonal, child: Icon(isHk ? Icons.home_work : Icons.storefront, color: TwoBeeColors.primary)),
              title: Text(merchant?['businessName']?.toString() ?? 'Store', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${isHk ? "Home Kitchen" : "Physical Restaurant"} · 6-digit PIN Guard Active'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.restaurant_menu_rounded, color: TwoBeeColors.primary),
                  title: const Text('Menu Manager'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MerchantMenuScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.local_offer_outlined, color: TwoBeeColors.primary),
                  title: const Text('Promotions & Offers'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MerchantPromotionsScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.reviews_outlined, color: TwoBeeColors.primary),
                  title: const Text('Customer Reviews'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MerchantReviewsScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.security_rounded, color: TwoBeeColors.primary),
                  title: const Text('Security (6-Digit PIN & 48h Payout Guard)'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MerchantSecurityScreen())),
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

class MerchantMenuScreen extends ConsumerStatefulWidget {
  const MerchantMenuScreen({super.key});

  @override
  ConsumerState<MerchantMenuScreen> createState() => _MerchantMenuScreenState();
}

class _MerchantMenuScreenState extends ConsumerState<MerchantMenuScreen> {
  List<dynamic> _cats = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = ref.read(authControllerProvider).merchantRoleToken;
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/merchant/panel/menu', roleToken: token);
      setState(() => _cats = (res['categories'] as List?) ?? []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addItemDialog() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '250');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Menu Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Item Name')),
            const SizedBox(height: 8),
            TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price (৳)')),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final token = ref.read(authControllerProvider).merchantRoleToken;
              await ref.read(apiClientProvider).post('/merchant/panel/menu/items', roleToken: token, body: {
                'name': nameCtrl.text.trim(),
                'priceBdt': double.tryParse(priceCtrl.text) ?? 250,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: const Text('Save Item'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menu Manager')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: TwoBeeColors.primary,
        foregroundColor: Colors.white,
        onPressed: _addItemDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final c in _cats) ...[
                  Text(c['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 8),
                  for (final item in (c['items'] as List))
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: SwitchListTile(
                        title: Text('${item['name']} · ${bdt(item['priceBdt'] as num)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        value: item['inStock'] == true,
                        onChanged: (v) async {
                          final token = ref.read(authControllerProvider).merchantRoleToken;
                          await ref.read(apiClientProvider).patch('/merchant/panel/menu/items/${item['id']}',
                              roleToken: token, body: {'inStock': v});
                          _load();
                        },
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

class MerchantPromotionsScreen extends ConsumerStatefulWidget {
  const MerchantPromotionsScreen({super.key});

  @override
  ConsumerState<MerchantPromotionsScreen> createState() => _MerchantPromotionsScreenState();
}

class _MerchantPromotionsScreenState extends ConsumerState<MerchantPromotionsScreen> {
  List<dynamic> _promos = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = ref.read(authControllerProvider).merchantRoleToken;
    final res = await ref.read(apiClientProvider).get('/merchant/panel/promotions', roleToken: token);
    if (mounted) setState(() => _promos = (res['promotions'] as List?) ?? []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Promotions & Offers')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: _promos
            .map((p) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text('${p['promoCode']} · ${p['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${p['discountType']} · Value ${p['discountValue']} · Min ${bdt(p['minOrderBdt'] as num)}'),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class MerchantReviewsScreen extends ConsumerStatefulWidget {
  const MerchantReviewsScreen({super.key});

  @override
  ConsumerState<MerchantReviewsScreen> createState() => _MerchantReviewsScreenState();
}

class _MerchantReviewsScreenState extends ConsumerState<MerchantReviewsScreen> {
  List<dynamic> _reviews = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = ref.read(authControllerProvider).merchantRoleToken;
    final res = await ref.read(apiClientProvider).get('/merchant/panel/reviews', roleToken: token);
    if (mounted) setState(() => _reviews = (res['reviews'] as List?) ?? []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer Reviews')),
      body: _reviews.isEmpty
          ? const Center(child: Text('No customer reviews yet.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: _reviews
                  .map((r) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text('${r['user']?['fullName'] ?? 'Customer'} · ★${r['rating']}'),
                          subtitle: Text('${r['comment'] ?? ''}\n${r['merchantReply'] != null ? 'Reply: ${r['merchantReply']}' : ''}'),
                        ),
                      ))
                  .toList(),
            ),
    );
  }
}

class MerchantSecurityScreen extends ConsumerStatefulWidget {
  const MerchantSecurityScreen({super.key});

  @override
  ConsumerState<MerchantSecurityScreen> createState() => _MerchantSecurityScreenState();
}

class _MerchantSecurityScreenState extends ConsumerState<MerchantSecurityScreen> {
  final _curPin = TextEditingController();
  final _newPin = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security & 6-Digit PIN')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            color: TwoBeeColors.surfaceTonal,
            child: ListTile(
              leading: Icon(Icons.shield_outlined, color: TwoBeeColors.primary),
              title: Text('6-Digit Passcode + 15-min Auto-Lock'),
              subtitle: Text('Critical Payout Guard: Changing payout bank/wallet requires SMS OTP + 48-hour hold.'),
            ),
          ),
          const SizedBox(height: 16),
          TextField(controller: _curPin, maxLength: 6, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Current 6-digit PIN')),
          const SizedBox(height: 8),
          TextField(controller: _newPin, maxLength: 6, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'New 6-digit PIN')),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async {
              final token = ref.read(authControllerProvider).merchantRoleToken;
              await ref.read(apiClientProvider).post('/merchant/panel/security/change-pin', roleToken: token, body: {
                'currentPasscode': _curPin.text.trim(),
                'newPasscode': _newPin.text.trim(),
              });
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('6-digit PIN updated!')));
            },
            child: const Text('Update 6-Digit Passcode'),
          ),
        ],
      ),
    );
  }
}

