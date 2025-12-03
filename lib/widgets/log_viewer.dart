import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/log_provider.dart';

class LogViewerButton extends ConsumerWidget {
  const LogViewerButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(logProvider);
    final hasErrors = logs.any((l) => l.level == 'ERROR');

    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.article_outlined),
          tooltip: 'View Logs',
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => const LogViewerDialog(),
            );
          },
        ),
        if (hasErrors)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class LogViewerDialog extends ConsumerWidget {
  const LogViewerDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(logProvider);

    return Dialog(
      child: Container(
        width: 700,
        height: 500,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Application Logs',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    final logText = logs
                        .map((l) =>
                            '[${l.formattedTime}] ${l.level}: ${l.message}${l.details != null ? '\n  ${l.details}' : ''}')
                        .join('\n');
                    Clipboard.setData(ClipboardData(text: logText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Logs copied to clipboard')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy All'),
                ),
                TextButton.icon(
                  onPressed: () {
                    ref.read(logProvider.notifier).clear();
                  },
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Clear'),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: logs.isEmpty
                  ? const Center(
                      child: Text(
                        'No logs yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        return _LogEntryCard(log: log);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogEntryCard extends StatelessWidget {
  final LogEntry log;

  const _LogEntryCard({required this.log});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildLevelBadge(),
                const SizedBox(width: 8),
                Text(
                  log.formattedTime,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontFamily: 'monospace',
                  ),
                ),
                const Spacer(),
                if (log.details != null)
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: '${log.message}\n${log.details}'));
                    },
                    tooltip: 'Copy',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              log.message,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            if (log.details != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  log.details!,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLevelBadge() {
    Color color;
    switch (log.level) {
      case 'ERROR':
        color = Colors.red;
        break;
      case 'WARN':
        color = Colors.orange;
        break;
      case 'SUCCESS':
        color = Colors.green;
        break;
      default:
        color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        log.level,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
