import 'package:flutter/material.dart';
import 'package:shop_inventory_app/app.dart';
import 'package:shop_inventory_app/data/db/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize database
  await AppDatabase.instance.database;
  
  runApp(const ShopInventoryApp());
}
