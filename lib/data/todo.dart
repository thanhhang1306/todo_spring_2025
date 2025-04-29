import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a TODO item, including priority and labels.
class Todo {
  final String id;
  final String text;
  final String uid;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? dueAt;
  final String priority;       // 'low' | 'medium' | 'high'
  final List<String> labels;   // new: arbitrary labels

  Todo({
    required this.id,
    required this.text,
    required this.uid,
    required this.createdAt,
    required this.completedAt,
    required this.dueAt,
    this.priority = 'low',
    this.labels = const [],
  });

  /// Converts the Todo into a Firestore-friendly map.
  Map<String, dynamic> toSnapshot() {
    return {
      'text': text,
      'uid': uid,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'dueAt': dueAt != null ? Timestamp.fromDate(dueAt!) : null,
      'priority': priority,
      'labels': labels,             // persist labels array
    };
  }

  /// Creates a Todo from a Firestore document snapshot.
  factory Todo.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return Todo(
      id: snapshot.id,
      text: data['text'] as String,
      uid: data['uid'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      completedAt: data['completedAt'] != null ? (data['completedAt'] as Timestamp).toDate() : null,
      dueAt: data['dueAt'] != null ? (data['dueAt'] as Timestamp).toDate() : null,
      priority: data['priority'] as String? ?? 'low',
      labels: List<String>.from(data['labels'] ?? []),  // read back labels
    );
  }
}
