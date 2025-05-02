import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/todo.dart';

/// Holds total and completed counts, with a derived completion rate.
class TodoStats {
  final int total;
  final int completed;
  double get completionRate => total == 0 ? 0 : completed / total;

  TodoStats({required this.total, required this.completed});
}

/// Represents a milestone threshold and whether it's achieved.
class Milestone {
  final int threshold;
  final bool achieved;

  Milestone({required this.threshold, required this.achieved});
}

/// Dashboard screen showing overall stats, profile info, and unlocked milestones.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<TodoStats> _statsFuture;
  final List<int> _milestoneThresholds = [5, 10, 25, 50, 100];

  @override
  void initState() {
    super.initState();
    _statsFuture = _fetchStats();
  }

  Future<TodoStats> _fetchStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return TodoStats(total: 0, completed: 0);
    final snapshot = await FirebaseFirestore.instance
        .collection('todos')
        .where('uid', isEqualTo: user.uid)
        .get();
    final todos = snapshot.docs.map((d) => Todo.fromSnapshot(d)).toList();
    final completedCount = todos.where((t) => t.completedAt != null).length;
    return TodoStats(total: todos.length, completed: completedCount);
  }

  // add sign out
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).popUntil((route) => route.isFirst);

  }

  List<Milestone> _buildMilestones(int completedCount) {
    return _milestoneThresholds
        .map((th) => Milestone(threshold: th, achieved: completedCount >= th))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: SafeArea(
        child: FutureBuilder<TodoStats>(
          future: _statsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(child: Text('Failed to load stats'));
            }
            final stats = snapshot.data!;
            final milestones = _buildMilestones(stats.completed);
            final user = FirebaseAuth.instance.currentUser;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Profile Card
                if (user != null)
                  Card(
                    margin: const EdgeInsets.only(bottom: 24),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          user.email != null && user.email!.isNotEmpty
                              ? user.email![0].toUpperCase()
                              : '',
                        ),
                      ),
                      title: Text(user.email ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.logout),
                        onPressed: () async {
                          await _signOut();
                        },
                      ),
                    ),
                  ),
                // Summary cards row
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Total',
                        value: stats.total.toString(),
                        icon: Icons.list_alt,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        label: 'Completed',
                        value: stats.completed.toString(),
                        icon: Icons.check_circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Completion indicator
                Text('Completion', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: stats.completionRate),
                const SizedBox(height: 4),
                Text('${(stats.completionRate * 100).toStringAsFixed(1)}%'),
                const SizedBox(height: 24),
                // Milestones section
                Text('Milestones', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...milestones.map(
                      (m) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: Icon(
                        m.achieved ? Icons.emoji_events : Icons.emoji_events_outlined,
                        color: m.achieved ? Colors.amber : null,
                      ),
                      title: Text('${m.threshold} todos completed'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Reusable statistic card used on Dashboard.
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label),
          ],
        ),
      ),
    );
  }
}
