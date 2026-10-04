import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/cloud/cloud_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (CloudConfig.configured) {
    await Supabase.initialize(
      url: CloudConfig.url,
      anonKey: CloudConfig.anonKey,
    );
  }
  runApp(const ProviderScope(child: SBillApp()));
}
