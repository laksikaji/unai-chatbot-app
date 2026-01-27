import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  late final SupabaseClient client;

  Future<void> initialize() async {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
    client = Supabase.instance.client;
  }

  // Authentication
  Future<AuthResponse> signUp(String email, String password) async {
    return await client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signIn(String email, String password) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(email);
  }

  Future<UserResponse> updatePassword(String newPassword) async {
    return await client.auth.updateUser(UserAttributes(password: newPassword));
  }

  // User Profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await client
        .from('users')
        .select()
        .eq('id', userId)
        .single();
    return response;
  }

  Future<void> updateUserProfile({String? username}) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    // Build update data - only include username if provided
    final Map<String, dynamic> updateData = {
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (username != null && username.isNotEmpty) {
      updateData['username'] = username;
    }

    // Use update instead of upsert to prevent creating/overwriting
    await client.from('users').update(updateData).eq('id', userId);
  }

  // Check if user is admin
  Future<bool> isAdmin() async {
    try {
      final profile = await getUserProfile();
      return profile != null && profile['role'] == 'admin';
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }

  // Chat Sessions
  Future<List<Map<String, dynamic>>> getChatSessions() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await client
        .from('chat_sessions')
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<String> createChatSession({String title = 'New Chat'}) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await client
        .from('chat_sessions')
        .insert({'user_id': userId, 'title': title})
        .select()
        .single();

    return response['id'];
  }

  Future<void> updateChatSession(String sessionId, String newTitle) async {
    await client
        .from('chat_sessions')
        .update({
          'title': newTitle,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', sessionId);
  }

  Future<void> deleteChatSession(String sessionId) async {
    await client.from('chat_sessions').delete().eq('id', sessionId);
  }

  // Messages
  Future<List<Map<String, dynamic>>> getMessages(String sessionId) async {
    final response = await client
        .from('messages')
        .select()
        .eq('chat_session_id', sessionId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addMessage({
    required String sessionId,
    required String content,
    required bool isUser,
  }) async {
    await client.from('messages').insert({
      'chat_session_id': sessionId,
      'content': content,
      'is_user': isUser,
    });

    // อัพเดต updated_at ของ chat session
    await client
        .from('chat_sessions')
        .update({'updated_at': DateTime.now().toIso8601String()})
        .eq('id', sessionId);
  }

  // Get current user
  User? get currentUser => client.auth.currentUser;

  // Check if user is logged in
  bool get isLoggedIn => client.auth.currentUser != null;

  // Delete user account
  Future<void> deleteUserAccount() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    try {
      // เรียก Edge Function เพื่อลบ user account ถาวร (ทั้ง database และ Auth)
      final response = await client.functions.invoke('delete-user-account');

      if (response.status != 200) {
        throw Exception(response.data['error'] ?? 'Failed to delete account');
      }

      // Sign out หลังจากลบสำเร็จ
      await client.auth.signOut();
    } catch (e) {
      debugPrint('Error deleting account: $e');
      rethrow;
    }
  }
}
