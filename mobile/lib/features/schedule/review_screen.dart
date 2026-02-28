import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'schedule_provider.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.item});
  final ScheduleItem item;
  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  int _quality = 10;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      appBar: AppBar(title: Text(item.surahName)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.arabic, style: const TextStyle(fontSize: 28), textDirection: TextDirection.rtl),
            const SizedBox(height: 16),
            Text('Pages ${item.startPage.toStringAsFixed(1)} - ${item.endPage.toStringAsFixed(1)}'),
            const Spacer(),
            Text('Quality: $_quality / 20', style: Theme.of(context).textTheme.titleMedium),
            Slider(value: _quality.toDouble(), min: 1, max: 20, divisions: 19,
              label: '$_quality', onChanged: (v) => setState(() => _quality = v.round())),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  await ref.read(scheduleProvider.notifier).markDone(item.id, _quality);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Mark Complete'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
