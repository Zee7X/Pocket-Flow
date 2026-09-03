// lib/core/constants/supabase_constants.dart
class SupabaseConstants {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://your-project-ref.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'your-supabase-anon-key-here',
  );

  static const String publishableKey = anonKey;

  static bool get isConfigured =>
      url.isNotEmpty &&
      url != 'https://your-project-ref.supabase.co' &&
      anonKey.isNotEmpty &&
      anonKey != 'your-supabase-anon-key-here';
}
