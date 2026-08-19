import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://ttipwqpiwqwejvxtzqqn.supabase.co',
    'sb_publishable_2cW0EppUpaTpRhuumLGzMA_0JS00vKw',
  );

  final res = await supabase.from('profiles').select().eq('email', 'shravyaprasuna03@gmail.com').maybeSingle();
  print('Anon read email: $res');
  
  final all = await supabase.from('profiles').select().limit(5);
  print('Anon read all profiles (limit 5): $all');
}
