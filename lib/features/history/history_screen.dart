// lib/features/history/history_screen.dart
import 'package:flutter/material.dart';
import '../../data/models/receipt.dart';
import '../../data/repositories/receipt_repository.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final ReceiptRepository _receiptRepository;
  List<Receipt> _receipts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _receiptRepository = context.read<ReceiptRepository>();
    _loadReceipts();
  }

  Future<void> _loadReceipts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<Receipt> receipts = await _receiptRepository.getAllReceipts();
      setState(() {
        _receipts = receipts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Не удалось загрузить историю: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteReceipt(String id) async {
    await _receiptRepository.deleteReceipt(id);
    _loadReceipts();
  }

  Future<void> _clearAll() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Очистить историю'),
          content: const Text('Удалить все сохраненные чеки? Это действие нельзя отменить.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Удалить все'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _receiptRepository.clearAll();
      _loadReceipts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('История'),
        actions: [
          if (_receipts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearAll,
              tooltip: 'Очистить историю',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: TextStyle(color: Colors.red[700])),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadReceipts,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_receipts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'История пуста',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Отсканируйте первый чек,\nи он появится здесь',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReceipts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _receipts.length,
        itemBuilder: (BuildContext context, int index) {
          final Receipt receipt = _receipts[index];
          return _ReceiptHistoryTile(
            receipt: receipt,
            onDelete: () => _deleteReceipt(receipt.id),
            onTap: () => _openReceiptDetail(context, receipt),
          );
        },
      ),
    );
  }

  void _openReceiptDetail(BuildContext context, Receipt receipt) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => _ReceiptDetailScreen(receipt: receipt),
      ),
    );
  }
}

// Плитка одного чека в истории
class _ReceiptHistoryTile extends StatelessWidget {
  final Receipt receipt;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _ReceiptHistoryTile({
    required this.receipt,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Иконка
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),

              // Информация
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(receipt.scannedAt),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Товаров: ${receipt.totalCount} | Распознано: ${receipt.matchedCount}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    if (receipt.storeName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        receipt.storeName!,
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),

              // Кнопка удаления
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: Colors.grey[400],
                onPressed: onDelete,
                tooltip: 'Удалить',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Только что';
    } else if (difference.inHours < 1) {
      final int minutes = difference.inMinutes;
      return '$minutes ${_pluralize(minutes, 'минуту', 'минуты', 'минут')} назад';
    } else if (difference.inDays < 1) {
      final int hours = difference.inHours;
      return '$hours ${_pluralize(hours, 'час', 'часа', 'часов')} назад';
    } else if (difference.inDays == 1) {
      return 'Вчера';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${_pluralize(difference.inDays, 'день', 'дня', 'дней')} назад';
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }

  String _pluralize(int count, String one, String two, String five) {
    if (count % 10 == 1 && count % 100 != 11) return one;
    if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) return two;
    return five;
  }
}

// Экран детального просмотра чека из истории
class _ReceiptDetailScreen extends StatelessWidget {
  final Receipt receipt;

  const _ReceiptDetailScreen({required this.receipt});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Чек от ${_formatDate(receipt.scannedAt)}'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: receipt.items.length,
        itemBuilder: (BuildContext context, int index) {
          final ScannedItem item = receipt.items[index];
          return ListTile(
            title: Text(item.rawText),
            subtitle: item.matchedProduct != null
                ? Text('${item.matchedProduct!.category} → ${item.matchedProduct!.key}')
                : const Text('Не распознано'),
            leading: Icon(
              item.isMatched ? Icons.check_circle : Icons.help_circle,
              color: item.isMatched ? Colors.green : Colors.orange,
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}