import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://ttipwqpiwqwejvxtzqqn.supabase.co',
    'sb_publishable_2cW0EppUpaTpRhuumLGzMA_0JS00vKw',
  );

  try {
    final profiles = await client.from('profiles').select();
    print('Profiles found: ${profiles.length}');
    for (final p in profiles) {
      print('Name: ${p['full_name']}, Role: ${p['role']}, ID: ${p['id']}');
    }
  } catch (e) {
    print('Query failed! Error: $e');
  }
}
