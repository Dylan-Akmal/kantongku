import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/month.dart';

class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({super.key, required this.month, required this.onChanged});

  final String month;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Bulan sebelumnya',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(shiftMonth(month, -1)),
        ),
        SizedBox(
          width: 170,
          child: Text(
            formatMonthLabel(month),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          tooltip: 'Bulan berikutnya',
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onChanged(shiftMonth(month, 1)),
        ),
      ],
    );
  }
}