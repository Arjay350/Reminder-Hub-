import 'package:flutter/material.dart';

import '../models/diary_models.dart';

class DiaryMoodFilter extends StatelessWidget {
  const DiaryMoodFilter({
    super.key,
    required this.selectedMood,
    required this.onChanged,
  });

  final String? selectedMood;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final menuItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(value: null, child: Text('All Moods')),
      ...DiaryEntry.moods.keys.map(
        (mood) => DropdownMenuItem<String?>(value: mood, child: Text(mood)),
      ),
    ];

    return DropdownButtonFormField<String?>(
      initialValue: selectedMood,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Mood',
        hintText: 'Filter mood',
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: theme.colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      items: menuItems,
      onChanged: (value) => onChanged(value),
      icon: const Icon(Icons.arrow_drop_down),
      dropdownColor: theme.colorScheme.surface,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
    );
  }
}
