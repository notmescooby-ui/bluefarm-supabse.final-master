import 'package:supabase_flutter/supabase_flutter.dart';
import 'demo_mode_service.dart';

class DatabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  SupabaseClient get client => _client;

  // Profiles
  Future<Map<String, dynamic>?> getProfile(String id) async {
    if (DemoModeService.isDemoMode) {
      return DemoModeService.demoRole == 'buyer'
          ? DemoModeService.sampleBuyerProfile
          : DemoModeService.sampleFarmerProfile;
    }
    return await _client.from('profiles').select().eq('id', id).maybeSingle();
  }

  Future<void> updateProfile(String id, Map<String, dynamic> data) async {
    if (DemoModeService.isDemoMode) return;
    await _client.from('profiles').update(data).eq('id', id);
  }

  // Ponds
  Future<List<Map<String, dynamic>>> getMyPonds() async {
    if (DemoModeService.isDemoMode) {
      return [
        {
          'id': 'pond-demo-01',
          'name': 'Pond 1 - Vannamei Nursery',
          'area_acres': 1.5,
          'waterbody_type': 'Brackish Water',
          'species': 'Vannamei Shrimp',
          'stocking_date': '2026-09-15',
          'status': 'active',
        },
        {
          'id': 'pond-demo-02',
          'name': 'Pond 2 - Grow-out Pond',
          'area_acres': 3.0,
          'waterbody_type': 'Brackish Water',
          'species': 'Vannamei Shrimp',
          'stocking_date': '2026-08-20',
          'status': 'active',
        },
      ];
    }
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    return await _client.from('ponds').select().eq('user_id', uid);
  }

  // Orders
  Future<List<Map<String, dynamic>>> getMyOrders() async {
    if (DemoModeService.isDemoMode) {
      return [
        {
          'id': 'order-demo-01',
          'species': 'Vannamei Shrimp (Count 30)',
          'quantity_kg': 500,
          'price_per_kg': 380,
          'status': 'completed',
          'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        },
      ];
    }
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    return await _client.from('orders').select().or('buyer_id.eq.$uid,farmer_id.eq.$uid');
  }

  // Listings
  Future<List<Map<String, dynamic>>> getAvailableListings() async {
    if (DemoModeService.isDemoMode) {
      return [
        {
          'id': 'listing-demo-01',
          'species': 'Vannamei Shrimp (Fresh)',
          'quantity_kg': 1200,
          'price_per_kg': 410,
          'location': 'Bhimavaram Rural',
          'status': 'active',
        },
        {
          'id': 'listing-demo-02',
          'species': 'Black Tiger Shrimp',
          'quantity_kg': 800,
          'price_per_kg': 580,
          'location': 'Kakinada Coastal Hub',
          'status': 'active',
        },
      ];
    }
    return await _client.from('listings').select().eq('status', 'active');
  }

  // Sensor Readings
  Future<List<Map<String, dynamic>>> getSensorReadings(String pondId) async {
    if (DemoModeService.isDemoMode) {
      return [
        {
          'pond_id': pondId,
          'ph': 7.4,
          'temperature': 28.5,
          'turbidity': 2.2,
          'dissolved_oxygen': 6.2,
          'created_at': DateTime.now().toIso8601String(),
        },
      ];
    }
    return await _client.from('sensor_readings').select().eq('pond_id', pondId).order('created_at', ascending: false);
  }
}
