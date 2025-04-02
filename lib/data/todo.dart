import 'package:cloud_firestore/cloud_firestore.dart';

class Todo {
  final String id;
  final String text;
  final String uid;
  final DateTime createdAt;
  final DateTime? completedAt;

  Todo({
    required this.id,
    required this.text,
    required this.uid,
    required this.createdAt,
    required this.completedAt,
  });

  Map<String, dynamic> toSnapshot() {
    return {
      'text': text,
      'uid': uid,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  factory Todo.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return Todo(
      id: snapshot.id,
      text: data['text'],
      uid: data['uid'],
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
      completedAt: data['completedAt'] != null ? (data['completedAt'] as Timestamp).toDate() : null,
    );
  }
}
