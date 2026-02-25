// ⚠️ EXAMPLE CONFIG FILE
// Copy this file to supabase_config.dart and fill in your actual values
// DO NOT commit supabase_config.dart to Git

class SupabaseConfig {
  static const String supabaseUrl = 'your_supabase_url_here';
  static const String supabaseAnonKey = 'your_supabase_anon_key_here';

  // Groq API Keys
  static const List<String> groqApiKeys = [
    'your_groq_api_key_1_here',
    'your_groq_api_key_2_here',
    'your_groq_api_key_3_here',
    'your_groq_api_key_4_here',
    'your_groq_api_key_5_here',
  ];

  // Gemini API Keys
  static const String geminiEmbeddingKey = 'your_gemini_embedding_key_here';
  static const List<String> geminiChatKeys = [
    'your_gemini_chat_key_1_here',
    'your_gemini_chat_key_2_here',
    'your_gemini_chat_key_3_here',
    'your_gemini_chat_key_4_here',
    'your_gemini_chat_key_5_here',
  ];

  // Google Sheets API Key
  static const String googleSheetsApiKey = 'your_google_sheets_api_key_here';

  // Google Sheet ID
  static const String googleSheetId = 'your_google_sheet_id_here';
}
