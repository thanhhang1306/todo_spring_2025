import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../data/todo.dart';
import 'details/detail_screen.dart';
import 'filter/filter_sheet.dart';

/// Main screen with List and Calendar views, plus a FAB to add todos.
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  // Controllers and subscriptions
  final _searchController = TextEditingController();
  StreamSubscription<List<Todo>>? _todoSubscription;
  late final TabController _tabController;

  // Data
  List<Todo> _todos = [];
  List<Todo>? _filteredTodos;

  // List-mode state
  FilterSheetResult _filters = FilterSheetResult(
    sortBy: 'date',
    order: 'descending',
    priority: 'all',
    startDate: null,
    endDate: null,
    labels: const [],
  );

  // Calendar-mode state
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _todoSubscription = FirebaseFirestore.instance
          .collection('todos')
          .where('uid', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map((d) => Todo.fromSnapshot(d)).toList())
          .listen((todos) {
        setState(() {
          _todos = todos;
          _filteredTodos = _applyFilters();
        });
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _todoSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  /// Applies text search and filter sheet settings
  List<Todo> _applyFilters() {
    var list = _todos
        .where((t) => t.text.toLowerCase().contains(_searchController.text.toLowerCase()))
        .toList();
    // Priority filter
    if (_filters.priority != 'all') {
      list = list.where((t) => t.priority == _filters.priority).toList();
    }
    // Label filter
    if (_filters.labels.isNotEmpty) {
      list = list.where((t) => t.labels.any((lbl) => _filters.labels.contains(lbl))).toList();
    }
    // Date range filter
    if (_filters.startDate != null) {
      list = list.where((t) => t.dueAt != null && !t.dueAt!.isBefore(_filters.startDate!)).toList();
    }
    if (_filters.endDate != null) {
      list = list.where((t) => t.dueAt != null && !t.dueAt!.isAfter(_filters.endDate!)).toList();
    }
    // Sorting
    if (_filters.sortBy == 'date') {
      list.sort((a, b) => _filters.order == 'ascending'
          ? a.createdAt.compareTo(b.createdAt)
          : b.createdAt.compareTo(a.createdAt));
    } else {
      list.sort((a, b) => _filters.order == 'ascending'
          ? (a.completedAt ?? DateTime(0)).compareTo(b.completedAt ?? DateTime(0))
          : (b.completedAt ?? DateTime(0)).compareTo(a.completedAt ?? DateTime(0)));
    }
    return list;
  }

  /// Returns todos due on a specific day
  List<Todo> _getEventsForDay(DateTime day) {
    return _todos.where((todo) {
      if (todo.dueAt == null) return false;
      final d = DateTime(todo.dueAt!.year, todo.dueAt!.month, todo.dueAt!.day);
      return isSameDay(d, day);
    }).toList();
  }

  /// Opens form to add a new todo; awaits a bool to know if something was added
  Future<void> _openAddForm() async {
    final initial = _tabController.index == 1 ? _selectedDay : null;
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TodoFormScreen(initialDate: initial)),
    );
    if (added == true) {
      setState(() {
        _filteredTodos = _applyFilters();
      });
    }
  }

  /// Maps priority to a color
  Color _priorityColor(String priority) {
    if (priority == 'high') return Colors.red;
    if (priority == 'medium') return Colors.orange;
    return Colors.green;
  }

  /// Maps a label to a color
  Color _labelColor(String lbl) {
    switch (lbl) {
      case 'Work':
        return Colors.blue;
      case 'Personal':
        return Colors.green;
      case 'Urgent':
        return Colors.red;
      case 'Shopping':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TODO Spring 2025'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'List'), Tab(text: 'Calendar')],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddForm,
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // --- List Mode ---
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    labelText: 'Search TODOs',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.filter_list),
                      onPressed: () async {
                        final result = await showModalBottomSheet<FilterSheetResult>(
                          context: context,
                          builder: (_) => FilterSheet(initialFilters: _filters),
                        );
                        if (result != null) {
                          setState(() {
                            _filters = result;
                            _filteredTodos = _applyFilters();
                          });
                        }
                      },
                    ),
                  ),
                  onChanged: (_) => setState(() => _filteredTodos = _applyFilters()),
                ),
              ),
              Expanded(
                child: (_filteredTodos ?? []).isEmpty
                    ? const Center(child: Text('No TODOs found'))
                    : ListView.builder(
                  itemCount: _filteredTodos!.length,
                  itemBuilder: (ctx, i) {
                    final todo = _filteredTodos![i];
                    return ListTile(
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _priorityColor(todo.priority),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Checkbox(
                            value: todo.completedAt != null,
                            onChanged: (v) {
                              FirebaseFirestore.instance
                                  .collection('todos')
                                  .doc(todo.id)
                                  .update({
                                'completedAt':
                                v == true ? FieldValue.serverTimestamp() : null
                              });
                            },
                          ),
                        ],
                      ),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            todo.text,
                            style: todo.completedAt != null
                                ? TextStyle(
                              color: _priorityColor(todo.priority),
                              decoration: TextDecoration.lineThrough,
                            )
                                : TextStyle(color: _priorityColor(todo.priority)),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            children: todo.labels
                                .map((lbl) => Chip(
                              label: Text(lbl),
                              backgroundColor: _labelColor(lbl),
                            ))
                                .toList(),
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => DetailScreen(todo: todo)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // --- Calendar Mode ---
          Column(
            children: [
              TableCalendar<Todo>(
                firstDay: DateTime.utc(2000, 1, 1),
                lastDay: DateTime.utc(2050, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Month',
                  CalendarFormat.week: 'Week'
                },
                onFormatChanged: (fmt) => setState(() => _calendarFormat = fmt),
                selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
                eventLoader: _getEventsForDay,
                calendarStyle: const CalendarStyle(markerSize: 8),
                calendarBuilders: CalendarBuilders<Todo>(
                  markerBuilder: (ctx, date, events) {
                    if (events.isNotEmpty) {
                      final prios = events.map((e) => e.priority);
                      final clr = prios.contains('high')
                          ? Colors.red
                          : prios.contains('medium')
                          ? Colors.orange
                          : Colors.green;
                      return Positioned(
                        bottom: 4,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration:
                          BoxDecoration(shape: BoxShape.circle, color: clr),
                        ),
                      );
                    }
                    return null;
                  },
                ),
                onDaySelected: (sel, foc) => setState(() {
                  _selectedDay = sel;
                  _focusedDay = foc;
                }),
              ),
              const Divider(),
              Expanded(
                child: _getEventsForDay(_selectedDay ?? _focusedDay).isEmpty
                    ? const Center(child: Text('No tasks'))
                    : ListView(
                  children: _getEventsForDay(_selectedDay ?? _focusedDay)
                      .map((todo) => ListTile(
                    leading: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _priorityColor(todo.priority)),
                    ),
                    title: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(todo.text),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          children: todo.labels
                              .map((lbl) => Chip(
                            label: Text(lbl),
                            backgroundColor:
                            _labelColor(lbl),
                          ))
                              .toList(),
                        ),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => DetailScreen(todo: todo)),
                    ),
                  ))
                      .toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Full-screen form to add a new Todo with optional due date, priority, and labels
class TodoFormScreen extends StatefulWidget {
  final DateTime? initialDate;
  const TodoFormScreen({Key? key, this.initialDate}) : super(key: key);

  @override
  _TodoFormScreenState createState() => _TodoFormScreenState();
}

class _TodoFormScreenState extends State<TodoFormScreen> {
  final _textController = TextEditingController();
  String _priority = 'low';
  DateTime? _dueDate;
  final List<String> _allLabels = ['Work', 'Personal', 'Urgent', 'Shopping'];
  late Set<String> _selectedLabels;

  @override
  void initState() {
    super.initState();
    _dueDate = widget.initialDate;
    _selectedLabels = {};
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  /// Combined date + time picker
  Future<void> _pickDueDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2050),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _dueDate != null
          ? TimeOfDay.fromDateTime(_dueDate!)
          : TimeOfDay.now(),
    );

    setState(() {
      if (time == null) {
        _dueDate = DateTime(date.year, date.month, date.day);
      } else {
        _dueDate = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
      }
    });
  }

  Future<void> _saveTodo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _textController.text.isNotEmpty) {
      await FirebaseFirestore.instance.collection('todos').add({
        'text': _textController.text,
        'createdAt': FieldValue.serverTimestamp(),
        'uid': user.uid,
        'priority': _priority,
        'dueAt': _dueDate != null ? Timestamp.fromDate(_dueDate!) : null,
        'labels': _selectedLabels.toList(),
      });
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dueText = _dueDate == null
        ? 'None'
        : '${_dueDate!.toLocal().toString().split(' ')[0]} '
        '${TimeOfDay.fromDateTime(_dueDate!).format(context)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Add Todo')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _textController,
              decoration: const InputDecoration(labelText: 'Task'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Priority:'),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _priority,
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                  ],
                  onChanged: (v) => setState(() => _priority = v!),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              title: Text('Due Date & Time: $dueText'),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDueDateTime,
            ),
            const SizedBox(height: 16),
            Text('Labels:', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _allLabels.map((lbl) => FilterChip(
                label: Text(lbl),
                selected: _selectedLabels.contains(lbl),
                onSelected: (sel) => setState(() {
                  if (sel) _selectedLabels.add(lbl);
                  else _selectedLabels.remove(lbl);
                }),
              )).toList(),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveTodo,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
