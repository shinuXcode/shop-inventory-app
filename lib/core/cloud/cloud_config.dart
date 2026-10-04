class CloudConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const legacyAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get key =>
      publishableKey.isNotEmpty ? publishableKey : legacyAnonKey;

  static bool get configured => url.isNotEmpty && key.isNotEmpty;
}
