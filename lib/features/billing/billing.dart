import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../app.dart';
import '../../core/billing/billing_calculator.dart';
import '../../core/database/app_database.dart';
import '../../core/settings/app_settings.dart';

final cartProvider = NotifierProvider<CartController, List<CartLine>>(CartController.new);

class CartController extends Notifier<List<CartLine>> {
  @override List<CartLine> build() => [];
  void add(Item item) {
    final i = state.indexWhere((x) => x.item.id == item.id);
    if (i >= 0) {
      setQuantity(state[i].id, state[i].quantity + 1);
    } else if (item.stockQuantity > 0) {
      state = [...state, CartLine(id: const Uuid().v4(), item: item)];
    }
  }
  void setQuantity(String id, int quantity) {
    final index = state.indexWhere((x) => x.id == id);
    if (index < 0) return;
    final line = state[index];
    final nextQuantity = quantity.clamp(1, line.item.stockQuantity);
    final next = [...state];
    next[index] = line.copyWith(quantity: nextQuantity);
    state = next;
  }
  void remove(String id) => state = state.where((x) => x.id != id).toList();
  void clear() => state = [];
  void replace(List<CartLine> cart) => state = [...cart];
}

class BillingPage extends ConsumerStatefulWidget {
  const BillingPage({super.key});
  @override ConsumerState<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends ConsumerState<BillingPage> {
  final search = TextEditingController();
  final discount = TextEditingController(text: '0');
  final searchFocus = FocusNode();
  List<Item> results = [];
  List<CartLine>? heldCart;
  List<Customer> customers = [];
  String? selectedCustomerId;
  String paymentMethod = 'cash';
  AppSettings? settings;
  bool busy = false;

  @override void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    settings = AppSettings(prefs);
    final db = ref.read(databaseProvider);
    results = await db.searchItems('');
    customers = await db.getCustomers();
    if (mounted) setState(() {});
  }

  @override void dispose() {
    search.dispose();
    discount.dispose();
    searchFocus.dispose();
    super.dispose();
  }

  Future<void> _search(String value) async {
    final rows = await ref.read(databaseProvider).searchItems(value);
    if (!mounted) return;
    setState(() => results = rows);
  }

  BillingTotals _totals(List<CartLine> cart) => const BillingCalculator().calculate(
    lines: cart.map((line) => BillingLine(
      unitPriceMinor: line.item.priceMinor,
      quantity: line.quantity,
      taxRateBps: (line.item.taxRate * 100).round(),
    )).toList(),
    discountMinor: _discountMinor,
  );

  int get _discountMinor {
    final parsed = double.tryParse(discount.text.trim()) ?? 0;
    return parsed < 0 ? 0 : (parsed * 100).round();
  }

  String _money(int minor) => '₹' + (minor / 100).toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    BillingTotals totals;
    try {
      totals = _totals(cart);
    } on ArgumentError {
      final subtotal = cart.fold<int>(0, (s, l) => s + l.item.priceMinor * l.quantity);
      totals = BillingTotals(subtotalMinor: subtotal, taxMinor: 0, discountMinor: 0, totalMinor: subtotal);
    }
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeyboardKey.f2: const _BillingActionIntent('search'),
        LogicalKeyboardKey.f4: const _BillingActionIntent('customer'),
        LogicalKeyboardKey.f8: const _BillingActionIntent('hold'),
        LogicalKeyboardKey.f9: const _BillingActionIntent('payment'),
        LogicalKeyboardKey.f12: const _BillingActionIntent('checkout'),
        LogicalKeyboardKey.escape: const _BillingActionIntent('escape'),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _BillingActionIntent: CallbackAction<_BillingActionIntent>(
            onInvoke: (intent) {
              switch (intent.action) {
                case 'search': searchFocus.requestFocus(); break;
                case 'customer': _selectCustomer(); break;
                case 'hold': _holdCart(); break;
                case 'payment': _paymentDialog(); break;
                case 'checkout': _checkout(); break;
                case 'escape': FocusManager.instance.primaryFocus?.unfocus(); break;
              }
              return null;
            },
          ),
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Billing'),
            actions: [
              if (heldCart != null)
                IconButton(
                  tooltip: 'Resume held cart (F8)',
                  onPressed: _resumeHeldCart,
                  icon: const Icon(Icons.play_arrow_outlined),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(child: Text(
                  'F2 Search • F4 Customer • F8 Hold • F9 Pay • F12 Checkout',
                  style: Theme.of(context).textTheme.labelSmall,
                )),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: wide
              ? Row(children: [
                  Expanded(flex: 3, child: _products()),
                  const SizedBox(width: 16),
                  SizedBox(width: 390, child: _cart(cart, totals)),
                ])
              : Column(children: [
                  _searchBox(),
                  const SizedBox(height: 8),
                  Expanded(child: _productList()),
                  const SizedBox(height: 8),
                  _cartSummary(cart, totals),
                ]),
          ),
        ),
      ),
    );
  }

  Widget _products() => Column(children: [
    _searchBox(), const SizedBox(height: 12), Expanded(child: _productList())
  ]);

  Widget _searchBox() => TextField(
    controller: search,
    focusNode: searchFocus,
    onChanged: _search,
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      prefixIcon: const Icon(Icons.search),
      hintText: 'Search name, SKU or barcode (F2)',
      suffixIcon: search.text.isEmpty ? null : IconButton(
        tooltip: 'Clear',
        onPressed: () { search.clear(); _search(''); },
        icon: const Icon(Icons.close),
      ),
    ),
  );

  Widget _productList() => results.isEmpty
    ? const Center(child: Text('No active products found.'))
    : ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final item = results[i];
        final subtitle = item.stockQuantity.toString() + ' in stock • ' +
          item.taxRate.toStringAsFixed(2) + '% tax' +
          (item.sku == null ? '' : ' • SKU ' + item.sku!);
        return Card(child: ListTile(
          title: Text(item.name),
          subtitle: Text(subtitle),
          trailing: FilledButton.tonalIcon(
            onPressed: item.stockQuantity == 0 ? null : () => ref.read(cartProvider.notifier).add(item),
            icon: const Icon(Icons.add_shopping_cart_outlined),
            label: Text(_money(item.priceMinor)),
          ),
        ));
      },
    );

  Widget _cart(List<CartLine> cart, BillingTotals totals) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Cart', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          if (cart.isNotEmpty)
            TextButton.icon(
              onPressed: () => ref.read(cartProvider.notifier).clear(),
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Clear'),
            ),
        ]),
        const SizedBox(height: 8),
        Expanded(child: cart.isEmpty
          ? const Center(child: Text('Cart is empty'))
          : ListView.separated(
              itemCount: cart.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => _cartLine(cart[i]),
            )),
        const SizedBox(height: 10),
        _cartSummary(cart, totals),
      ]),
    ),
  );

  Widget _cartLine(CartLine line) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(line.item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Row(children: [
      IconButton(
        tooltip: 'Decrease quantity',
        visualDensity: VisualDensity.compact,
        onPressed: line.quantity <= 1 ? null : () =>
          ref.read(cartProvider.notifier).setQuantity(line.id, line.quantity - 1),
        icon: const Icon(Icons.remove_circle_outline),
      ),
      Text(line.quantity.toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
      IconButton(
        tooltip: 'Increase quantity',
        visualDensity: VisualDensity.compact,
        onPressed: line.quantity >= line.item.stockQuantity ? null : () =>
          ref.read(cartProvider.notifier).setQuantity(line.id, line.quantity + 1),
        icon: const Icon(Icons.add_circle_outline),
      ),
      const SizedBox(width: 4),
      Text('× ' + _money(line.item.priceMinor)),
    ]),
    trailing: IconButton(
      tooltip: 'Remove',
      onPressed: () => ref.read(cartProvider.notifier).remove(line.id),
      icon: const Icon(Icons.delete_outline),
    ),
  );

  Widget _cartSummary(List<CartLine> cart, BillingTotals totals) => Column(children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text('Subtotal'), Text(_money(totals.subtotalMinor))
    ]),
    const SizedBox(height: 6),
    Row(children: [
      const Expanded(child: Text('Discount')),
      SizedBox(
        width: 110,
        child: TextField(
          controller: discount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          textAlign: TextAlign.end,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(prefixText: '₹ ', isDense: true),
        ),
      ),
    ]),
    const SizedBox(height: 6),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text('Tax'), Text(_money(totals.taxMinor))
    ]),
    const Divider(),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('TOTAL', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      Text(_money(totals.totalMinor), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
    ]),
    const SizedBox(height: 10),
    if (selectedCustomerId != null)
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Customer: ' + (customers.firstWhere((c) => c.id == selectedCustomerId).name),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    if (selectedCustomerId != null) const SizedBox(height: 6),
    Row(children: [
      Expanded(child: OutlinedButton.icon(
        onPressed: cart.isEmpty ? null : _selectCustomer,
        icon: const Icon(Icons.person_outline),
        label: Text(selectedCustomerId == null ? 'Customer (F4)' : 'Change customer'),
      )),
      const SizedBox(width: 8),
      Expanded(child: OutlinedButton.icon(
        onPressed: cart.isEmpty ? null : _paymentDialog,
        icon: const Icon(Icons.payments_outlined),
        label: Text(paymentMethod.toUpperCase()),
      )),
    ]),
    const SizedBox(height: 10),
    FilledButton.icon(
      onPressed: cart.isEmpty || busy ? null : _checkout,
      icon: busy
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : const Icon(Icons.check_circle_outline),
      label: Text(busy ? 'Processing…' : 'Checkout (F12)'),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
    ),
    if (heldCart != null)
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          'A cart is on hold. Press F8 to swap between the current and held cart.',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
  ]);

  Future<void> _selectCustomer() async {
    if (customers.isEmpty) customers = await ref.read(databaseProvider).getCustomers();
    final selected = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        String filter = '';
        return StatefulBuilder(builder: (context, setDialogState) {
          final f = filter.toLowerCase();
          final visible = customers.where((c) =>
            c.name.toLowerCase().contains(f) || (c.phone ?? '').toLowerCase().contains(f)).toList();
          return AlertDialog(
            title: const Text('Select customer'),
            content: SizedBox(
              width: 420,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  autofocus: true,
                  onChanged: (v) => setDialogState(() => filter = v),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search customers'),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: visible.isEmpty
                    ? const Padding(padding: EdgeInsets.all(20), child: Text('No matching customers.'))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: visible.length,
                        itemBuilder: (_, i) => ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(visible[i].name),
                          subtitle: Text(visible[i].phone ?? 'No phone'),
                          trailing: selectedCustomerId == visible[i].id ? const Icon(Icons.check) : null,
                          onTap: () => Navigator.pop(dialogContext, visible[i].id),
                        ),
                      ),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, ''), child: const Text('Walk-in / clear')),
            ],
          );
        });
      },
    );
    if (selected != null) setState(() => selectedCustomerId = selected.isEmpty ? null : selected);
  }

  Future<void> _paymentDialog() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Payment method'),
        children: ['cash', 'upi', 'card', 'credit'].map((method) =>
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, method),
            child: Row(children: [
              Icon(method == 'cash'
                ? Icons.payments_outlined
                : method == 'upi'
                  ? Icons.qr_code_2_outlined
                  : method == 'card'
                    ? Icons.credit_card_outlined
                    : Icons.account_balance_wallet_outlined),
              const SizedBox(width: 12),
              Text(method[0].toUpperCase() + method.substring(1)),
              const Spacer(),
              if (paymentMethod == method) const Icon(Icons.check),
            ]),
          )).toList(),
      ),
    );
    if (selected != null) setState(() => paymentMethod = selected);
  }

  void _holdCart() {
    final current = ref.read(cartProvider);
    if (current.isEmpty && heldCart == null) return;
    final next = heldCart;
    heldCart = current.isEmpty ? null : List<CartLine>.from(current);
    ref.read(cartProvider.notifier).replace(next ?? const <CartLine>[]);
    setState(() {});
  }

  void _resumeHeldCart() => _holdCart();

  Future<void> _checkout() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty || busy) return;
    final prefs = await SharedPreferences.getInstance();
    final appSettings = settings ?? AppSettings(prefs);
    BillingTotals totals;
    try {
      totals = _totals(cart);
    } on ArgumentError {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Discount cannot exceed the subtotal.')));
      return;
    }
    final no = appSettings.invoicePrefix + '-' + DateTime.now().millisecondsSinceEpoch.toString();
    setState(() => busy = true);
    try {
      await ref.read(databaseProvider).checkout(
        invoiceId: const Uuid().v4(),
        invoiceNumber: no,
        cart: cart,
        customerId: selectedCustomerId,
        discountMinor: totals.discountMinor,
        paymentMethod: paymentMethod,
      );
      ref.read(cartProvider.notifier).clear();
      if (!mounted) return;
      setState(() {
        selectedCustomerId = null;
        discount.text = '0';
        paymentMethod = 'cash';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invoice ' + no + ' created • ' + _money(totals.totalMinor))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Checkout failed: ' + e.toString())));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _BillingActionIntent extends Intent {
  const _BillingActionIntent(this.action);
  final String action;
}
