import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  await Supabase.initialize(
    url: 'https://inimbyivkmwgqnsbkmqg.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImluaW1ieWl2a213Z3Fuc2JrbXFnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcwMTU4MTksImV4cCI6MjA5MjU5MTgxOX0.R6TpilbhIVir7fD7hF39SR317NG9B_7SumGVpr0ezps',
  );
  
  final supabase = Supabase.instance.client;
  
  try {
    final response = await supabase
        .from('app_config')
        .select('key, value')
        .filter('key', 'in', ['latest_version', 'update_url', 'min_version']);
        
    print('Response: $response');
  } catch (e) {
    print('Error: $e');
  }
}
