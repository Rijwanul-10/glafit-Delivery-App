import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/twobee_theme.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  final String? roleFilter;
  const NotificationsScreen({super.key, this.roleFilter});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  String _cat = 'ALL';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get(
            '/common/notifications',
            query: widget.roleFilter != null ? {'role': widget.roleFilter} : null,
          );
      setState(() => _items = (res['items'] as List?) ?? []);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAll() async {
    await ref.read(apiClientProvider).post('/common/notifications/read-all');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _cat == 'ALL'
        ? _items
        : _items.where((x) => (x['category'] as String?) == _cat).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(onPressed: _markAll, child: const Text('Mark all read')),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: ['ALL', 'ORDERS', 'OFFERS', 'SYSTEM'].map((c) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c),
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
                : visible.isEmpty
                    ? const Center(child: Text('No updates right now.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final n = visible[i] as Map;
                          final unread = n['isRead'] == false;
                          return Card(
                            color: unread ? TwoBeeColors.surfaceTonal : TwoBeeColors.surfaceCard,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: TwoBeeColors.primarySoft.withValues(alpha: 0.4),
                                child: const Icon(Icons.notifications_active_outlined, color: TwoBeeColors.primary),
                              ),
                              title: Text(n['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(n['body']?.toString() ?? ''),
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

class InAppChatScreen extends ConsumerStatefulWidget {
  final String serviceType; // FOOD | PARCEL | RIDE
  final String orderId;
  final String peerTitle;
  final String senderRole; // CLIENT | RIDER

  const InAppChatScreen({
    super.key,
    required this.serviceType,
    required this.orderId,
    required this.peerTitle,
    this.senderRole = 'CLIENT',
  });

  @override
  ConsumerState<InAppChatScreen> createState() => _InAppChatScreenState();
}

class _InAppChatScreenState extends ConsumerState<InAppChatScreen> {
  final _ctrl = TextEditingController();
  String? _threadId;
  List<dynamic> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiClientProvider).get('/common/chat/${widget.serviceType}/${widget.orderId}');
      final t = res['thread'] as Map<String, dynamic>;
      _threadId = t['id'] as String;
      _messages = List<dynamic>.from(t['messages'] as List);
      final sock = ref.read(socketServiceProvider);
      sock.joinChat(_threadId!);
      sock.socket?.off('chat:message');
      sock.socket?.on('chat:message', (msg) {
        if (!mounted) return;
        setState(() {
          if (!_messages.any((m) => m['id'] == msg['id'])) _messages.add(msg);
        });
      });
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _threadId == null) return;
    _ctrl.clear();
    final res = await ref.read(apiClientProvider).post(
      '/common/chat/$_threadId/messages',
      body: {'body': text, 'senderRole': widget.senderRole},
    );
    if (mounted) {
      setState(() {
        final msg = res['message'];
        if (!_messages.any((m) => m['id'] == msg['id'])) _messages.add(msg);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat · ${widget.peerTitle}')),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i] as Map;
                      final mine = m['senderRole'] == widget.senderRole;
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: mine ? TwoBeeColors.primary : TwoBeeColors.surfaceCard,
                            borderRadius: BorderRadius.circular(14),
                            border: mine ? null : Border.all(color: TwoBeeColors.borderSoft),
                          ),
                          child: Text(
                            m['body']?.toString() ?? '',
                            style: TextStyle(color: mine ? Colors.white : TwoBeeColors.textPrimary),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: const InputDecoration(hintText: 'Write message...'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: TwoBeeColors.primary),
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded),
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

Future<void> showSosSafetySheet(BuildContext context, WidgetRef ref, {required String role, String? orderId}) async {
  await showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.emergency_rounded, color: TwoBeeColors.errorText, size: 28),
              SizedBox(width: 10),
              Text('2Bee Emergency Safety Center', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          const Text('Trigger live GPS SOS alert to 2Bee 24/7 Dispatch Security or dial national emergency hotline.'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: TwoBeeColors.errorText),
            onPressed: () async {
              await ref.read(apiClientProvider).post('/common/sos', body: {
                'role': role,
                'orderId': ?orderId,
                'lat': 23.7937,
                'lng': 90.4066,
                'note': 'Urgent SOS triggered from $role panel',
              });
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('SOS Alert sent to 2Bee Safety Team! Hotline: 16216')),
                );
              }
            },
            icon: const Icon(Icons.warning_amber_rounded),
            label: const Text('Send Live SOS Alert'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse('tel:999')),
            icon: const Icon(Icons.call_rounded),
            label: const Text('Call National Emergency (999)'),
          ),
        ],
      ),
    ),
  );
}

class SupportLegalScreen extends StatefulWidget {
  final String title;
  const SupportLegalScreen({super.key, this.title = 'Help & Legal'});

  @override
  State<SupportLegalScreen> createState() => _SupportLegalScreenState();
}

class _SupportLegalScreenState extends State<SupportLegalScreen> {
  final _ticketCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: TwoBeeColors.surfaceTonal,
            child: ListTile(
              leading: const Icon(Icons.support_agent_rounded, color: TwoBeeColors.primary),
              title: const Text('2Bee 24/7 Dhaka Support', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Hotline: 16216 · support@2bee.app'),
              trailing: FilledButton(
                onPressed: () => launchUrl(Uri.parse('tel:16216')),
                child: const Text('Call'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.gavel_outlined, color: TwoBeeColors.primary),
                  title: const Text('Terms of Service'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TermsAndPrivacyScreen(initialTab: 0)),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined, color: TwoBeeColors.primary),
                  title: const Text('Privacy Policy & Data Protection'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TermsAndPrivacyScreen(initialTab: 1)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text('Frequently Asked Questions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 6),
          const Card(
            child: ExpansionTile(
              title: Text('Food Orders, Home Kitchens & Refunds', style: TextStyle(fontWeight: FontWeight.w600)),
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Text('Home Kitchens operate with verified daily batch quotas and cutoff times. Instant refunds apply automatically if a merchant rejects or cancels your order.'),
                ),
              ],
            ),
          ),
          const Card(
            child: ExpansionTile(
              title: Text('Parcel Tiers & Front Carrier Protection', style: TextStyle(fontWeight: FontWeight.w600)),
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Text('Normal parcels up to 8 kg qualify for eco dispatch. Recipients share a 4-digit Delivery Security PIN at handover.'),
                ),
              ],
            ),
          ),
          const Card(
            child: ExpansionTile(
              title: Text('Rider Multi-Service & Payout Security Holds', style: TextStyle(fontWeight: FontWeight.w600)),
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Text('Multi-service pairs only Normal Front-Carrier parcels along matching Zone A -> B corridors, always dropping passengers first. Payout changes enforce SMS OTP + 48h hold.'),
                ),
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
                  const Text('Report an Issue / Support Ticket', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _ticketCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: 'Describe your trip, parcel, food order or payout question...'),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      final refNo = '2B-SUP-${DateTime.now().millisecondsSinceEpoch % 10000}';
                      _ticketCtrl.clear();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Support ticket $refNo submitted! Response ETA < 15 mins.')),
                      );
                    },
                    child: const Text('Submit Support Ticket'),
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

class TermsAndPrivacyScreen extends StatefulWidget {
  final int initialTab; // 0: Terms, 1: Privacy
  const TermsAndPrivacyScreen({super.key, this.initialTab = 0});

  @override
  State<TermsAndPrivacyScreen> createState() => _TermsAndPrivacyScreenState();
}

class _TermsAndPrivacyScreenState extends State<TermsAndPrivacyScreen> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_tab == 0 ? 'Terms of Service' : 'Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Terms of Service')),
              ButtonSegment(value: 1, label: Text('Privacy Policy')),
            ],
            selected: {_tab},
            onSelectionChanged: (v) => setState(() => _tab = v.first),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _tab == 0
                    ? const [
                        Text('2Bee Super-App Terms of Service (v1.0)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        SizedBox(height: 10),
                        Text('1. Account Identity: One verified Bangladesh mobile phone (+8801XXXXXXXXX) unlocks Client, Rider, and Merchant roles under isolated role tokens.'),
                        SizedBox(height: 8),
                        Text('2. Role Security: Riders create a permanent 4-digit PIN during registration. Merchants set NO passcode while KYC is pending and must create a fixed 6-digit PIN via OTP upon admin approval. Sessions lock after 15 minutes of inactivity.'),
                        SizedBox(height: 8),
                        Text('3. Multi-Service Compliance: Eligible only for Normal parcels (<= 8 kg & <= 31,500 cm3) along Zone A -> Zone B corridors. Passengers are dropped first before final parcel delivery.'),
                        SizedBox(height: 8),
                        Text('4. Payout Protection: Bank / MFS payout changes require SMS OTP and a mandatory 48-hour security hold.'),
                      ]
                    : const [
                        Text('2Bee Privacy & Isolation Policy', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        SizedBox(height: 10),
                        Text('1. Strict Service Isolation: Parcel Senders/Recipients and Ride Passengers NEVER see each other\'s identity, route overlap, or multi-service batching metadata.'),
                        SizedBox(height: 8),
                        Text('2. Telemetry & Tracking: Rider GPS updates stream over encrypted WebSocket rooms isolated strictly per active order or trip ID.'),
                        SizedBox(height: 8),
                        Text('3. KYC Documents: NID, Driving License, Trade License, and Selfies are stored strictly for identity verification and regulatory compliance.'),
                      ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

