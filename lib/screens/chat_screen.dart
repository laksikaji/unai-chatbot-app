import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';
import 'supabase_service.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'admin_dashboard.dart';

class ChatScreen extends StatefulWidget {
  final bool isGuest;

  const ChatScreen({super.key, this.isGuest = false});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final List<ChatMessage> _guestMessages = []; // Guest mode messages
  final ScrollController _scrollController = ScrollController();

  String _username = 'User';
  String _email = 'user@example.com';

  List<Map<String, dynamic>> _chatHistory = [];
  String? _currentChatId;
  bool _isLoadingChats = true;
  final _supabaseService = SupabaseService();

  bool get _isGuestMode => widget.isGuest;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    if (!_isGuestMode) {
      _loadUserProfile();
      _loadChatsFromDatabase();
    } else {
      _isLoadingChats = false;
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = SupabaseService().currentUser;
      if (user != null) {
        setState(() {
          _email = user.email ?? 'user@example.com';
        });

        // Load username from database
        final profile = await _supabaseService.getUserProfile();
        if (profile != null && mounted) {
          setState(() {
            _username =
                profile['username'] ?? user.email?.split('@')[0] ?? 'User';
          });
        } else if (mounted) {
          setState(() {
            _username = user.email?.split('@')[0] ?? 'User';
          });
        }

        // Check if user is admin
        final isAdmin = await _supabaseService.isAdmin();
        if (mounted) {
          setState(() {
            _isAdmin = isAdmin;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  Future<void> _loadChatsFromDatabase() async {
    try {
      setState(() {
        _isLoadingChats = true;
      });

      final chats = await _supabaseService.getChatSessions();

      setState(() {
        _chatHistory = chats;
        _isLoadingChats = false;
      });

      // ถ้าไม่มีแชทเลย ให้สร้างแชทแรกอัตโนมัติ
      if (_chatHistory.isEmpty) {
        await _createNewChat();
      } else {
        // โหลดแชทล่าสุด
        await _loadChatMessages(_chatHistory.first['id']);
      }
    } catch (e) {
      debugPrint('Error loading chats: $e');
      setState(() {
        _isLoadingChats = false;
      });
      // ถ้า error ให้สร้างแชทใหม่
      await _createNewChat();
    }
  }

  Future<void> _loadChatMessages(String chatId) async {
    try {
      setState(() {
        _currentChatId = chatId;
        _messages.clear();
      });

      final messages = await _supabaseService.getMessages(chatId);

      if (messages.isEmpty) {
        // ถ้าไม่มีข้อความ ให้แสดงข้อความต้อนรับ
        setState(() {
          _messages.add(
            ChatMessage(
              text:
                  'สวัสดีครับ! ยินดีต้อนรับสู่ UNAi Chatbot บอกข้อมูลอย่างครบถ้วนเพื่อการตอบคำถามที่ไวขึ้น',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        });
      } else {
        setState(() {
          for (var msg in messages) {
            _messages.add(
              ChatMessage(
                text: msg['content'],
                isUser: msg['is_user'],
                timestamp: DateTime.parse(msg['created_at']),
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading messages: $e');
    }
  }

  Future<void> _createNewChat() async {
    try {
      final chatId = await _supabaseService.createChatSession(
        title: 'New Chat ${_chatHistory.length + 1}',
      );

      // เพิ่มแชทใหม่เข้า list โดยไม่ต้องโหลดใหม่ทั้งหมด (หลีกเลี่ยงการสร้างซ้ำ)
      final newChat = {
        'id': chatId,
        'title': 'New Chat ${_chatHistory.length + 1}',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      setState(() {
        _chatHistory.insert(0, newChat);
        _currentChatId = chatId;
        _messages.clear();
        _messages.add(
          ChatMessage(
            text: 'สวัสดีครับ! ยินดีต้อนรับสู่ UNAi Chatbot',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    } catch (e) {
      debugPrint('Error creating chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create new chat: $e')),
        );
      }
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    // Guest mode doesn't need chat ID
    if (!_isGuestMode && _currentChatId == null) return;

    final messageText = _messageController.text;
    _messageController.clear();

    if (_isGuestMode) {
      // === GUEST MODE ===
      setState(() {
        _guestMessages.add(
          ChatMessage(
            text: messageText,
            isUser: true,
            timestamp: DateTime.now(),
          ),
        );
        // เพิ่ม loading indicator
        _guestMessages.add(
          ChatMessage(text: '...', isUser: false, timestamp: DateTime.now()),
        );
      });
      _scrollToBottom();

      try {
        debugPrint('Calling Edge Function: chat-with-ai');

        // เรียก Edge Function
        final response = await _supabaseService.client.functions.invoke(
          'chat-with-ai',
          body: {
            'message': messageText,
            'chatHistory': _guestMessages
                .where((m) => m.text != '...')
                .map((m) => {'content': m.text, 'isUser': m.isUser})
                .toList(),
          },
        );

        debugPrint('Response status: ${response.status}');
        debugPrint('Response data: ${response.data}');

        // ลบ loading indicator
        setState(() {
          _guestMessages.removeWhere((m) => m.text == '...');
        });

        if (response.status == 200) {
          final data = response.data;
          final aiResponse =
              data['response'] ?? 'ขอโทษครับ ไม่สามารถตอบได้ในขณะนี้';

          setState(() {
            _guestMessages.add(
              ChatMessage(
                text: aiResponse,
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
          });
        } else {
          // แสดง error
          final errorMsg = response.data?['error'] ?? 'เกิดข้อผิดพลาด';
          setState(() {
            _guestMessages.add(
              ChatMessage(
                text: 'ขอโทษครับ เกิดข้อผิดพลาด: $errorMsg',
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
          });
        }
      } catch (e) {
        debugPrint('Error calling AI: $e');
        setState(() {
          _guestMessages.removeWhere((m) => m.text == '...');
          _guestMessages.add(
            ChatMessage(
              text: 'ขอโทษครับ เกิดข้อผิดพลาด: ${e.toString()}',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        });
      }
      _scrollToBottom();
    } else {
      // === AUTHENTICATED MODE ===
      setState(() {
        _messages.add(
          ChatMessage(
            text: messageText,
            isUser: true,
            timestamp: DateTime.now(),
          ),
        );
        // เพิ่ม loading indicator
        _messages.add(
          ChatMessage(text: '...', isUser: false, timestamp: DateTime.now()),
        );
      });

      // Save user message to database
      try {
        await _supabaseService.addMessage(
          sessionId: _currentChatId!,
          content: messageText,
          isUser: true,
        );
      } catch (e) {
        debugPrint('Error saving user message: $e');
      }

      _scrollToBottom();

      try {
        debugPrint('Calling Edge Function: chat-with-ai');

        // เรียก Edge Function
        final response = await _supabaseService.client.functions.invoke(
          'chat-with-ai',
          body: {
            'message': messageText,
            'chatHistory': _messages
                .where((m) => m.text != '...')
                .map((m) => {'content': m.text, 'isUser': m.isUser})
                .toList(),
          },
        );

        debugPrint('Response status: ${response.status}');
        debugPrint('Response data: ${response.data}');

        // ลบ loading indicator
        setState(() {
          _messages.removeWhere((m) => m.text == '...');
        });

        if (response.status == 200) {
          final data = response.data;
          final aiResponse =
              data['response'] ?? 'ขอโทษครับ ไม่สามารถตอบได้ในขณะนี้';

          setState(() {
            _messages.add(
              ChatMessage(
                text: aiResponse,
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
          });

          // Save bot message to database
          try {
            await _supabaseService.addMessage(
              sessionId: _currentChatId!,
              content: aiResponse,
              isUser: false,
            );

            // โหลดรายการแชทใหม่เพื่อออัพเดทลำดับ
            final chats = await _supabaseService.getChatSessions();
            setState(() {
              _chatHistory = chats;
            });
          } catch (e) {
            debugPrint('Error saving bot message: $e');
          }
        } else {
          // แสดง error
          final errorMsg = response.data?['error'] ?? 'เกิดข้อผิดพลาด';
          setState(() {
            _messages.add(
              ChatMessage(
                text: 'ขอโทษครับ เกิดข้อผิดพลาด: $errorMsg',
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
          });
        }
      } catch (e) {
        debugPrint('Error calling AI: $e');
        setState(() {
          _messages.removeWhere((m) => m.text == '...');
          _messages.add(
            ChatMessage(
              text: 'ขอโทษครับ เกิดข้อผิดพลาด: ${e.toString()}',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        });
      }

      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// =========================================
  /// SETTINGS DIALOG
  /// =========================================
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            final colors = themeProvider.colors;
            return Dialog(
              backgroundColor: colors.dialogBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(32),
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SETTING',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Admin Dashboard Button (Only for Admin)
                    if (_isAdmin)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AdminDashboard(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.buttonSecondary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'ADMIN DASHBOARD',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Profile Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showProfileDialog();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.buttonSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'PROFILE',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Account Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAccountDialog();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.buttonSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'ACCOUNT',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Theme Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showThemeDialog();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.buttonSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'THEME',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Cancel Button
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'CANCEL',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// =========================================
  /// PROFILE DIALOG
  /// =========================================
  void _showProfileDialog() {
    final TextEditingController usernameController = TextEditingController(
      text: _username,
    );
    bool isEditingUsername = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            final colors = themeProvider.colors;
            return StatefulBuilder(
              builder: (context, setState) {
                return Dialog(
                  backgroundColor: colors.dialogBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'PROFILE',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Username Section
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: colors.inputField,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'USERNAME',
                                      style: TextStyle(
                                        color: colors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    isEditingUsername
                                        ? TextField(
                                            controller: usernameController,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                            ),
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              isDense: true,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                            autofocus: true,
                                          )
                                        : Text(
                                            _username,
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontSize: 16,
                                            ),
                                          ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  isEditingUsername ? Icons.check : Icons.edit,
                                  color: colors.textSecondary,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (isEditingUsername) {
                                      this.setState(() {
                                        _username = usernameController.text;
                                      });
                                    }
                                    isEditingUsername = !isEditingUsername;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Email Section
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: colors.inputField,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'EMAIL',
                                      style: TextStyle(
                                        color: colors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _email,
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.lock,
                                color: colors.textSecondary,
                                size: 20,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _showSettingsDialog();
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 12,
                                ),
                              ),
                              child: Text(
                                'CANCEL',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                final newUsername = usernameController.text
                                    .trim();

                                if (newUsername.isEmpty) {
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text('Username cannot be empty'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                // Show loading
                                Navigator.pop(context);
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Saving...'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );

                                try {
                                  // Save to Supabase
                                  await _supabaseService.updateUserProfile(
                                    username: newUsername,
                                  );

                                  // Update local state
                                  this.setState(() {
                                    _username = newUsername;
                                  });

                                  if (mounted) {
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Profile saved successfully',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to save profile: $e',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.buttonPrimary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'SAVE',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// =========================================
  /// ACCOUNT DIALOG
  /// =========================================
  void _showAccountDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            final colors = themeProvider.colors;
            return Dialog(
              backgroundColor: colors.dialogBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(32),
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ACCOUNT',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Logout Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);

                          final shouldLogout = await showDialog<bool>(
                            context: this.context,
                            builder: (context) => Consumer<ThemeProvider>(
                              builder: (context, themeProvider, child) {
                                final colors = themeProvider.colors;
                                return Dialog(
                                  backgroundColor: colors.dialogBackground,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(32),
                                    constraints: const BoxConstraints(
                                      maxWidth: 400,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'LOGOUT',
                                          style: TextStyle(
                                            color: colors.textPrimary,
                                            fontSize: 24,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        Text(
                                          'Do you want to log out?',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: colors.textPrimary,
                                            fontSize: 16,
                                            height: 1.5,
                                          ),
                                        ),
                                        const SizedBox(height: 32),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              style: TextButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 32,
                                                      vertical: 12,
                                                    ),
                                              ),
                                              child: Text(
                                                'CANCEL',
                                                style: TextStyle(
                                                  color: colors.textSecondary,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 32,
                                                      vertical: 12,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: const Text(
                                                'LOGOUT',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          );

                          if (shouldLogout == true && mounted) {
                            try {
                              await SupabaseService().signOut();
                              if (!mounted) return;
                              Navigator.pushAndRemoveUntil(
                                this.context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                                (route) => false,
                              );
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to logout: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'LOGOUT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Delete Account Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showDeleteAccountConfirmation();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.buttonPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'DELETE ACCOUNT',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Cancel Button
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showSettingsDialog();
                      },
                      child: Text(
                        'CANCEL',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// =========================================
  /// DELETE ACCOUNT CONFIRMATION
  /// =========================================
  void _showDeleteAccountConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            final colors = themeProvider.colors;
            return Dialog(
              backgroundColor: colors.dialogBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(32),
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'DELETE ACCOUNT',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Deleting your account is permanent. You will have no way of recovering your account or conversation data.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _showAccountDialog();
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                          ),
                          child: Text(
                            'CANCEL',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _deleteUserAccount();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'DELETE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// =========================================
  /// DELETE USER ACCOUNT
  /// =========================================
  Future<void> _deleteUserAccount() async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deleting account...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Delete account
      await _supabaseService.deleteUserAccount();

      // Navigate to login screen
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// =========================================
  /// THEME DIALOG
  /// =========================================
  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            final colors = themeProvider.colors;
            return Dialog(
              backgroundColor: colors.dialogBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(32),
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SELECT THEME',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Light Theme Option
                    _buildThemeOption(
                      context,
                      themeProvider,
                      AppTheme.light,
                      'LIGHT THEME',
                      'สีขาว - ธีมสว่าง',
                      colors,
                    ),

                    const SizedBox(height: 16),

                    // Blue Theme Option
                    _buildThemeOption(
                      context,
                      themeProvider,
                      AppTheme.blue,
                      'BLUE THEME',
                      'สีน้ำเงิน - ธีมฟ้า',
                      colors,
                    ),

                    const SizedBox(height: 16),

                    // Dark Theme Option
                    _buildThemeOption(
                      context,
                      themeProvider,
                      AppTheme.dark,
                      'DARK THEME',
                      'สีดำ - ธีมมืด',
                      colors,
                    ),

                    const SizedBox(height: 32),

                    // Close Button
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.buttonPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'CLOSE',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    ThemeProvider themeProvider,
    AppTheme theme,
    String title,
    String subtitle,
    ThemeColors colors,
  ) {
    final isSelected = themeProvider.currentTheme == theme;
    return InkWell(
      onTap: () {
        themeProvider.setTheme(theme);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.buttonPrimary.withValues(alpha: 0.2)
              : colors.buttonSecondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colors.buttonPrimary : colors.divider,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? colors.buttonPrimary : colors.textSecondary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: colors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// =========================================
  /// EDIT CHAT DIALOG
  /// =========================================
  void _showEditChatDialog(String chatTitle) {
    final TextEditingController chatNameController = TextEditingController(
      text: chatTitle,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF0a1e5e),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(32),
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'EDIT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1e3a8a),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: chatNameController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      const Icon(Icons.edit, color: Colors.white70, size: 20),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // หา chatId จาก chatTitle
                        final chat = _chatHistory.firstWhere(
                          (c) => c['title'] == chatTitle,
                          orElse: () => {},
                        );
                        if (chat.isEmpty) return;

                        final chatId = chat['id'];

                        showDialog(
                          context: this.context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              backgroundColor: const Color(0xFF0a1e5e),
                              title: const Text(
                                'Delete Chat?',
                                style: TextStyle(color: Colors.white),
                              ),
                              content: Text(
                                'Do you want to delete "$chatTitle"?',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    final scaffoldMessenger =
                                        ScaffoldMessenger.of(this.context);
                                    final navigator = Navigator.of(context);
                                    try {
                                      await _supabaseService.deleteChatSession(
                                        chatId,
                                      );
                                      await _loadChatsFromDatabase();
                                      if (!mounted) return;
                                      navigator.pop();
                                      scaffoldMessenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Deleted $chatTitle successfully',
                                          ),
                                        ),
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      navigator.pop();
                                      scaffoldMessenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to delete chat: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      icon: const Icon(Icons.delete, size: 20),
                      label: const Text('DELETE'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        // หา chatId จาก chatTitle
                        final chat = _chatHistory.firstWhere(
                          (c) => c['title'] == chatTitle,
                          orElse: () => {},
                        );
                        if (chat.isEmpty) return;

                        final chatId = chat['id'];

                        final scaffoldMessenger = ScaffoldMessenger.of(
                          this.context,
                        );
                        final navigator = Navigator.of(context);
                        try {
                          await _supabaseService.updateChatSession(
                            chatId,
                            chatNameController.text,
                          );
                          await _loadChatsFromDatabase();
                          if (!mounted) return;
                          navigator.pop();
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Renamed to "${chatNameController.text}" successfully',
                              ),
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          navigator.pop();
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text('Failed to rename chat: $e'),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563eb),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'SAVE',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// =========================================
  /// GUIDE QUESTIONS DIALOG
  /// =========================================
  void _showGuideQuestionsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            final colors = themeProvider.colors;
            return Dialog(
              backgroundColor: colors.dialogBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(32),
                constraints: const BoxConstraints(
                  maxWidth: 600,
                  maxHeight: 450,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'GUIDE QUESTIONS',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colors.inputField,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colors.divider.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'การบอกข้อมูลที่ครบถ้วนจะทำให้บอทตอบคำถามได้ดีขึ้น โดยระบุอุปกรณ์ ระบบที่ใช้และอาการที่เกิดและลักษณะไฟ LED\n\nเช่น ใช้ TAG ระบบ บลูทูธ โดยมีอาการคือ ไม่พบ TAG หน้า UI เพียงตัวเดียวและ TAG ไม่มีไฟกระพริบ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          height: 1.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.buttonSecondary,
                        foregroundColor: colors.textPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'CLOSE',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// =========================================
  /// SEARCH CHAT DIALOG
  /// =========================================
  void _showSearchChatDialog() {
    final TextEditingController searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            List<Map<String, dynamic>> filteredChats = _chatHistory
                .where(
                  (chat) => chat['title'].toLowerCase().contains(
                    searchController.text.toLowerCase(),
                  ),
                )
                .toList();

            return Dialog(
              backgroundColor: const Color(0xFF0a1e5e),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                constraints: const BoxConstraints(
                  maxWidth: 500,
                  maxHeight: 600,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'SEARCH CHAT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    TextField(
                      controller: searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'SEARCH CHAT HERE...',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 15,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1a3a8a),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white70,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {});
                      },
                    ),

                    const SizedBox(height: 24),

                    Expanded(
                      child: filteredChats.isEmpty
                          ? Center(
                              child: Text(
                                'No conversations found',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredChats.length,
                              itemBuilder: (context, index) {
                                return InkWell(
                                  onTap: () async {
                                    Navigator.pop(context);
                                    await _loadChatMessages(
                                      filteredChats[index]['id'],
                                    );
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Opened ${filteredChats[index]['title']}',
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1e40af),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      filteredChats[index]['title'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// =========================================
  /// MAIN UI
  /// =========================================
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = themeProvider.colors;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: colors.appBar,
            toolbarHeight: 80,
            leading: _isGuestMode
                ? IconButton(
                    icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  )
                : Builder(
                    builder: (context) => IconButton(
                      icon: Icon(Icons.menu, color: colors.textPrimary),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
            title: Row(
              children: [
                Image.asset('assets/images/unai_logo.png', height: 50),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UNAi Chatbot',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Online',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: _isGuestMode
                ? [
                    // Login and Signup buttons for guests
                    TextButton(
                      onPressed: _navigateToLoginWithGuestData,
                      child: Text(
                        'LOGIN',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _navigateToSignupWithGuestData,
                      child: Text(
                        'SIGN UP',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ]
                : [
                    IconButton(
                      icon: Icon(Icons.settings, color: colors.textPrimary),
                      onPressed: _showSettingsDialog,
                    ),
                  ],
          ),

          drawer: _isGuestMode ? null : _buildDrawer(),

          body: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [colors.backgroundStart, colors.backgroundEnd],
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _isGuestMode
                                ? _guestMessages.length
                                : _messages.length,
                            itemBuilder: (context, index) {
                              final message = _isGuestMode
                                  ? _guestMessages[index]
                                  : _messages[index];
                              return _buildMessageBubble(message, colors);
                            },
                          ),
                        ),
                        _buildInputArea(colors),
                      ],
                    ),
                  ),
                ),
              ),
              // Floating Help Button
              Positioned(
                right: 24,
                bottom: 100,
                child: FloatingActionButton(
                  onPressed: _showGuideQuestionsDialog,
                  backgroundColor: colors.buttonSecondary,
                  child: Icon(
                    Icons.help_outline,
                    color: colors.textPrimary,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// =========================================
  /// DRAWER
  /// =========================================
  Widget _buildDrawer() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = themeProvider.colors;
        return Drawer(
          backgroundColor: colors.drawer,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 40,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.appBar, colors.drawer],
                  ),
                ),
                child: Row(
                  children: [
                    Image.asset('assets/images/unai_logo.png', height: 40),
                    const SizedBox(width: 12),
                    Text(
                      'UNAi Chatbot',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildDrawerButton(
                      icon: Icons.add,
                      label: 'NEW CHAT',
                      onTap: () async {
                        Navigator.pop(context);
                        await _createNewChat();
                      },
                      colors: colors,
                    ),
                    const SizedBox(height: 12),

                    _buildDrawerButton(
                      icon: Icons.search,
                      label: 'SEARCH CHAT',
                      onTap: () {
                        Navigator.pop(context);
                        _showSearchChatDialog();
                      },
                      colors: colors,
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'YOUR CHAT',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),

              Expanded(
                child: _isLoadingChats
                    ? Center(
                        child: CircularProgressIndicator(
                          color: colors.buttonPrimary,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _chatHistory.length,
                        itemBuilder: (context, index) {
                          return _buildChatHistoryItem(
                            _chatHistory[index]['title'],
                            colors,
                          );
                        },
                      ),
              ),

              // Bottom options
              Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: colors.divider)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildDrawerButton(
                        icon: Icons.settings,
                        label: 'SETTING',
                        onTap: () {
                          Navigator.pop(context);
                          _showSettingsDialog();
                        },
                        colors: colors,
                      ),
                      const SizedBox(height: 12),
                      _buildDrawerButton(
                        icon: Icons.logout,
                        label: 'LOGOUT',
                        color: Colors.red,
                        onTap: () async {
                          Navigator.pop(context);

                          final shouldLogout = await showDialog<bool>(
                            context: context,
                            builder: (context) => Dialog(
                              backgroundColor: colors.dialogBackground,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(32),
                                constraints: const BoxConstraints(
                                  maxWidth: 400,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'LOGOUT',
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'Do you want to log out?',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 16,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 32,
                                              vertical: 12,
                                            ),
                                          ),
                                          child: Text(
                                            'CANCEL',
                                            style: TextStyle(
                                              color: colors.textSecondary,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 32,
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Text(
                                            'LOGOUT',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );

                          if (shouldLogout == true && mounted) {
                            try {
                              await SupabaseService().signOut();
                              if (!mounted) return;
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                                (route) => false,
                              );
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to logout: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                        colors: colors,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrawerButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ThemeColors colors,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color ?? colors.buttonSecondary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: colors.textPrimary, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatHistoryItem(String title, ThemeColors colors) {
    return InkWell(
      onTap: () async {
        Navigator.pop(context);
        // หา chatId จาก title
        final chat = _chatHistory.firstWhere(
          (c) => c['title'] == title,
          orElse: () => {},
        );
        if (chat.isNotEmpty) {
          await _loadChatMessages(chat['id']);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: colors.inputField,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colors.divider.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.more_vert,
                color: colors.textSecondary,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                _showEditChatDialog(title);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// =========================================
  /// MESSAGE BUBBLE UI
  /// =========================================
  Widget _buildMessageBubble(ChatMessage message, ThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: message.isUser
                ? colors.buttonSecondary
                : Colors.white,
            radius: 24,
            child: message.isUser
                ? Icon(Icons.person, color: colors.textPrimary, size: 26)
                : Image.asset(
                    'assets/images/unai_logo.png',
                    width: 32,
                    height: 32,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: message.isUser ? colors.userBubble : colors.botBubble,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser
                      ? Colors.white
                      : (colors.botBubble.computeLuminance() > 0.5
                            ? Colors.black87
                            : Colors.white),
                  fontSize: 18,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// =========================================
  /// INPUT AREA
  /// =========================================
  Widget _buildInputArea(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.inputArea,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: TextStyle(color: colors.textPrimary, fontSize: 17),
                  decoration: InputDecoration(
                    hintText: 'TYPE YOUR MESSAGE HERE...',
                    hintStyle: TextStyle(
                      color: colors.textSecondary.withValues(alpha: 0.7),
                      fontSize: 17,
                    ),
                    filled: true,
                    fillColor: colors.inputField,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: colors.buttonSecondary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.send, color: colors.textPrimary),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'UNAi Chatbot can make mistakes. Please verify important information.',
            style: TextStyle(
              color: colors.textSecondary.withValues(alpha: 0.6),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Guest mode navigation methods
  Future<void> _navigateToLoginWithGuestData() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoginScreen(guestMessages: _guestMessages),
      ),
    );

    // If login successful, navigate to authenticated chat
    if (result == true && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const ChatScreen(isGuest: false),
        ),
      );
    }
  }

  Future<void> _navigateToSignupWithGuestData() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SignupScreen(guestMessages: _guestMessages),
      ),
    );

    // If signup successful
    if (result == true && mounted) {
      // User will need to verify email, so navigate to Login
      await _navigateToLoginWithGuestData();
    }
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
