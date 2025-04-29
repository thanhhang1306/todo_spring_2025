import 'package:flutter/material.dart';

class FilterSheetResult {
  final String sortBy;
  final String order;
  final String priority;
  final DateTime? startDate;
  final DateTime? endDate;

  FilterSheetResult({
    required this.sortBy,
    required this.order,
    required this.priority,
    this.startDate,
    this.endDate,
  });
}

class FilterSheet extends StatefulWidget {
  const FilterSheet({
    required this.initialFilters,
    super.key,
  });

  final FilterSheetResult initialFilters;

  @override
  _FilterSheetState createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  String _sortBy = 'date';
  String _order = 'ascending';
  String _priority = 'all';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _sortBy = widget.initialFilters.sortBy;
    _order = widget.initialFilters.order;
    _priority = widget.initialFilters.priority;
    _startDate = widget.initialFilters.startDate;
    _endDate = widget.initialFilters.endDate;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 16, left: 32, right: 32, bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Filters',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: _sortBy,
                  items: const [
                    DropdownMenuItem(value: 'date', child: Text('Date')),
                    DropdownMenuItem(value: 'completed', child: Text('Completed')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _sortBy = value ?? _sortBy;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButton<String>(
                  value: _order,
                  items: const [
                    DropdownMenuItem(value: 'ascending', child: Text('Ascending')),
                    DropdownMenuItem(value: 'descending', child: Text('Descending')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _order = value ?? _order;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Priority dropdown
          Row(
            children: [
              const Text('Priority:'),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButton<String>(
                  value: _priority,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Priorities')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _priority = value ?? _priority;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Date range pickers
          ListTile(
            title: Text(
              'From: ${_startDate != null ? _startDate!.toLocal().toString().split(' ')[0] : 'Any'}',
            ),
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
            title: Text(
              'To:   ${_endDate != null ? _endDate!.toLocal().toString().split(' ')[0] : 'Any'}',
            ),
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
          ElevatedButton(
            onPressed: () {
              Navigator.pop(
                context,
                FilterSheetResult(
                  sortBy: _sortBy,
                  order: _order,
                  priority: _priority,
                  startDate: _startDate,
                  endDate: _endDate,
                ),
              );
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
