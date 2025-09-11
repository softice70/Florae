import 'package:florae/data/settings/settings_manager.dart';
import 'package:florae/notifications.dart' as notify;
import 'package:flutter/material.dart';

import '../data/backup/backup_manager.dart';
import '../data/settings/settings.dart';
import '../l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<SettingsScreen> createState() => _SettingsScreen();
}

class _SettingsScreen extends State<SettingsScreen> {
  Settings settings = Settings();

  Future<void> getSettings() async {
    var currentSettings = await SettingsManager.getSettings();
    setState(() {
      settings = currentSettings;
    });
  }

  @override
  void initState() {
    super.initState();
    getSettings();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        automaticallyImplyLeading: false,
        title: FittedBox(
            fit: BoxFit.fitWidth,
            child: Text(AppLocalizations.of(context)!.tooltipSettings)),
        elevation: 0.0,
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        titleTextStyle: Theme.of(context).textTheme.displayLarge,
      ),
      //passing in the ListView.builder
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            children: <Widget>[
              Card(
                semanticContainer: true,
                clipBehavior: Clip.antiAliasWithSaveLayer,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Column(children: <Widget>[
                  ..._buildNotificationHours(),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    subtitle: Transform.translate(
                      offset: const Offset(-10, -5),
                      child:
                          Text(AppLocalizations.of(context)!.notificationInfo),
                    ),
                  ),
                  ListTile(
                      trailing: const Icon(Icons.arrow_right),
                      leading: const Icon(Icons.circle_notifications,
                          color: Colors.red),
                      title: Text(
                          AppLocalizations.of(context)!.testNotificationButton),
                      onTap: () async {
                        try {
                          await notify.singleNotification(
                              AppLocalizations.of(context)!.testNotificationTitle,
                              AppLocalizations.of(context)!.testNotificationBody,
                              2);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('测试通知已发送，请检查通知栏')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('发送失败: $e')),
                          );
                        }
                      }),
                ]),
              ),
              Card(
                  semanticContainer: true,
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Column(children: <Widget>[
                    ListTile(
                        trailing: const Icon(Icons.arrow_right),
                        leading: const Icon(Icons.backup, color: Colors.blueGrey),
                        title: Text(AppLocalizations.of(context)!.exportData),
                        onTap: () async {
                          // 显示加载指示器
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (BuildContext context) {
                              return const AlertDialog(
                                content: Row(
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(width: 20),
                                    Text('正在导出数据...'),
                                  ],
                                ),
                              );
                            },
                          );

                          try {
                            var successfullyBackedUp =
                                await BackupManager.backup();
                            
                            // 关闭加载指示器
                            Navigator.of(context).pop();
                            
                            if (successfullyBackedUp) {
                              // 显示成功对话框
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    icon: const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 48,
                                    ),
                                    title: const Text('导出成功'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('花园数据已成功导出！'),
                                        const SizedBox(height: 8),
                                        Text(
                                          '导出内容包括植物信息、养护记录和图片',
                                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text('确定'),
                                      ),
                                    ],
                                  );
                                },
                              );
                              
                              // 同时显示简短的 SnackBar
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text('数据导出成功'),
                                    ],
                                  ),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('导出失败：用户取消了操作或没有存储权限'),
                                  backgroundColor: Colors.orange,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          } catch (e) {
                            // 关闭加载指示器
                            Navigator.of(context).pop();
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('导出过程中发生错误：$e'),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        }),
                    ListTile(
                        trailing: const Icon(Icons.arrow_right),
                        leading: const Icon(Icons.restore_outlined,
                            color: Colors.blueGrey),
                        title: Text(AppLocalizations.of(context)!.importData),
                        onTap: () async {
                          // 显示确认对话框
                          bool? shouldProceed = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                icon: const Icon(
                                  Icons.warning,
                                  color: Colors.orange,
                                  size: 48,
                                ),
                                title: const Text('导入花园数据'),
                                content: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('导入新数据将会：'),
                                    SizedBox(height: 8),
                                    Text('• 清空当前所有植物数据'),
                                    Text('• 清空所有养护历史记录'),
                                    Text('• 删除所有植物图片'),
                                    SizedBox(height: 12),
                                    Text(
                                      '此操作不可撤销，请确认是否继续？',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop(false);
                                    },
                                    child: const Text('取消'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.of(context).pop(true);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('确认导入'),
                                  ),
                                ],
                              );
                            },
                          );

                          // 如果用户取消，直接返回
                          if (shouldProceed != true) return;

                          // 显示加载指示器
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (BuildContext context) {
                              return const AlertDialog(
                                content: Row(
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(width: 20),
                                    Text('正在导入数据...'),
                                  ],
                                ),
                              );
                            },
                          );

                          try {
                            var successfullyRestored =
                                await BackupManager.restore(clearExistingData: true);
                            
                            // 关闭加载指示器
                            Navigator.of(context).pop();
                            
                            if (successfullyRestored) {
                              // 显示成功对话框
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    icon: const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 48,
                                    ),
                                    title: const Text('导入成功'),
                                    content: const Text('花园数据已成功导入并覆盖原有数据！'),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text('确定'),
                                      ),
                                    ],
                                  );
                                },
                              );
                              
                              // 同时显示 SnackBar
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text('数据导入成功'),
                                    ],
                                  ),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('导入失败：请确保选择的是有效的 Florae 备份文件（.json格式）'),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 4),
                                ),
                              );
                            }
                          } catch (e) {
                            // 关闭加载指示器
                            Navigator.of(context).pop();
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('导入过程中发生错误：$e'),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        }),
                  ])),
              Card(
                  semanticContainer: true,
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Column(children: <Widget>[
                    ListTile(
                        trailing: const Icon(Icons.arrow_right),
                        leading: const Icon(Icons.text_snippet,
                            color: Colors.lightGreen),
                        title: Text(
                            AppLocalizations.of(context)!.aboutFloraeButton),
                        onTap: () {
                          showAboutDialog(
                            context: context,
                            applicationName: 'Florae',
                            applicationVersion: '3.1.0',
                            applicationLegalese: '© Naval Alcalá',
                          );
                        }),
                  ])),
              const SizedBox(height: 70),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await SettingsManager.writeSettings(settings);
          Navigator.pop(context);
        },
        label: Text(AppLocalizations.of(context)!.saveButton),
        icon: const Icon(Icons.save),
        backgroundColor: Theme.of(context).colorScheme.secondary,
      ),
    );
  }

  List<Widget> _buildNotificationHours() {
    return [
      ListTile(
          trailing: const Icon(Icons.arrow_right),
          leading: const Icon(Icons.alarm, color: Colors.blue),
          title: Text(AppLocalizations.of(context)!.atDay),
          subtitle: settings.morningNotification != null
              ? Text(settings.morningNotification!.format(context))
              : Text(AppLocalizations.of(context)!.never),
          onTap: () {
            _showAlarmDialog(context, settings.morningNotification,
                (selectedTime) {
              setState(() {
                settings.morningNotification = selectedTime;
              });
            });
          }),
      ListTile(
          trailing: const Icon(Icons.arrow_right),
          leading: const Icon(Icons.alarm, color: Colors.blue),
          title: Text(AppLocalizations.of(context)!.atNoon),
          subtitle: settings.eveningNotification != null
              ? Text(settings.eveningNotification!.format(context))
              : Text(AppLocalizations.of(context)!.never),
          onTap: () {
            _showAlarmDialog(context, settings.eveningNotification,
                (selectedTime) {
              setState(() {
                settings.eveningNotification = selectedTime;
              });
            });
          }),
      ListTile(
          trailing: const Icon(Icons.arrow_right),
          leading: const Icon(Icons.alarm, color: Colors.blue),
          title: Text(AppLocalizations.of(context)!.atNight),
          subtitle: settings.nightNotification != null
              ? Text(settings.nightNotification!.format(context))
              : Text(AppLocalizations.of(context)!.never),
          onTap: () {
            _showAlarmDialog(context, settings.nightNotification,
                (selectedTime) {
              setState(() {
                settings.nightNotification = selectedTime;
              });
            });
          }),
    ];
  }

  void _showAlarmDialog(BuildContext context, TimeOfDay? notification,
      void Function(TimeOfDay?) onTimeChanged) async {
    TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: notification ?? TimeOfDay.now(),
    );

    if (selectedTime == null) {
      notification = null;
    }
    onTimeChanged(selectedTime);
  }
}
