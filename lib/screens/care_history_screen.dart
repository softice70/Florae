import 'dart:io';
import 'package:florae/data/care_history.dart';
import 'package:florae/data/plant.dart';
import 'package:florae/data/garden.dart';
import 'package:florae/data/default.dart';
import 'package:florae/l10n/app_localizations.dart';
import 'package:florae/screens/care_plant.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CareHistoryScreen extends StatefulWidget {
  const CareHistoryScreen({super.key});

  @override
  State<CareHistoryScreen> createState() => _CareHistoryScreenState();
}

class _CareHistoryScreenState extends State<CareHistoryScreen> {
  List<Map<String, dynamic>> _careHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCareHistory();
  }

  Future<void> _loadCareHistory() async {
    try {
      final garden = await Garden.load();
      final plants = await garden.getAllPlants();
      Map<DateTime, Map<Plant, List<CareHistory>>> groupedHistory = {};

      // 收集所有养护记录
      for (var plant in plants) {
        for (var history in plant.careHistory) {
          final date = DateTime(
            history.careDate.year,
            history.careDate.month,
            history.careDate.day,
          );

          if (!groupedHistory.containsKey(date)) {
            groupedHistory[date] = {};
          }
          if (!groupedHistory[date]!.containsKey(plant)) {
            groupedHistory[date]![plant] = [];
          }
          groupedHistory[date]![plant]!.add(history);
        }
      }

      // 转换为列表并排序
      final sortedEntries = groupedHistory.entries.toList()
        ..sort((a, b) => b.key.compareTo(a.key));

      setState(() {
        _careHistory = sortedEntries.map((entry) {
          return {
            'date': entry.key,
            'plants': entry.value.entries.map((plantEntry) {
              return {
                'plant': plantEntry.key,
                'histories': plantEntry.value,
              };
            }).toList()
              ..sort((a, b) => (a['plant'] as Plant).name.compareTo((b['plant'] as Plant).name)),
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshHistory() async {
    setState(() {
      _isLoading = true;
    });
    await _loadCareHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.careHistory),
      ),
      body: _isLoading
          ? _buildLoadingIndicator()
          : _careHistory.isEmpty
              ? Center(
                  child: Text(
                    AppLocalizations.of(context)!.mainNoCares,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshHistory,
                  child: ListView.builder(
                    itemCount: _careHistory.length,
                    itemBuilder: (context, index) {
                      final dayData = _careHistory[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                               color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(50),
                              border: Border(
                                bottom: BorderSide(
                                  color: Theme.of(context).dividerColor,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: _buildDateText(dayData['date']),
                          ),
                          ...dayData['plants'].map<Widget>((plantData) {
                            return _buildPlantCareCard(
                              plantData['plant'],
                              plantData['histories'],
                            );
                          }).toList(),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  ),
                ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(date.year, date.month, date.day);

    if (checkDate == today) {
      return '今天';
    } else if (checkDate == yesterday) {
      return '昨天'; // This could be localized if needed
    } else {
      return DateFormat('yyyy-MM-dd').format(date);
    }
  }

  Widget _buildDateText(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final checkDate = DateTime(date.year, date.month, date.day);
    final daysDifference = today.difference(checkDate).inDays;

    String mainText = _formatDate(date);
    
    // 如果是今天，不显示天数差
    if (daysDifference == 0) {
      return Text(
        mainText,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    // 其他日期显示天数差
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: mainText,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          TextSpan(
            text: '     ${daysDifference}天前',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlantImage(Plant plant) {
    if (plant.picture == null || plant.picture!.isEmpty) {
      return Container(
        color: Colors.grey[300],
        child: Icon(Icons.local_florist, color: Colors.grey[600]),
      );
    }

    if (plant.picture!.contains("florae_avatar")) {
      return Image.asset(
        plant.picture!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: Icon(Icons.local_florist, color: Colors.grey[600]),
          );
        },
      );
    } else {
      return Image.file(
        File(plant.picture!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: Icon(Icons.local_florist, color: Colors.grey[600]),
          );
        },
      );
    }
  }

  Widget _buildPlantCareCard(Plant plant, List<CareHistory> histories) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CarePlantScreen(title: plant.name),
              settings: RouteSettings(arguments: plant),
            ),
          );
          // 返回时重新加载数据
          _loadCareHistory();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 左侧：植物缩略图
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: _buildPlantImage(plant),
                ),
              ),
              const SizedBox(width: 12),
              // 右侧：植物名称和养护记录列表
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 第一行：植物名称
                    Text(
                      plant.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // 养护记录列表
                    ...histories.map((history) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 养护类型图标
                            Container(
                              width: 24,
                              height: 24,
                              margin: const EdgeInsets.only(right: 8),
                              child: _getCareIcon(history.careName),
                            ),
                            // 养护详情
                            Expanded(
                              child: history.details != null && history.details!.isNotEmpty
                                  ? RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: _getCareChineseName(history.careName),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(fontWeight: FontWeight.w500),
                                          ),
                                          TextSpan(
                                            text: ' ${history.details}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                          ),
                                        ],
                                      ),
                                    )
                                  : Text(
                                      _getCareChineseName(history.careName),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(fontWeight: FontWeight.w500),
                                    ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCareChineseName(String careName) {
    switch (careName.toLowerCase()) {
      case 'water':
        return '浇水';
      case 'spray':
        return '喷雾';
      case 'rotate':
        return '转动';
      case 'prune':
        return '修剪';
      case 'fertilise':
        return '施肥';
      case 'transplant':
        return '移栽';
      case 'clean':
        return '清洁';
      default:
        return careName;
    }
  }

  Widget _getCareIcon(String careName) {
    final careInfo = DefaultValues.getCare(context, careName);
    final icon = careInfo?.icon ?? Icons.help_outline;
    final color = careInfo?.color ?? Colors.grey;
    
    return Icon(icon, color: color, size: 20);
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context)!.careHistory),
        ],
      ),
    );
  }
}