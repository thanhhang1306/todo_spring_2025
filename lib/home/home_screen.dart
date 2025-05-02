import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:todo_spring_2025/home/dashboard/dashboard_screen.dart';


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
  String _statusFilter = 'all'; // 'all' | 'active' | 'completed'
  bool _isSelectionMode = false;

  // Data
  List<Todo> _todos = [];
  List<Todo>? _filteredTodos;
  /// Holds the IDs of any todos the user has “checked” for bulk actions.
  Set<String> _selectedTodoIds = {};

  /// Deletes all selected docs in one batch, then clears selection.
  Future<void> _deleteSelected() async {
    if (_selectedTodoIds.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final id in _selectedTodoIds) {
      batch.delete(FirebaseFirestore.instance.collection('todos').doc(id));
    }
    await batch.commit();
    setState(() {
      _selectedTodoIds.clear();
      _filteredTodos = _applyFilters();
    });
  }

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
        .where((t) =>
        t.text.toLowerCase().contains(_searchController.text.toLowerCase()))
        .toList();
    if (_statusFilter == 'active') {
      list = list.where((t) => t.completedAt == null).toList();
    } else if (_statusFilter == 'completed') {
      list = list.where((t) => t.completedAt != null).toList();
    }
    // Priority filter
    if (_filters.priority != 'all') {
      list = list.where((t) => t.priority == _filters.priority).toList();
    }
    // Label filter
    if (_filters.labels.isNotEmpty) {
      list = list.where((t) =>
          t.labels.any((lbl) => _filters.labels.contains(lbl))).toList();
    }
    // Date range filter
    if (_filters.startDate != null) {
      list = list.where((t) => t.dueAt != null &&
          !t.dueAt!.isBefore(_filters.startDate!)).toList();
    }
    if (_filters.endDate != null) {
      list = list.where((t) => t.dueAt != null &&
          !t.dueAt!.isAfter(_filters.endDate!)).toList();
    }
    // Sorting
    if (_filters.sortBy == 'date') {
      list.sort((a, b) =>
      _filters.order == 'ascending'
          ? a.createdAt.compareTo(b.createdAt)
          : b.createdAt.compareTo(a.createdAt));
    } else {
      list.sort((a, b) =>
      _filters.order == 'ascending'
          ? (a.completedAt ?? DateTime(0)).compareTo(
          b.completedAt ?? DateTime(0))
          : (b.completedAt ?? DateTime(0)).compareTo(
          a.completedAt ?? DateTime(0)));
    }
    return list;
  }

  /// Returns todos due on a specific day, applying the same “archive” filter
  List<Todo> _getEventsForDay(DateTime day) {
    return _todos.where((todo) {
      // 1) does it fall on this day?
      if (todo.dueAt == null) return false;
      if (!isSameDay(todo.dueAt!, day)) return false;

      // 2) archive filter (“all” | “active” | “completed”)
      if (_statusFilter == 'active' && todo.completedAt != null) return false;
      if (_statusFilter == 'completed' && todo.completedAt == null) return false;

      return true;
    }).toList();
  }


  /// Opens form to add a new todo; pre-fills due date if in Calendar tab
  Future<void> _openAddForm() async {
    DateTime? initial;
    if (_tabController.index == 1 && _selectedDay != null) {
      // strip off any time – make it midnight of the selected day
      final d = _selectedDay!;
      initial = DateTime(d.year, d.month, d.day);
    }

    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TodoFormScreen(initialDate: initial)),
    );

    // if the form popped with `true`, re-run filters so the new item shows up
    if (added == true) {
      setState(() => _filteredTodos = _applyFilters());
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
          tabs: const [
            Tab(text: 'List'),
            Tab(text: 'Calendar'),
          ],
        ),
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete selected',
              onPressed: _deleteSelected,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cancel delete',
              onPressed: () {
                setState(() {
                  _isSelectionMode = false;
                  _selectedTodoIds.clear();
                });
              },
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.dashboard),
              tooltip: 'Dashboard',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => DashboardScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Select to delete',
              onPressed: () {
                setState(() {
                  _isSelectionMode = true;
                  _selectedTodoIds.clear();
                });
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.archive),
              tooltip: 'Show…',
              onSelected: (v) {
                setState(() {
                  _statusFilter = v;
                  _filteredTodos = _applyFilters();
                });
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'all', child: Text('All tasks')),
                PopupMenuItem(value: 'active', child: Text('Active only')),
                PopupMenuItem(value: 'completed', child: Text('Completed only')),
              ],
            ),
          ],
        ],
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    labelText: 'Search TODOs',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.filter_list),
                      onPressed: () async {
                        final result = await showModalBottomSheet<
                            FilterSheetResult>(
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
                  onChanged: (_) =>
                      setState(() => _filteredTodos = _applyFilters()),
                ),
              ),
              Expanded(
                child: (_filteredTodos ?? []).isEmpty
                    ? const Center(child: Text('No TODOs found'))
                    : ListView.builder(
                  itemCount: _filteredTodos!.length,
                  itemBuilder: (ctx, i) {
                    final todo = _filteredTodos![i];
                    final selected = _selectedTodoIds.contains(todo.id);

                    return InkWell(
                      onLongPress: () {
                        setState(() {
                          _isSelectionMode = true;
                          if (selected) _selectedTodoIds.remove(todo.id);
                          else _selectedTodoIds.add(todo.id);
                        });
                      },
                      onTap: _isSelectionMode
                          ? () {
                        setState(() {
                          if (selected) _selectedTodoIds.remove(todo.id);
                          else _selectedTodoIds.add(todo.id);
                        });
                      }
                          : null,
                      child: Container(
                        color: selected ? Colors.blue.withOpacity(.1) : null,
                        child: ListTile(
                          leading: _isSelectionMode
                              ? Checkbox(
                            value: selected,
                            onChanged: (_) {
                              setState(() {
                                if (selected)
                                  _selectedTodoIds.remove(todo.id);
                                else
                                  _selectedTodoIds.add(todo.id);
                              });
                            },
                          )
                              : Row(
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
                                    'completedAt': v == true
                                        ? FieldValue.serverTimestamp()
                                        : null,
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
                                    : TextStyle(
                                  color: _priorityColor(todo.priority),
                                ),
                              ),
                            if (todo.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                              Text(
                                todo.description,
                                style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                children: todo.labels.map((lbl) => Chip(
                                  label: Text(lbl),
                                  backgroundColor: _labelColor(lbl),
                                )).toList(),
                              ),
                            ],
                          ),
                          trailing: _isSelectionMode ? null : const Icon(Icons.arrow_forward_ios),
                          onTap: _isSelectionMode
                              ? null
                              : () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => DetailScreen(todo: todo)),
                          ),
                        ),
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
                onDaySelected: (sel, foc) =>
                    setState(() {
                      _selectedDay = sel;
                      _focusedDay = foc;
                    }),
              ),
              const Divider(),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final todays = _getEventsForDay(_selectedDay ?? _focusedDay);
                    if (todays.isEmpty) {
                      return const Center(child: Text('No tasks'));
                    }
                    return ListView.builder(
                      itemCount: todays.length,
                      itemBuilder: (ctx, i) {
                        final todo = todays[i];
                        final selected = _selectedTodoIds.contains(todo.id);

                        return InkWell(
                          onLongPress: () {
                            setState(() {
                              _isSelectionMode = true;
                              if (selected) _selectedTodoIds.remove(todo.id);
                              else _selectedTodoIds.add(todo.id);
                            });
                          },
                          onTap: _isSelectionMode
                              ? () {
                            setState(() {
                              if (selected) _selectedTodoIds.remove(todo.id);
                              else _selectedTodoIds.add(todo.id);
                            });
                          }
                              : () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => DetailScreen(todo: todo)),
                          ),
                          child: Container(
                            color: selected ? Colors.blue.withOpacity(.1) : null,
                            child: ListTile(
                              leading: _isSelectionMode
                                  ? Checkbox(
                                value: selected,
                                onChanged: (_) {
                                  setState(() {
                                    if (selected) _selectedTodoIds.remove(todo.id);
                                    else _selectedTodoIds.add(todo.id);
                                  });
                                },
                              )
                                  : Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _priorityColor(todo.priority),
                                ),
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
                                        : TextStyle(
                                      color: _priorityColor(todo.priority),
                                    ),
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
                              trailing: _isSelectionMode ? null : const Icon(Icons.arrow_forward_ios),
                            ),
                          ),
                        );
                      },
                    );
                  },
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
  final _descriptionController = TextEditingController();
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
    _descriptionController.dispose();
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
        'description': _descriptionController.text,
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
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Add Todo')),
      body: Column(
        children: [
          // 1) scrollable inputs
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  MediaQuery.of(context).viewInsets.bottom + 16
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  // Priority picker
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
                  // Due date/time
                  ListTile(
                    title: Text('Due Date & Time: $dueText'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: _pickDueDateTime,
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
                      onSelected: (sel) => setState(() {
                        if (sel) _selectedLabels.add(lbl);
                        else _selectedLabels.remove(lbl);
                      }),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ),

          // 2) fixed Save button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saveTodo,
                child: const Text('Save'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
