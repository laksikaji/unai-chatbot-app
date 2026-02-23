import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';
import 'supabase_service.dart';
import 'home_screen.dart';
import 'chat_screen.dart';
import '../services/system_settings_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _isSyncing = false;
  bool _isUploading = false;

  // AI Model Settings
  bool _isLoadingModel = false;
  String _currentAiProvider = 'gemini'; // Default
  final _systemSettingsService = SystemSettingsService();

  Map<String, dynamic>? _lastSyncData;
  final _supabaseService = SupabaseService();

  // Team Contacts
  List<Map<String, dynamic>> _teamContacts = [];
  bool _isLoadingContacts = false;

  @override
  void initState() {
    super.initState();
    _loadSystemSettings();
    _loadTeamContacts();
  }

  Future<void> _loadSystemSettings() async {
    setState(() => _isLoadingModel = true);
    try {
      final provider = await _systemSettingsService.getAiProvider();
      if (mounted) {
        setState(() {
          _currentAiProvider = provider;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingModel = false);
    }
  }

  Future<void> _updateAiProvider(String provider) async {
    if (provider == _currentAiProvider) return;

    setState(() => _isLoadingModel = true);
    try {
      await _systemSettingsService.updateAiProvider(provider);
      if (mounted) {
        setState(() {
          _currentAiProvider = provider;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI Provider switched to ${provider.toUpperCase()}'),
            backgroundColor: provider == 'groq' ? Colors.orange : Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingModel = false);
    }
  }

  // ── Team Contacts ──────────────────────────────────────────
  Future<void> _loadTeamContacts() async {
    setState(() => _isLoadingContacts = true);
    final contacts = await _supabaseService.getTeamContacts();
    if (mounted) {
      setState(() {
        _teamContacts = contacts;
        _isLoadingContacts = false;
      });
    }
  }

  Future<void> _showContactDialog({Map<String, dynamic>? contact}) async {
    final firstNameCtrl = TextEditingController(
      text: contact?['first_name'] ?? '',
    );
    final lastNameCtrl = TextEditingController(
      text: contact?['last_name'] ?? '',
    );
    final phoneCtrl = TextEditingController(text: contact?['phone'] ?? '');
    final isEdit = contact != null;

    await showDialog(
      context: context,
      builder: (ctx) => Consumer<ThemeProvider>(
        builder: (ctx, themeProvider, _) {
          final colors = themeProvider.colors;
          return Dialog(
            backgroundColor: colors.dialogBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(28),
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEdit ? 'Edit Contact' : 'Add Contact',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildContactTextField(
                    colors,
                    firstNameCtrl,
                    'First Name',
                    Icons.person,
                  ),
                  const SizedBox(height: 12),
                  _buildContactTextField(
                    colors,
                    lastNameCtrl,
                    'Last Name',
                    Icons.person_outline,
                  ),
                  const SizedBox(height: 12),
                  _buildContactTextField(
                    colors,
                    phoneCtrl,
                    'Phone',
                    Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: colors.textSecondary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.buttonPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            final firstName = firstNameCtrl.text.trim();
                            final lastName = lastNameCtrl.text.trim();
                            final phone = phoneCtrl.text.trim();
                            if (firstName.isEmpty ||
                                lastName.isEmpty ||
                                phone.isEmpty) {
                              return;
                            }
                            Navigator.pop(ctx);
                            try {
                              if (isEdit) {
                                await _supabaseService.updateTeamContact(
                                  id: contact['id'],
                                  firstName: firstName,
                                  lastName: lastName,
                                  phone: phone,
                                );
                              } else {
                                await _supabaseService.addTeamContact(
                                  firstName: firstName,
                                  lastName: lastName,
                                  phone: phone,
                                );
                              }
                              await _loadTeamContacts();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          child: Text(
                            'Save',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
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
  }

  Future<void> _confirmDeleteContact(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Consumer<ThemeProvider>(
        builder: (ctx, themeProvider, _) {
          final colors = themeProvider.colors;
          return AlertDialog(
            backgroundColor: colors.dialogBackground,
            title: Text(
              'Delete Contact',
              style: TextStyle(color: colors.textPrimary),
            ),
            content: Text(
              'Remove "$name" from the system?',
              style: TextStyle(color: colors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed == true) {
      try {
        await _supabaseService.deleteTeamContact(id);
        await _loadTeamContacts();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _buildContactTextField(
    ThemeColors colors,
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: colors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors.textSecondary),
        prefixIcon: Icon(icon, color: colors.textSecondary, size: 20),
        filled: true,
        fillColor: colors.inputField,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),
      ),
    );
  }

  // Sync Google Sheets
  Future<void> _syncGoogleSheets() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      final response = await _supabaseService.client.functions.invoke(
        'sync-google-sheets',
      );

      if (response.status == 200) {
        setState(() {
          _lastSyncData = response.data;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Synced ${response.data['records']} records!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(response.data['error'] ?? 'Sync failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  // Upload File
  Future<void> _uploadFile() async {
    try {
      // Pick file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
      );

      if (result == null) return;

      setState(() {
        _isUploading = true;
      });

      final fileBytes = result.files.first.bytes;
      final fileName =
          'upload_${DateTime.now().millisecondsSinceEpoch}.${result.files.first.extension}';

      if (fileBytes == null) {
        throw Exception('Failed to read file');
      }

      // Upload to Supabase Storage
      await _supabaseService.client.storage
          .from('admin-uploads')
          .uploadBinary(fileName, fileBytes);

      // Process file
      final response = await _supabaseService.client.functions.invoke(
        'process-file-upload',
        body: {'fileName': fileName},
      );

      if (response.status == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Uploaded! Processed ${response.data['records']} records',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(response.data['error'] ?? 'Upload failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  // Clear All Data
  Future<void> _clearAllData() async {
    // Show confirmation dialog
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          final colors = themeProvider.colors;
          return AlertDialog(
            backgroundColor: colors.dialogBackground,
            title: Text(
              'Clear All Data',
              style: TextStyle(color: colors.textPrimary),
            ),
            content: Text(
              'Are you sure you want to delete ALL knowledge base data? This action cannot be undone.',
              style: TextStyle(color: colors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Delete All',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (shouldClear != true) return;

    try {
      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deleting all data...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Call Supabase Edge Function to delete all data
      final response = await _supabaseService.client.functions.invoke(
        'clear-troubleshooting-data',
      );

      if (response.status == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All data deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(response.data['error'] ?? 'Clear data failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Show File Format Guide
  void _showFileFormatGuide() {
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
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'FILE FORMAT GUIDE',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: colors.inputField,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'รองรับไฟล์ CSV และ Excel (.xlsx, .xls)\nโดยในแถวแรกต้องมีหัวข้อครบตามนี้',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 15,
                              height: 1.6,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'ประเภทหลัก | ประเภท | อาการ | ข้อสังเกตุ | ตรวจสอบเบื้องต้น | สาเหตุที่อาจเป็นไปได้ | วิธีแก้ | ผู้แก้ปัญหาเบื้องต้น',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 14,
                              height: 1.8,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 120,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.buttonSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
                            letterSpacing: 1.0,
                          ),
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

  // Logout
  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          final colors = themeProvider.colors;
          return AlertDialog(
            backgroundColor: colors.dialogBackground,
            title: Text('Logout', style: TextStyle(color: colors.textPrimary)),
            content: Text(
              'Do you want to log out?',
              style: TextStyle(color: colors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (shouldLogout == true && mounted) {
      await _supabaseService.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = themeProvider.colors;
        return Scaffold(
          appBar: AppBar(
            iconTheme: IconThemeData(color: colors.textPrimary),
            toolbarHeight: 80,
            backgroundColor: colors.appBar,
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
                      'Admin Dashboard',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.settings, color: colors.textPrimary),
                onPressed: _showSettingsDialog,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [colors.backgroundStart, colors.backgroundEnd],
              ),
            ),
            child: Scrollbar(
              thumbVisibility: true,
              thickness: 8,
              radius: const Radius.circular(4),
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Sync Google Sheets Card
                          _buildSyncCard(colors),
                          const SizedBox(height: 16),

                          // Upload File Card
                          _buildUploadCard(colors),
                          const SizedBox(height: 16),

                          // Clear Data Card
                          _buildClearDataCard(colors),
                          const SizedBox(height: 16),

                          // AI Model Card
                          _buildAiModelCard(colors),
                          const SizedBox(height: 16),

                          // Team Contacts Card
                          _buildTeamContactsCard(colors),
                          const SizedBox(height: 16),

                          // API Usage Section
                          _buildApiUsageSection(colors),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _showFileFormatGuide,
            backgroundColor: colors.buttonSecondary,
            child: Icon(
              Icons.help_outline,
              color: colors.textPrimary,
              size: 28,
            ),
          ),
        );
      },
    );
  }

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

                    // Chat Page Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ChatScreen(),
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
                          'CHAT PAGE',
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

                    const SizedBox(height: 16),

                    // Logout Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _logout();
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

                    // Scrollable Area (Height for approx 4 items)
                    SizedBox(
                      height: 320, // Approx height for 4 items
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            // Blue Theme Option
                            _buildThemeOption(
                              context,
                              themeProvider,
                              AppTheme.blue,
                              'BLUE THEME',
                              'สีน้ำเงิน - ธีมทะเล',
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
                            const SizedBox(height: 16),

                            // Green Theme Option
                            _buildThemeOption(
                              context,
                              themeProvider,
                              AppTheme.green,
                              'GREEN THEME',
                              'สีเขียว - ธีมป่าไม้',
                              colors,
                            ),
                            const SizedBox(height: 16),

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

                            // Orange Theme Option
                            _buildThemeOption(
                              context,
                              themeProvider,
                              AppTheme.orange,
                              'ORANGE THEME',
                              'สีส้ม - ธีมสดใส',
                              colors,
                            ),
                            const SizedBox(height: 16),

                            // Pink Theme Option
                            _buildThemeOption(
                              context,
                              themeProvider,
                              AppTheme.pink,
                              'PINK THEME',
                              'สีชมพู - ธีมน่ารัก',
                              colors,
                            ),
                            const SizedBox(height: 16),

                            // Purple Theme Option
                            _buildThemeOption(
                              context,
                              themeProvider,
                              AppTheme.purple,
                              'PURPLE THEME',
                              'สีม่วง - ธีมลึกลับ',
                              colors,
                            ),
                            const SizedBox(height: 16),

                            // Red Theme Option
                            _buildThemeOption(
                              context,
                              themeProvider,
                              AppTheme.red,
                              'RED THEME',
                              'สีแดง - ธีมร้อนแรง',
                              colors,
                            ),
                            const SizedBox(height: 16),

                            // Sky Theme Option
                            _buildThemeOption(
                              context,
                              themeProvider,
                              AppTheme.sky,
                              'SKY THEME',
                              'สีฟ้า - ธีมท้องฟ้า',
                              colors,
                            ),
                            const SizedBox(height: 16),

                            // Yellow Theme Option
                            _buildThemeOption(
                              context,
                              themeProvider,
                              AppTheme.yellow,
                              'YELLOW THEME',
                              'สีเหลือง - ธีมอบอุ่น',
                              colors,
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildSyncCard(ThemeColors colors) {
    return Card(
      color: colors.inputField,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sync, color: colors.textPrimary, size: 32),
                const SizedBox(width: 12),
                Text(
                  'Sync Google Sheets',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _lastSyncData != null
                  ? 'Last sync: ${_lastSyncData!['records']} records'
                  : 'Not synced yet',
              style: TextStyle(color: colors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSyncing ? null : _syncGoogleSheets,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.buttonSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSyncing
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: colors.textPrimary,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'SYNC NOW',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard(ThemeColors colors) {
    return Card(
      color: colors.inputField,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.upload_file, color: colors.textPrimary, size: 32),
                const SizedBox(width: 12),
                Text(
                  'Upload File',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Upload CSV or Excel file directly (instant update)',
              style: TextStyle(color: colors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _uploadFile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.buttonSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isUploading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: colors.textPrimary,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'UPLOAD FILE',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClearDataCard(ThemeColors colors) {
    return Card(
      color: colors.inputField,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.delete_forever, color: Colors.red, size: 32),
                const SizedBox(width: 12),
                Text(
                  'Clear Data',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Delete all knowledge base data from database',
              style: TextStyle(color: colors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _clearAllData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'CLEAR ALL DATA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiModelCard(ThemeColors colors) {
    return Card(
      color: colors.inputField,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.backgroundStart.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('🧠', style: TextStyle(fontSize: 32)),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Provider',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select AI model for chat responses',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                if (_isLoadingModel) const Spacer(),
                if (_isLoadingModel)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.textPrimary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.backgroundStart,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.divider.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildModelOption(
                      title: 'Groq',
                      value: 'groq',
                      icon: Icons.bolt,
                      color: Colors.orange,
                      isSelected: _currentAiProvider == 'groq',
                      colors: colors,
                    ),
                  ),
                  Expanded(
                    child: _buildModelOption(
                      title: 'Gemini',
                      value: 'gemini',
                      icon: Icons.auto_awesome,
                      color: Colors.blueAccent,
                      isSelected: _currentAiProvider == 'gemini',
                      colors: colors,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmbeddingUsageCard(
    ThemeColors colors,
    Map<int, Map<String, dynamic>> latestLogs,
  ) {
    return Card(
      color: colors.inputField,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.memory, color: Colors.purpleAccent, size: 32),
                const SizedBox(width: 12),
                Text(
                  'Embedding Usage',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Used for searching knowledge base (Always active)',
              style: TextStyle(color: colors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            _buildUsageRow(
              colors,
              'Key #1',
              21,
              latestLogs,
            ), // Index 21 for Embedding
          ],
        ),
      ),
    );
  }

  Widget _buildGroqUsageCard(
    ThemeColors colors,
    Map<int, Map<String, dynamic>> latestLogs,
  ) {
    return Card(
      color: colors.inputField,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flash_on, color: Colors.orange, size: 32),
                const SizedBox(width: 12),
                Text(
                  'Groq Usage',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Column(
              children: List.generate(5, (index) {
                final keyIndex = index + 1; // Groq 1-5
                return _buildUsageRow(
                  colors,
                  'Key #$keyIndex',
                  keyIndex,
                  latestLogs,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeminiChatUsageCard(
    ThemeColors colors,
    Map<int, Map<String, dynamic>> latestLogs,
  ) {
    return Card(
      color: colors.inputField,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: Colors.blueAccent,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  'Gemini Usage',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Column(
              children: List.generate(5, (index) {
                final keyIndex = index + 11; // Gemini Chat 11-15
                return _buildUsageRow(
                  colors,
                  'Key #${index + 1}',
                  keyIndex,
                  latestLogs,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageRow(
    ThemeColors colors,
    String label,
    int backendKeyIndex,
    Map<int, Map<String, dynamic>> latestLogs,
  ) {
    final data = latestLogs[backendKeyIndex];
    final requestsRemaining = data?['requests_remaining'] ?? 0;
    final requestsLimit = data?['requests_limit'] ?? 1500; // Default limit
    final percentage = data != null ? requestsRemaining / requestsLimit : 0.0;

    Color progressColor;
    if (percentage > 0.5) {
      progressColor = Colors.green;
    } else if (percentage > 0.2) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.red;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                data != null
                    ? '$requestsRemaining / $requestsLimit'
                    : 'No Data',
                style: TextStyle(
                  color: colors.textPrimary.withValues(alpha: 0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: colors.divider.withValues(alpha: 0.2),
            color: data != null ? progressColor : Colors.grey,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          if (data != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Resets: ${data['reset_time'] ?? '-'}',
                    style: TextStyle(
                      color: colors.textSecondary.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _formatTimestamp(data['timestamp']),
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Team Contacts Card ──────────────────────────────────────
  Widget _buildTeamContactsCard(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.dialogBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0ea5e9).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.contacts_rounded,
                  color: Color(0xFF0ea5e9),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Team Contacts',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Manage contact list for AI responses',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showContactDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Contact'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0ea5e9),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Content
          if (_isLoadingContacts)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_teamContacts.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(
                      Icons.group_off_outlined,
                      size: 48,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No contacts yet.\nPress "Add Contact" to get started.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                // Table header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colors.inputField,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Full Name',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Phone',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 80),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Rows
                ...List.generate(_teamContacts.length, (i) {
                  final c = _teamContacts[i];
                  final fullName = '${c['first_name']} ${c['last_name']}';
                  return Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: i.isEven
                          ? colors.dialogBackground
                          : colors.inputField.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.divider, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(
                                  0xFF0ea5e9,
                                ).withValues(alpha: 0.15),
                                child: Text(
                                  c['first_name'][0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF0ea5e9),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  fullName,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            c['phone'] ?? '-',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: colors.textSecondary,
                              ),
                              tooltip: 'Edit',
                              onPressed: () => _showContactDialog(contact: c),
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: Colors.redAccent,
                              ),
                              tooltip: 'Delete',
                              onPressed: () =>
                                  _confirmDeleteContact(c['id'], fullName),
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildApiUsageSection(ThemeColors colors) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabaseService.client
          .from('api_usage_logs')
          .stream(primaryKey: ['id'])
          .order('timestamp', ascending: false)
          .limit(100), // Increased limit to cover all keys
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(color: colors.textPrimary),
          );
        }

        final logs = snapshot.data!;
        final Map<int, Map<String, dynamic>> latestLogs = {};

        for (var log in logs) {
          final index = log['api_key_index'] as int?;
          if (index != null && !latestLogs.containsKey(index)) {
            latestLogs[index] = log;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Embedding Card
            _buildEmbeddingUsageCard(colors, latestLogs),
            const SizedBox(height: 16),

            // 2. Groq Card
            _buildGroqUsageCard(colors, latestLogs),
            const SizedBox(height: 16),

            // 3. Gemini Chat Card
            _buildGeminiChatUsageCard(colors, latestLogs),
          ],
        );
      },
    );
  }

  Widget _buildModelOption({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required ThemeColors colors,
  }) {
    return GestureDetector(
      onTap: _isLoadingModel ? null : () => _updateAiProvider(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : colors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : colors.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year.toString();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      final second = dt.second.toString().padLeft(2, '0');
      return 'Last active: $day/$month/$year $hour:$minute:$second';
    } catch (e) {
      return '';
    }
  }
}
