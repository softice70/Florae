import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../data/journal.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({Key? key}) : super(key: key);

  @override
  _JournalScreenState createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  List<JournalEntry> _journalEntries = [];
  bool _isLoading = true;
  int _expandedId = -1; // 当前展开的随笔ID
  int _editingId = -1; // 当前编辑的随笔ID
  TextEditingController _editController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadJournalEntries();
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  // 从SharedPreferences加载随笔数据
  Future<void> _loadJournalEntries() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? journalJson = prefs.getString('journal_entries');

      if (journalJson != null) {
        List<dynamic> jsonList = json.decode(journalJson);
        _journalEntries = jsonList
            .map((entry) => JournalEntry.fromJson(entry))
            .toList()
            .reversed
            .toList();
      }
    } catch (e) {
      print('Failed to load journal entries: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 保存随笔数据到SharedPreferences
  Future<void> _saveJournalEntries() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String journalJson =
          json.encode(_journalEntries.map((entry) => entry.toJson()).toList());
      await prefs.setString('journal_entries', journalJson);
    } catch (e) {
      print('Failed to save journal entries: $e');
    }
  }

  // 添加新随笔
  void _addNewEntry() {
    JournalEntry newEntry = JournalEntry(
      id: DateTime.now().millisecondsSinceEpoch,
      createdAt: DateTime.now(),
      content: '',
    );

    setState(() {
      _journalEntries.insert(0, newEntry);
      _expandedId = newEntry.id;
      _startEditing(newEntry.id);
    });

    _saveJournalEntries();
  }

  // 删除随笔
  void _deleteEntry(int id) {
    setState(() {
      _journalEntries.removeWhere((entry) => entry.id == id);
      if (_expandedId == id) {
        _expandedId = -1;
      }
      if (_editingId == id) {
        _editingId = -1;
      }
    });
    _saveJournalEntries();
  }

  // 开始编辑随笔
  void _startEditing(int id) {
    JournalEntry? entry = _journalEntries.firstWhere(
      (entry) => entry.id == id,
      orElse: () => JournalEntry(id: 0, createdAt: DateTime.now(), content: ''),
    );

    _editController.text = entry.content;
    setState(() {
      _editingId = id;
    });
  }

  // 取消编辑
  void _cancelEditing() {
    setState(() {
      _editingId = -1;
    });
  }

  // 保存编辑
  void _saveEditing() {
    setState(() {
      for (int i = 0; i < _journalEntries.length; i++) {
        if (_journalEntries[i].id == _editingId) {
          _journalEntries[i] = JournalEntry(
            id: _journalEntries[i].id,
            createdAt: _journalEntries[i].createdAt,
            content: _editController.text,
          );
          break;
        }
      }
      _editingId = -1;
    });
    _saveJournalEntries();
  }

  // 切换展开/收起状态
  void _toggleExpanded(int id) {
    setState(() {
      _expandedId = _expandedId == id ? -1 : id;
    });
  }

  // 按月份分组显示随笔
  Widget _buildJournalList() {
    if (_journalEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book, size: 80, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text('暂无养护随笔', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 8),
            Text('点击右下角的“+”按钮添加新随笔',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    // 按月份分组
    Map<String, List<JournalEntry>> groupedEntries = {};
    for (JournalEntry entry in _journalEntries) {
      String monthKey = entry.getMonthTitle();
      if (!groupedEntries.containsKey(monthKey)) {
        groupedEntries[monthKey] = [];
      }
      groupedEntries[monthKey]!.add(entry);
    }

    return ListView.builder(
      itemCount: groupedEntries.keys.length,
      itemBuilder: (context, index) {
        String monthTitle = groupedEntries.keys.elementAt(index);
        List<JournalEntry> monthEntries = groupedEntries[monthTitle]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 月份标题
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
              child: Text(
                monthTitle,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            // 该月的随笔列表
            ...monthEntries.map((entry) {
              bool isExpanded = _expandedId == entry.id;
              bool isEditing = _editingId == entry.id;

              // 获取随笔前n个字作为预览
              String previewText = entry.content.length > 30
                  ? '${entry.content.substring(0, 30)}...'
                  : entry.content;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 随笔标题行
                    InkWell(
                      onTap: () => _toggleExpanded(entry.id),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Text(entry.getDateTimeFormat()),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                previewText.isEmpty ? '无内容' : previewText,
                                style: TextStyle(color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              isExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 展开的详细内容
                    if (isExpanded) ...[
                      Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: isEditing
                            ? TextField(
                                controller: _editController,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: '输入你的养护随笔...',
                                ),
                                maxLines: 10,
                                minLines: 3,
                                keyboardType: TextInputType.multiline,
                              )
                            : MarkdownBody(
                                data: entry.content.isEmpty
                                    ? '无内容'
                                    : entry.content,
                                styleSheet: MarkdownStyleSheet.fromTheme(
                                    Theme.of(context)),
                              ),
                      ),
                      // 操作按钮
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: isEditing
                              ? [
                                  TextButton(
                                    onPressed: _cancelEditing,
                                    child: Text('取消'),
                                  ),
                                  SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _saveEditing,
                                    child: Text('保存'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .secondary,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ]
                              : [
                                  TextButton(
                                    onPressed: () => _startEditing(entry.id),
                                    child: Text('编辑'),
                                  ),
                                  SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () => _deleteEntry(entry.id),
                                    child: Text('删除'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                  ),
                                ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        title: FittedBox(fit: BoxFit.fitWidth, child: Text('养护随笔')),
        titleTextStyle: Theme.of(context).textTheme.displayLarge,
        backgroundColor: Colors.transparent,
        elevation: 0.0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildJournalList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewEntry,
        tooltip: '添加新随笔',
        child: Icon(Icons.add),
        backgroundColor: Theme.of(context).colorScheme.secondary,
      ),
    );
  }
}
