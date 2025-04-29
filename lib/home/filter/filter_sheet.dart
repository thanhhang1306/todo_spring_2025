import 'package:flutter/material.dart';

/// Captures sort, order, priority, date-range, and label filters.
class FilterSheetResult {
  final String sortBy;
  final String order;
  final String priority;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> labels;

  FilterSheetResult({
    required this.sortBy,
    required this.order,
    required this.priority,
    this.startDate,
    this.endDate,
    this.labels = const [],
  });
}

/// Bottom-sheet allowing the user to set filters, including labels.
class FilterSheet extends StatefulWidget {
  const FilterSheet({
    required this.initialFilters,
    Key? key,
  }) : super(key: key);

  final FilterSheetResult initialFilters;

  @override
  _FilterSheetState createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late String _sortBy;
  late String _order;
  late String _priority;
  DateTime? _startDate;
  DateTime? _endDate;
  late Set<String> _labels;

  final List<String> _allLabels = ['Work', 'Personal', 'Urgent', 'Shopping'];

  @override
  void initState() {
    super.initState();
    _sortBy = widget.initialFilters.sortBy;
    _order = widget.initialFilters.order;
    _priority = widget.initialFilters.priority;
    _startDate = widget.initialFilters.startDate;
    _endDate = widget.initialFilters.endDate;
    _labels = widget.initialFilters.labels.toSet();
  }

  void _resetFilters() {
    setState(() {
      _sortBy = 'date';
      _order = 'descending';
      _priority = 'all';
      _startDate = null;
      _endDate = null;
      _labels.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Ensure the sheet avoids keyboard and overflows by becoming scrollable
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          top: 16,
          left: 32,
          right: 32,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Filters', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            // Sort & Order
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                      value: _sortBy,
                      items: const [
                        DropdownMenuItem(value: 'date', child: Text('Date')),
                        DropdownMenuItem(value: 'completed', child: Text('Completed')),
                      ],
                      onChanged: (v) => setState(() => _sortBy = v!)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButton<String>(
                      value: _order,
                      items: const [
                        DropdownMenuItem(value: 'ascending', child: Text('Ascending')),
                        DropdownMenuItem(value: 'descending', child: Text('Descending')),
                      ],
                      onChanged: (v) => setState(() => _order = v!)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Priority
            Row(
              children: [
                const Text('Priority:'),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButton<String>(
                      value: _priority,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                        DropdownMenuItem(value: 'medium', child: Text('Medium')),
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                      ],
                      onChanged: (v) => setState(() => _priority = v!)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Date pickers
            ListTile(
              title: Text('From: ${_startDate != null ? _startDate!.toLocal().toString().split(' ')[0] : 'Any'}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _startDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2050),
                );
                if (d != null) setState(() => _startDate = d);
              },
            ),
            ListTile(
              title: Text('To:   ${_endDate != null ? _endDate!.toLocal().toString().split(' ')[0] : 'Any'}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _endDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2050),
                );
                if (d != null) setState(() => _endDate = d);
              },
            ),
            const SizedBox(height: 16),
            // Label chips
            Align(alignment: Alignment.centerLeft, child: Text('Labels:', style: Theme.of(context).textTheme.bodyMedium)),
            Wrap(
              spacing: 8,
              children: _allLabels.map((lbl) => FilterChip(
                label: Text(lbl),
                selected: _labels.contains(lbl),
                onSelected: (sel) => setState(() => sel ? _labels.add(lbl) : _labels.remove(lbl)),
              )).toList(),
            ),
            const SizedBox(height: 24),
            // Buttons
            Row(
              children: [
                TextButton(onPressed: _resetFilters, child: const Text('Reset')),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => Navigator.pop(
                    context,
                    FilterSheetResult(
                      sortBy: _sortBy,
                      order: _order,
                      priority: _priority,
                      startDate: _startDate,
                      endDate: _endDate,
                      labels: _labels.toList(),
                    ),
                  ),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
