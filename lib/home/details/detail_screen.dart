import 'dart:async';
import 'dart:math';

import 'package:app_settings/app_settings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../data/todo.dart';

final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// Retro palette
const Color bg     = Color(0xFF1A1A2E);
const Color panel  = Color(0xFF16213E);
const Color accent = Color(0xFFE43F5A);

/// Paints an 8-bit starfield + pixel-ground
class _PixelBackgroundPainter extends CustomPainter {
  final List<Offset> stars;
  _PixelBackgroundPainter(this.stars);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // deep-space fill
    paint.color = const Color(0xFF000010);
    canvas.drawRect(Offset.zero & size, paint);

    // tiny 2×2 stars
    paint.color = Colors.white;
    for (final s in stars) {
      canvas.drawRect(
        Rect.fromLTWH(s.dx * size.width, s.dy * size.height, 2, 2),
        paint,
      );
    }

    // pixel-ground tiles
    paint.color = const Color(0xFF111111);
    final tile = 16.0;
    final cols = (size.width / tile).ceil();
    for (var i = 0; i < cols; i++) {
      canvas.drawRect(
        Rect.fromLTWH(i * tile, size.height - tile, tile, tile),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PixelBackgroundPainter old) => false;
}

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

  // Pixel stars
  final List<Offset> _pixelStars = List.generate(
    100,
        (_) => Offset(Random().nextDouble(), Random().nextDouble()),
  );

  @override
  void initState() {
    super.initState();
    _textController        = TextEditingController(text: widget.todo.text);
    _descriptionController = TextEditingController(text: widget.todo.description);
    _selectedDueDate       = widget.todo.dueAt;
    _selectedLabels        = widget.todo.labels.toSet();
  }

  @override
  void dispose() {
    _textController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    try {
      await FirebaseFirestore.instance.collection('todos').doc(widget.todo.id).delete();
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Todo deleted!', style: GoogleFonts.pressStart2p(color: Colors.white, fontSize: 10)),
            backgroundColor: panel,
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: $e', style: GoogleFonts.pressStart2p(color: Colors.white, fontSize: 10)),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _saveChanges() async {
    final doc = FirebaseFirestore.instance.collection('todos').doc(widget.todo.id);
    final updates = <String, dynamic>{};
    if (_textController.text != widget.todo.text) updates['text'] = _textController.text;
    if (_descriptionController.text != widget.todo.description) updates['description'] = _descriptionController.text;
    if (!setEquals(_selectedLabels, widget.todo.labels.toSet())) updates['labels'] = _selectedLabels.toList();
    if (_selectedDueDate != widget.todo.dueAt) {
      updates['dueAt'] = _selectedDueDate == null ? null : Timestamp.fromDate(_selectedDueDate!);
      // schedule notification if needed:
      if (_selectedDueDate != null) _scheduleNotification(widget.todo.id, _selectedDueDate!, _textController.text);
    }
    if (updates.isNotEmpty) {
      await doc.update(updates);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Todo updated!', style: GoogleFonts.pressStart2p(color: Colors.white, fontSize: 10)),
          backgroundColor: panel,
        ),
      );
    }
    Navigator.pop(context, true);
  }

  Future<bool> _requestNotificationPermission() async {
    final isGranted = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission() ?? false;
    return isGranted;
  }

  void _showPermissionDeniedSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Enable notifications to set due date.', style: GoogleFonts.pressStart2p(color: Colors.white, fontSize: 10)),
        backgroundColor: Colors.redAccent,
        action: SnackBarAction(
          label: 'Settings',
          textColor: Colors.white,
          onPressed: () => AppSettings.openAppSettings(type: AppSettingsType.notification),
        ),
      ),
    );
  }

  Future<void> _initializeNotifications() async {
    final androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await flutterLocalNotificationsPlugin.initialize(
      InitializationSettings(android: androidSettings),
    );
  }

  Future<void> _scheduleNotification(String todoId, DateTime dueDate, String text) async {
    await _initializeNotifications();
    final tzDateTime = tz.TZDateTime.from(dueDate, tz.local);
    await flutterLocalNotificationsPlugin.zonedSchedule(
      todoId.hashCode,
      'Task due',
      text,
      tzDateTime,
      const NotificationDetails(
        android: AndroidNotificationDetails('general_channel', 'General Notifications'),
      ),
      androidScheduleMode: AndroidScheduleMode.inexact,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  Future<void> _pickDueDate() async {
    if (!await _requestNotificationPermission()) {
      _showPermissionDeniedSnackbar();
      return;
    }
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2050),
    );
    if (pickedDate == null) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedDueDate != null
          ? TimeOfDay.fromDateTime(_selectedDueDate!)
          : TimeOfDay.now(),
    );
    if (pickedTime == null) return;
    setState(() {
      _selectedDueDate = DateTime(
        pickedDate.year, pickedDate.month, pickedDate.day,
        pickedTime.hour, pickedTime.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final pixelHeader = GoogleFonts.pressStart2p(color: accent, fontSize: 16);
    final pixelText   = GoogleFonts.pressStart2p(color: Colors.white, fontSize: 10);

    return Stack(
      children: [
        // Pixel background
        CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _PixelBackgroundPainter(_pixelStars),
        ),

        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: panel,
            title: Text('DETAILS', style: pixelHeader),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _delete,
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              // Task title
              _pixelInputContainer(
                child: TextField(
                  controller: _textController,
                  style: pixelText,
                  decoration: InputDecoration(
                    hintText: 'Task',
                    hintStyle: pixelText.copyWith(color: Colors.white38),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Description
              _pixelInputContainer(
                child: TextField(
                  controller: _descriptionController,
                  style: pixelText,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Description',
                    hintStyle: pixelText.copyWith(color: Colors.white38),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Due date picker
              _pixelInputContainer(
                child: ListTile(
                  title: Text('Due Date', style: pixelText),
                  subtitle: Text(
                    _selectedDueDate != null
                        ? _selectedDueDate!.toLocal().toString().split('.')[0]
                        : 'None',
                    style: pixelText.copyWith(color: Colors.white54),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    color: accent,
                    onPressed: _pickDueDate,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 8),
              // Labels
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Labels:', style: pixelText),
              ),
              Wrap(
                spacing: 6,
                children: _allLabels.map((lbl) {
                  final selected = _selectedLabels.contains(lbl);
                  return Container(
                    decoration: BoxDecoration(
                      color: selected ? accent : panel,
                      border: Border.all(color: accent, width: 2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FilterChip(
                      label: Text(lbl, style: pixelText),
                      selected: selected,
                      selectedColor: accent,
                      backgroundColor: panel,
                      checkmarkColor: panel,
                      onSelected: (sel) {
                        setState(() {
                          sel ? _selectedLabels.add(lbl) : _selectedLabels.remove(lbl);
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
              const Spacer(),
              // Save button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: accent,
                  border: Border.all(color: accent, width: 2),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: TextButton(
                  onPressed: _saveChanges,
                  child: Text('SAVE', style: pixelText.copyWith(color: panel)),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _pixelInputContainer({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: panel,
      border: Border.all(color: accent, width: 2),
      borderRadius: BorderRadius.circular(2),
    ),
    child: child,
  );
}
