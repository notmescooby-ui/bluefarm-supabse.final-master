import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://ttipwqpiwqwejvxtzqqn.supabase.co',
    'sb_publishable_2cW0EppUpaTpRhuumLGzMA_0JS00vKw',
  );

  try {
    final listings = await client.from('listings').select().eq('status', 'active');
    print('Listings query succeeded! Count: ${listings.length}');
    
    if (listings.isNotEmpty) {
      final farmerIds = listings.map((e) => e['farmer_id']).where((id) => id != null).toSet().toList();
      print('Farmer IDs: $farmerIds');
      
      if (farmerIds.isNotEmpty) {
        final profiles = await client.from('profiles').select('id, full_name, farm_name, region').inFilter('id', farmerIds);
        print('Profiles query succeeded! Count: ${profiles.length}');
      }
    }
  } catch (e) {
    print('Query failed! Error: $e');
  }
}
