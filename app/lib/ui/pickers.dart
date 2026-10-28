import 'package:flutter/material.dart';

/// A dialog listing options; returns the chosen key.
Future<String?> pickOption(
    BuildContext context, String title, Map<String, String> options, String current) {
  return showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: [
        RadioGroup<String>(
          groupValue: current,
          onChanged: (v) => Navigator.pop(context, v),
          child: Column(
            children: [
              for (final e in options.entries)
                RadioListTile<String>(value: e.key, title: Text(e.value)),
            ],
          ),
        ),
      ],
    ),
  );
}

/// A dialog with a stepper for a whole number.
Future<int?> pickNumber(BuildContext context, String title, int current, int min, int max,
    {int step = 1}) {
  var value = current;
  return showDialog<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: NumberStepper(
          value: value,
          min: min,
          max: max,
          step: step,
          onChanged: (v) => setState(() => value = v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, value), child: const Text('Save')),
        ],
      ),
    ),
  );
}

class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    this.suffix = '',
  });

  final int value;
  final int min;
  final int max;
  final int step;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton.filledTonal(
            iconSize: 30,
            onPressed: value - step >= min ? () => onChanged(value - step) : null,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 120,
            child: Text('$value$suffix',
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.displaySmall),
          ),
          IconButton.filledTonal(
            iconSize: 30,
            onPressed: value + step <= max ? () => onChanged(value + step) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      );
}
