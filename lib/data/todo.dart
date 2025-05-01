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
  final List<String> labels;   // arbitrary labels

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
      'labels': labels,
    };
  }

  /// Creates a Todo from a Firestore document snapshot,
  /// safely handling any null Timestamps.
  factory Todo.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;

    DateTime safeDate(Object? o) =>
        o is Timestamp ? o.toDate() : DateTime.now();

    DateTime? safeNullableDate(Object? o) =>
        o is Timestamp ? o.toDate() : null;

    return Todo(
      id: snapshot.id,
      text: data['text'] as String,
      uid: data['uid'] as String,
      createdAt: safeDate(data['createdAt']),
      completedAt: safeNullableDate(data['completedAt']),
      dueAt: safeNullableDate(data['dueAt']),
      priority: data['priority'] as String? ?? 'low',
      labels: List<String>.from(data['labels'] ?? []),
    );
  }
}
