import 'package:flutter/material.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../app.dart';
import '../../core/database/app_database.dart';

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});
  @override ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  late Future<List<Customer>> future;
  final search = TextEditingController();

  @override
  void initState() {
    super.initState();
    future = ref.read(databaseProvider).getCustomers();
  }

  void refresh() => setState(() => future = ref.read(databaseProvider).getCustomers(query: search.text));

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Customers'),
      actions: [
        IconButton(
          tooltip: 'Add customer',
          onPressed: () => _edit(),
          icon: const Icon(Icons.person_add_outlined),
        ),
      ],
    ),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        TextField(
          controller: search,
          onChanged: (_) => refresh(),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Search name, phone or email',
            suffixIcon: search.text.isEmpty ? null : IconButton(
              onPressed: () { search.clear(); refresh(); },
              icon: const Icon(Icons.close),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<List<Customer>>(
            future: future,
            builder: (c, s) {
              if (s.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (s.hasError) return Center(child: Text('Failed to load customers: ' + s.error.toString()));
              final list = s.data ?? const <Customer>[];
              if (list.isEmpty) return const Center(child: Text('No customers found.'));
              return ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final customer = list[i];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(customer.name.trim().isEmpty ? '?' : customer.name.trim()[0].toUpperCase()),
                      ),
                      title: Text(customer.name),
                      subtitle: Text(
                        (customer.phone?.isNotEmpty ?? false)
                            ? customer.phone!
                            : (customer.email?.isNotEmpty ?? false) ? customer.email! : 'No contact details',
                      ),
                      onTap: () => _showCustomer(customer),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'edit') _edit(customer);
                          if (v == 'history') _history(customer);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'history', child: Text('Purchase history')),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    ),
  );

  Future<void> _showCustomer(Customer customer) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(customer.name),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(customer.phone ?? 'No phone'),
          const SizedBox(height: 4),
          Text(customer.email ?? 'No email'),
          if ((customer.address ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(customer.address!),
          ],
          if ((customer.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Notes: ' + customer.notes!),
          ],
        ]),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); _history(customer); }, child: const Text('History')),
          FilledButton(onPressed: () { Navigator.pop(context); _edit(customer); }, child: const Text('Edit')),
        ],
      ),
    );
  }

  Future<void> _history(Customer customer) async {
    final invoices = await ref.read(databaseProvider).invoicesForCustomer(customer.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(customer.name + ' • Purchase history'),
        content: SizedBox(
          width: 520,
          height: 420,
          child: invoices.isEmpty
              ? const Center(child: Text('No invoices for this customer.'))
              : ListView.separated(
                  itemCount: invoices.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final invoice = invoices[i];
                    return ListTile(
                      title: Text(invoice.invoiceNumber),
                      subtitle: Text(invoice.createdAt.toLocal().toString()),
                      trailing: Text('₹' + (invoice.totalMinor / 100).toStringAsFixed(2)),
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _edit([Customer? customer]) async {
    final name = TextEditingController(text: customer?.name ?? '');
    final phone = TextEditingController(text: customer?.phone ?? '');
    final email = TextEditingController(text: customer?.email ?? '');
    final address = TextEditingController(text: customer?.address ?? '');
    final notes = TextEditingController(text: customer?.notes ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(customer == null ? 'Add customer' : 'Edit customer'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: name, autofocus: true, onChanged: (_) => setDialogState(() {}), decoration: const InputDecoration(labelText: 'Name *')),
                const SizedBox(height: 10),
                TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
                const SizedBox(height: 10),
                TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 10),
                TextField(controller: address, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: 'Address')),
                const SizedBox(height: 10),
                TextField(controller: notes, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: name.text.trim().isEmpty ? null : () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    final now = DateTime.now();
    await ref.read(databaseProvider).saveCustomer(CustomersCompanion.insert(
      id: customer?.id ?? const Uuid().v4(),
      name: name.text.trim(),
      phone: Value(phone.text.trim().isEmpty ? null : phone.text.trim()),
      email: Value(email.text.trim().isEmpty ? null : email.text.trim()),
      address: Value(address.text.trim().isEmpty ? null : address.text.trim()),
      notes: Value(notes.text.trim().isEmpty ? null : notes.text.trim()),
      createdAt: customer?.createdAt ?? now,
      updatedAt: now,
    ));
    refresh();
  }
}
