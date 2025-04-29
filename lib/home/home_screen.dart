import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/todo.dart';
import 'details/detail_screen.dart';
import 'filter/filter_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();
  final _searchController = TextEditingController();
  StreamSubscription<List<Todo>>? _todoSubscription;
  List<Todo> _todos = [];
  List<Todo>? _filteredTodos;

  // State for new todo priority
  String _newTodoPriority = 'low';

  // Include priority, date range in initial filters
  FilterSheetResult _filters = FilterSheetResult(
    sortBy: 'date',
    order: 'descending',
    priority: 'all',
    startDate: null,
    endDate: null,
  );

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _todoSubscription = getTodosForUser(user.uid).listen((todos) {
        setState(() {
          _todos = todos;
          _filteredTodos = filterTodos();
        });
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _todoSubscription?.cancel();
    super.dispose();
  }

  List<Todo> filterTodos() {
    var list = _todos
        .where((t) => t.text.toLowerCase().contains(_searchController.text.toLowerCase()))
        .toList();

    // Priority filter
    if (_filters.priority != 'all') {
      list = list.where((t) => t.priority == _filters.priority).toList();
    }

    // Date range filter on dueAt
    if (_filters.startDate != null) {
      list = list.where((t) =>
      t.dueAt != null && !t.dueAt!.isBefore(_filters.startDate!)).toList();
    }
    if (_filters.endDate != null) {
      list = list.where((t) =>
      t.dueAt != null && !t.dueAt!.isAfter(_filters.endDate!)).toList();
    }

    // Sorting
    if (_filters.sortBy == 'date') {
      list.sort((a, b) => _filters.order == 'ascending'
          ? a.createdAt.compareTo(b.createdAt)
          : b.createdAt.compareTo(a.createdAt));
    } else if (_filters.sortBy == 'completed') {
      list.sort((a, b) => _filters.order == 'ascending'
          ? (a.completedAt ?? DateTime(0)).compareTo(b.completedAt ?? DateTime(0))
          : (b.completedAt ?? DateTime(0)).compareTo(a.completedAt ?? DateTime(0)));
    }

    return list;
  }

  Stream<List<Todo>> getTodosForUser(String userId) {
    return FirebaseFirestore.instance
        .collection('todos')
        .where('uid', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((querySnapshot) =>
        querySnapshot.docs.map((doc) => Todo.fromSnapshot(doc)).toList());
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isDesktop = constraints.maxWidth > 600;
          return Center(
            child: SizedBox(
              width: isDesktop ? 600 : double.infinity,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                              builder: (context) => FilterSheet(initialFilters: _filters),
                            );

                            if (result != null) {
                              setState(() {
                                _filters = result;
                                _filteredTodos = filterTodos();
                              });
                            }
                          },
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _filteredTodos = filterTodos();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _filteredTodos?.isEmpty ?? true
                        ? const Center(child: Text('No TODOs found'))
                        : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      itemCount: _filteredTodos?.length ?? 0,
                      itemBuilder: (context, index) {
                        final todo = _filteredTodos?[index];
                        if (todo == null) return const SizedBox.shrink();
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
                                onChanged: (bool? value) {
                                  final updateData = {
                                    'completedAt': value == true
                                        ? FieldValue.serverTimestamp()
                                        : null
                                  };
                                  FirebaseFirestore.instance
                                      .collection('todos')
                                      .doc(todo.id)
                                      .update(updateData);
                                },
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          title: Text(
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
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DetailScreen(todo: todo),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Container(
                    color: Colors.green[100],
                    padding: const EdgeInsets.all(32.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            keyboardType: TextInputType.text,
                            controller: _controller,
                            decoration: const InputDecoration(
                              labelText: 'Enter Task:',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _newTodoPriority,
                          items: const [
                            DropdownMenuItem(value: 'low', child: Text('Low')),
                            DropdownMenuItem(value: 'medium', child: Text('Medium')),
                            DropdownMenuItem(value: 'high', child: Text('High')),
                          ],
                          onChanged: (v) => setState(() => _newTodoPriority = v!),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            if (user != null && _controller.text.isNotEmpty) {
                              await FirebaseFirestore.instance
                                  .collection('todos')
                                  .add({
                                'text': _controller.text,
                                'createdAt': FieldValue.serverTimestamp(),
                                'uid': user.uid,
                                'priority': _newTodoPriority,
                              });
                              _controller.clear();
                            }
                          },
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
