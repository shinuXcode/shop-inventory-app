import 'package:flutter/material.dart';
import 'package:shop_inventory_app/features/home/home_screen.dart';
import 'package:shop_inventory_app/core/theme.dart';

class ShopInventoryApp extends StatelessWidget {
  const ShopInventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shop Inventory',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: const HomeScreen(),
    );
  }
}
