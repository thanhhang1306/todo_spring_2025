import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a TODO item, including priority, labels, and description.
class Todo {
  final String id;
  final String text;
  final String description;       // Description of the task
  final String uid;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? dueAt;
  final String priority;          // 'low' | 'medium' | 'high'
  final List<String> labels;      // arbitrary labels

  Todo({
    required this.id,
    required this.text,
    this.description = '',
    required this.uid,
    required this.createdAt,
    this.completedAt,
    this.dueAt,
    this.priority = 'low',
    this.labels = const [],
  });

  /// Converts this Todo into a Firestore-friendly map.
  Map<String, dynamic> toSnapshot() {
    return {
      'text': text,
      'description': description,
      'uid': uid,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'dueAt': dueAt != null ? Timestamp.fromDate(dueAt!) : null,
      'priority': priority,
      'labels': labels,
    };
  }

  /// Creates a Todo from a Firestore document snapshot, handling missing fields.
  factory Todo.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>? ?? {};

    // Safely parse timestamps
    DateTime safeDate(Object? o) => o is Timestamp ? o.toDate() : DateTime.now();
    DateTime? safeNullableDate(Object? o) => o is Timestamp ? o.toDate() : null;

    // Safely parse description, defaulting to empty string
    final rawDesc = data['description'];
    final safeDesc = rawDesc is String ? rawDesc : '';

    return Todo(
      id: snapshot.id,
      text: data['text'] as String? ?? '',
      description: safeDesc,
      uid: data['uid'] as String? ?? '',
      createdAt: safeDate(data['createdAt']),
      completedAt: safeNullableDate(data['completedAt']),
      dueAt: safeNullableDate(data['dueAt']),
      priority: data['priority'] as String? ?? 'low',
      labels: List<String>.from(data['labels'] ?? []),
    );
  }
}
