import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  SupabaseClient get client => _client;

  // Profiles
  Future<Map<String, dynamic>?> getProfile(String id) async {
    return await _client.from('profiles').select().eq('id', id).maybeSingle();
  }

  Future<void> updateProfile(String id, Map<String, dynamic> data) async {
    await _client.from('profiles').update(data).eq('id', id);
  }

  // Ponds
  Future<List<Map<String, dynamic>>> getMyPonds() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    return await _client.from('ponds').select().eq('user_id', uid);
  }

  // Orders
  Future<List<Map<String, dynamic>>> getMyOrders() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    return await _client.from('orders').select().or('buyer_id.eq.$uid,farmer_id.eq.$uid');
  }

  // Listings
  Future<List<Map<String, dynamic>>> getAvailableListings() async {
    return await _client.from('listings').select().eq('status', 'active');
  }

  // Sensor Readings
  Future<List<Map<String, dynamic>>> getSensorReadings(String pondId) async {
    return await _client.from('sensor_readings').select().eq('pond_id', pondId).order('created_at', ascending: false);
  }
}
