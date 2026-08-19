import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://ttipwqpiwqwejvxtzqqn.supabase.co',
    'sb_publishable_2cW0EppUpaTpRhuumLGzMA_0JS00vKw',
  );

  try {
    final snap = await client.from('listings')
        .select('*, profiles:farmer_id(full_name, farm_name, region)')
        .eq('status', 'active');
    print('Query succeeded! Result count: ${snap.length}');
    if (snap.isNotEmpty) {
      print('First item: ${snap.first}');
    }
  } catch (e) {
    print('Query failed! Error: $e');
  }
}
