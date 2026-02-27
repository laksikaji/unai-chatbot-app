import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:data_table_2/data_table_2.dart';
import '../theme_provider.dart';
import '../screens/supabase_service.dart';

class DataPreviewDialog extends StatefulWidget {
  const DataPreviewDialog({super.key});

  @override
  State<DataPreviewDialog> createState() => _DataPreviewDialogState();
}

class _DataPreviewDialogState extends State<DataPreviewDialog> {
  final _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  final List<Map<String, dynamic>> _data = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 5;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) {
      setState(() {
        _offset = 0;
        _data.clear();
        _hasMore = true;
      });
    }

    if (!_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final newData = await _supabaseService.getTroubleshootingData(
        limit: _limit,
        offset: _offset,
        searchQuery: _searchController.text,
      );

      setState(() {
        _data.addAll(newData);
        _offset += newData.length;
        if (newData.length < _limit) {
          _hasMore = false;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearch() {
    FocusScope.of(context).unfocus();
    _loadData(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = themeProvider.colors;
        return Dialog(
          backgroundColor: colors.dialogBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header & Search
                Row(
                  children: [
                    Text(
                      'Data Preview',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 300,
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: colors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          hintStyle: TextStyle(color: colors.textSecondary),
                          prefixIcon: Icon(
                            Icons.search,
                            color: colors.textSecondary,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: colors.textSecondary,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearch();
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: colors.inputField,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: colors.divider),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: colors.divider),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: colors.buttonPrimary,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                        ),
                        onSubmitted: (_) => _onSearch(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.buttonPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _onSearch,
                      child: Text(
                        'Search',
                        style: TextStyle(color: colors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: Icon(Icons.close, color: colors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Content
                Expanded(
                  child: _data.isEmpty && !_isLoading
                      ? Center(
                          child: Text(
                            'No data found.',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: colors.divider),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Scrollbar(
                              controller: _horizontalScrollController,
                              thumbVisibility: true,
                              trackVisibility: true,
                              child: DataTable2(
                                minWidth: 1600,
                                scrollController: _verticalScrollController,
                                horizontalScrollController:
                                    _horizontalScrollController,
                                headingRowColor:
                                    WidgetStateProperty.resolveWith(
                                      (states) => colors.appBar,
                                    ),
                                dataRowColor: WidgetStateProperty.resolveWith(
                                  (states) => colors.dialogBackground,
                                ),
                                headingTextStyle: TextStyle(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                                dataTextStyle: TextStyle(
                                  color: colors.textPrimary,
                                ),
                                columns: const [
                                  DataColumn2(
                                    label: Text('ประเภทหลัก'),
                                    size: ColumnSize.M,
                                  ),
                                  DataColumn2(
                                    label: Text('ประเภท'),
                                    size: ColumnSize.M,
                                  ),
                                  DataColumn2(
                                    label: Text('อาการ'),
                                    size: ColumnSize.L,
                                  ),
                                  DataColumn2(
                                    label: Text('ข้อสังเกตุ'),
                                    size: ColumnSize.L,
                                  ),
                                  DataColumn2(
                                    label: Text('ตรวจสอบเบื้องต้น'),
                                    size: ColumnSize.L,
                                  ),
                                  DataColumn2(
                                    label: Text('สาเหตุที่อาจเป็นไปได้'),
                                    size: ColumnSize.L,
                                  ),
                                  DataColumn2(
                                    label: Text('วิธีแก้'),
                                    size: ColumnSize.L,
                                  ),
                                  DataColumn2(
                                    label: Text('ผู้แก้ปัญหาเบื้องต้น'),
                                    size: ColumnSize.M,
                                  ),
                                ],
                                rows: _data.map((item) {
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          item['category']?.toString() ?? '-',
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          item['subcategory']?.toString() ??
                                              '-',
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          item['symptom_description']
                                                  ?.toString() ??
                                              '-',
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          item['observation']?.toString() ??
                                              '-',
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          item['initial_check']?.toString() ??
                                              '-',
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          item['possible_causes']?.toString() ??
                                              '-',
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          item['solution']?.toString() ?? '-',
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          item['responsible_party']
                                                  ?.toString() ??
                                              '-',
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                ),

                // Footer
                if (_hasMore || _isLoading)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Center(
                      child: _isLoading
                          ? CircularProgressIndicator(
                              color: colors.buttonPrimary,
                            )
                          : ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.buttonSecondary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () => _loadData(),
                              icon: Icon(
                                Icons.expand_more,
                                color: colors.textPrimary,
                              ),
                              label: Text(
                                'Load More',
                                style: TextStyle(color: colors.textPrimary),
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
  }
}
