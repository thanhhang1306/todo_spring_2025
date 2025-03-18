import 'package:cloud_firestore/cloud_firestore.dart';

class Todo {
  final String text;
  final String uid;
  final DateTime createdAt;

  Todo({
    required this.text,
    required this.uid,
    required this.createdAt,
  });

  Map<String, dynamic> toSnapshot() {
    return {
      'text': text,
      'uid': uid,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Todo.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return Todo(
      text: data['text'],
      uid: data['uid'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}
