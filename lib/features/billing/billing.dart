import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../app.dart';
import '../../core/database/app_database.dart';

final cartProvider = NotifierProvider<CartController, List<CartLine>>(CartController.new);

class CartController extends Notifier<List<CartLine>> {
  @override List<CartLine> build() => [];
  void add(Item item) {
    final i = state.indexWhere((x) => x.item.id == item.id);
    if (i >= 0) {
      final next = [...state];
      if (next[i].quantity < item.stockQuantity) {
        next[i] = next[i].copyWith(quantity: next[i].quantity + 1);
      }
      state = next;
    } else if (item.stockQuantity > 0) {
      state = [...state, CartLine(id: const Uuid().v4(), item: item)];
    }
  }
  void remove(String id) => state = state.where((x) => x.id != id).toList();
  void clear() => state = [];
}

class BillingPage extends ConsumerStatefulWidget {
  const BillingPage({super.key});
  @override ConsumerState<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends ConsumerState<BillingPage> {
  final search = TextEditingController();
  List<Item> results = [];

  Future<void> _search(String value) async {
    results = await ref.read(databaseProvider).searchItems(value);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final subtotal = cart.fold<int>(0, (s, l) => s + l.item.priceMinor * l.quantity);
    final tax = cart.fold<int>(0, (s, l) =>
      s + ((l.item.priceMinor * l.quantity * l.item.taxRate) / 100).round());
    final total = subtotal + tax;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(title: const Text('Billing')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: wide
          ? Row(children: [
              Expanded(flex: 3, child: _products()),
              const SizedBox(width: 16),
              SizedBox(width: 380, child: _cart(cart, subtotal, tax, total)),
            ])
          : Column(children: [
              _searchBox(), const SizedBox(height: 8),
              Expanded(child: _productList()),
              const Divider(), _summary(cart, subtotal, tax, total),
            ]),
      ),
    );
  }

  Widget _products() => Column(children: [
    _searchBox(), const SizedBox(height: 12), Expanded(child: _productList())
  ]);

  Widget _searchBox() => TextField(
    controller: search, onChanged: _search,
    decoration: const InputDecoration(
      prefixIcon: Icon(Icons.search), hintText: 'Search name, SKU or barcode'),
  );

  Widget _productList() => results.isEmpty
    ? const Center(child: Text('Search for a product to add it to the cart.'))
    : ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final x = results[i];
        return Card(child: ListTile(
          title: Text(x.name),
          subtitle: Text(x.stockQuantity.toString() + ' in stock • ' + x.taxRate.toString() + '% tax'),
          trailing: TextButton(
            onPressed: x.stockQuantity == 0 ? null : () => ref.read(cartProvider.notifier).add(x),
            child: Text('₹' + (x.priceMinor / 100).toStringAsFixed(2)),
          ),
        ));
      },
    );

  Widget _cart(List<CartLine> cart, int s, int t, int total) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Cart', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Expanded(child: cart.isEmpty
          ? const Center(child: Text('Cart is empty'))
          : ListView.builder(
            itemCount: cart.length,
            itemBuilder: (_, i) {
              final l = cart[i];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.item.name),
                subtitle: Text(l.quantity.toString() + ' × ₹' + (l.item.priceMinor / 100).toStringAsFixed(2)),
                trailing: IconButton(
                  tooltip: 'Remove',
                  onPressed: () => ref.read(cartProvider.notifier).remove(l.id),
                  icon: const Icon(Icons.delete_outline)),
              );
            },
          )),
        _summary(cart, s, t, total),
      ]),
    ),
  );

  Widget _summary(List<CartLine> cart, int s, int t, int total) => Column(children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text('Subtotal'), Text('₹' + (s / 100).toStringAsFixed(2))]),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text('Tax'), Text('₹' + (t / 100).toStringAsFixed(2))]),
    const Divider(),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('TOTAL', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      Text('₹' + (total / 100).toStringAsFixed(2),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
    ]),
    const SizedBox(height: 12),
    FilledButton.icon(
      onPressed: cart.isEmpty ? null : _checkout,
      icon: const Icon(Icons.payments_outlined), label: const Text('Checkout'),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
    ),
  ]);

  Future<void> _checkout() async {
    final cart = ref.read(cartProvider);
    final no = 'SB-' + DateTime.now().millisecondsSinceEpoch.toString();
    try {
      await ref.read(databaseProvider).checkout(
        invoiceId: const Uuid().v4(), invoiceNumber: no, cart: cart,
        paymentMethod: 'cash', discountMinor: 0);
      ref.read(cartProvider.notifier).clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invoice ' + no + ' created')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checkout failed: ' + e.toString())));
    }
  }
}
