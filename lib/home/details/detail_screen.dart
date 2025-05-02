import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../data/todo.dart';

final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

class DetailScreen extends StatefulWidget {
  final Todo todo;

  const DetailScreen({super.key, required this.todo});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late TextEditingController _textController;
  late TextEditingController _descriptionController;
  DateTime? _selectedDueDate;
  late Set<String> _selectedLabels;
  final List<String> _allLabels = ['Work', 'Personal', 'Urgent', 'Shopping'];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.todo.text);
    _descriptionController = TextEditingController(text: widget.todo.description);
    _selectedDueDate = widget.todo.dueAt;
    _selectedLabels = widget.todo.labels.toSet();
  }

  Future<void> _delete() async {
    try {
      await FirebaseFirestore.instance.collection('todos').doc(widget.todo.id).delete();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Todo deleted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete todo: $e')),
        );
      }
    }
  }

  Future<void> _updateText(String newText) async {
    try {
      await FirebaseFirestore.instance.collection('todos').doc(widget.todo.id).update({'text': newText});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Todo updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update todo: $e')),
        );
      }
    }
  }

  Future<void> _updateDueDate(DateTime? newDueDate) async {
    try {
      await FirebaseFirestore.instance
          .collection('todos')
          .doc(widget.todo.id)
          .update({'dueAt': newDueDate == null ? null : Timestamp.fromDate(newDueDate)});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update todo: $e')),
        );
      }
    }
  }

  Future<void> _updateLabels() async {
    try {
      await FirebaseFirestore.instance.collection('todos').doc(widget.todo.id).update({'labels': _selectedLabels.toList()});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update labels: $e')),
        );
      }
    }
  }

  Future<bool> _requestNotificationPermission() async {
    final isGranted = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission() ??
        false;
    return isGranted;
  }

  void _showPermissionDeniedSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'You need to enable notifications to set due date.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
        ),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: 'Open Settings',
          textColor: Colors.white,
          onPressed: () {
            AppSettings.openAppSettings(
              type: AppSettingsType.notification,
            );
          },
        ),
      ),
    );
  }

  Future<void> _initializeNotifications() async {
    final initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
  }

  Future<void> _scheduleNotification(
      String todoId,
      DateTime dueDate,
      String text,
      ) async {
    final tzDateTime = tz.TZDateTime.from(dueDate, tz.local);
    await flutterLocalNotificationsPlugin.zonedSchedule(
      todoId.hashCode,
      'Task due',
      text,
      tzDateTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'general_channel',
          'General Notifications',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexact,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  Future<void> _updateDescription(String newDesc) async {
    await FirebaseFirestore.instance
        .collection('todos')
        .doc(widget.todo.id)
        .update({'description': newDesc});
  }

  /// Call this to batch‐update title + description when the user taps “Save”
  Future<void> _saveChanges() async {
    final doc = FirebaseFirestore.instance
        .collection('todos')
        .doc(widget.todo.id);

    final updates = <String, dynamic>{};
    if (_textController.text != widget.todo.text) {
      updates['text'] = _textController.text;
    }
    if (_descriptionController.text != widget.todo.description) {
      updates['description'] = _descriptionController.text;
    }

    if (updates.isNotEmpty) {
      await doc.update(updates);
    }
    Navigator.pop(context, true);
  }




  @override
  void dispose() {
    _textController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Todo'),
                  content: const Text('Are you sure you want to delete this todo?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await _delete();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1) Scrollable inputs
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                32,
                16,
                32,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Task title
                  TextField(
                    controller: _textController,
                    decoration: const InputDecoration(labelText: 'Task'),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  // Due Date picker + notification logic
                  ListTile(
                    title: const Text('Due Date'),
                    subtitle: Text(
                      _selectedDueDate != null
                          ? _selectedDueDate!.toLocal().toString().split('.')[0]
                          : 'No due date',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_selectedDueDate != null)
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () async {
                              await _updateDueDate(null);
                              setState(() {
                                _selectedDueDate = null;
                              });
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () async {
                            final isGranted = await _requestNotificationPermission();
                            if (!context.mounted) return;

                            if (!isGranted) {
                              _showPermissionDeniedSnackbar(context);
                              return;
                            }

                            await _initializeNotifications();
                            if (!context.mounted) return;

                            final selectedDate = await showDatePicker(
                              context: context,
                              initialDate: _selectedDueDate ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2050),
                            );
                            if (!context.mounted || selectedDate == null) return;

                            final selectedTime = await showTimePicker(
                              context: context,
                              initialTime: _selectedDueDate != null
                                  ? TimeOfDay.fromDateTime(_selectedDueDate!)
                                  : TimeOfDay.now(),
                            );
                            if (!context.mounted || selectedTime == null) return;

                            final dueDate = DateTime(
                              selectedDate.year,
                              selectedDate.month,
                              selectedDate.day,
                              selectedTime.hour,
                              selectedTime.minute,
                            );

                            setState(() {
                              _selectedDueDate = dueDate;
                            });

                            await _updateDueDate(dueDate);
                            await _scheduleNotification(
                              widget.todo.id,
                              dueDate,
                              widget.todo.text,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Labels
                  Text('Labels:', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _allLabels.map((lbl) => FilterChip(
                      label: Text(lbl),
                      selected: _selectedLabels.contains(lbl),
                      onSelected: (sel) {
                        setState(() {
                          if (sel) _selectedLabels.add(lbl);
                          else _selectedLabels.remove(lbl);
                        });
                      },
                    )).toList(),
                  ),
                ],
              ),
            ),
          ),

          // 2) Fixed Save button at bottom
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saveChanges,
                child: const Text('Save'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
