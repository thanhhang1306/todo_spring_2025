import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/todo.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<List<Todo>> getTodosForUser(String userId) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('todos')
        .where('uid', isEqualTo: userId)
        .get();

    return querySnapshot.docs.map((doc) => Todo.fromSnapshot(doc)).toList();
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
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
                ElevatedButton(
                  onPressed: () async {
                    if (user != null && _controller.text.isNotEmpty) {
                      await FirebaseFirestore.instance.collection('todos').add({
                        'text': _controller.text,
                        'createdAt': FieldValue.serverTimestamp(),
                        'uid': user.uid,
                      });
                      _controller.clear();
                      setState(() {}); // Refresh the list
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
                child: FutureBuilder<List<Todo>>(
              future: getTodosForUser(user?.uid ?? ''),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return const Center(child: Text('Error loading TODOs'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No TODOs found'));
                } else {
                  final todos = snapshot.data!;
                  return ListView.builder(
                    itemCount: todos.length,
                    itemBuilder: (context, index) {
                      final todo = todos[index];
                      return ListTile(
                        title: Text(todo.text),
                        subtitle: Text(todo.createdAt.toString()),
                      );
                    },
                  );
                }
              },
            )),
          ],
        ),
      ),
    );
  }
}
