import 'package:flutter/material.dart';
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
  @override void initState() {
    super.initState();
    future = ref.read(databaseProvider).getCustomers();
  }
  void refresh() => setState(() => future = ref.read(databaseProvider).getCustomers());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Customers'), actions: [
      IconButton(tooltip: 'Add customer', onPressed: _add, icon: const Icon(Icons.person_add_outlined))
    ]),
    body: FutureBuilder<List<Customer>>(
      future: future,
      builder: (c, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final list = s.data!;
        if (list.isEmpty) return const Center(child: Text('No customers yet'));
        return ListView.builder(
          padding: const EdgeInsets.all(16), itemCount: list.length,
          itemBuilder: (_, i) => Card(child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(list[i].name),
            subtitle: Text(list[i].phone ?? 'No phone'),
          )),
        );
      },
    ),
  );

  Future<void> _add() async {
    final n = TextEditingController(), p = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add customer'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: n, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 8),
          TextField(controller: p, decoration: const InputDecoration(labelText: 'Phone')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || n.text.trim().isEmpty) return;
    final now = DateTime.now();
    await ref.read(databaseProvider).saveCustomer(CustomersCompanion.insert(
      id: const Uuid().v4(), name: n.text.trim(), phone: Value(p.text.trim()),
      createdAt: now, updatedAt: now));
    refresh();
  }
}
