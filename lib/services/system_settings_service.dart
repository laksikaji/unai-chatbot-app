import 'package:supabase_flutter/supabase_flutter.dart';

class SystemSettingsService {
  final SupabaseClient _client = Supabase.instance.client;

  // Get current AI provider
  Future<String> getAiProvider() async {
    try {
      final response = await _client
          .from('system_settings')
          .select('value')
          .eq('key', 'ai_provider')
          .single();

      return response['value'] as String;
    } catch (e) {
      // Default to gemini if not found or error
      return 'gemini';
    }
  }

  // Update AI provider
  Future<void> updateAiProvider(String provider) async {
    if (provider != 'gemini' && provider != 'groq') {
      throw Exception('Invalid provider: $provider');
    }

    await _client.from('system_settings').upsert({
      'key': 'ai_provider',
      'value': provider,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
