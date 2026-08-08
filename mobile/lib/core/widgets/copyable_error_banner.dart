import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Selectable + one-tap copy error banner for AI / network failures.
class CopyableErrorBanner extends StatelessWidget {
  const CopyableErrorBanner({super.key, required this.message});

  final String message;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: message));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Hata panoya kopyalandı'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.error_outline_rounded, color: Colors.red.shade400),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              message,
              style: TextStyle(color: Colors.red.shade700, height: 1.35),
            ),
          ),
          IconButton(
            tooltip: 'Kopyala',
            onPressed: () => _copy(context),
            icon: Icon(Icons.copy_rounded, size: 18, color: Colors.red.shade400),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
