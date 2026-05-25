// lib/features/scanner/scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controller/scanner_controller.dart';
import 'result_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ScannerController>(
      create: (BuildContext context) => ScannerController(
        scanReceiptUseCase: context.read<ScanReceiptUseCase>(),
        ocrService: context.read<OcrService>(),
        receiptRepository: context.read<ReceiptRepository>(),
      ),
      child: Consumer<ScannerController>(
        builder: (BuildContext context, ScannerController controller, Widget? child) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Сканер чека'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => _showScanTips(context),
                ),
              ],
            ),
            body: Column(
              children: [
                // Область камеры
                Expanded(
                  flex: 2,
                  child: _CameraPreview(controller: controller),
                ),

                // Блок с информацией
                Expanded(
                  flex: 1,
                  child: _ScanInfoPanel(controller: controller),
                ),
              ],
            ),
            bottomNavigationBar: _BottomScanButton(controller: controller),
          );
        },
      ),
    );
  }

  void _showScanTips(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Как сканировать'),
          content: const Text(
            '1. Положите чек на ровную поверхность\n'
            '2. Убедитесь, что текст хорошо освещен\n'
            '3. Держите камеру прямо над чеком\n'
            '4. Чек должен полностью помещаться в рамку\n'
            '5. Избегайте бликов и теней',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Понятно'),
            ),
          ],
        );
      },
    );
  }
}

// Виджет области камеры
class _CameraPreview extends StatelessWidget {
  final ScannerController controller;

  const _CameraPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.document_scanner,
              size: 80,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Наведите камеру на чек',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
            if (controller.isProcessing)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: CircularProgressIndicator(color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}

// Панель с информацией о выбранных диетах
class _ScanInfoPanel extends StatelessWidget {
  final ScannerController controller;

  const _ScanInfoPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Активные диеты:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (controller.activeDiets.isEmpty)
            Text(
              'Диеты не выбраны. Перейдите в настройки.',
              style: TextStyle(color: Colors.grey[600]),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: controller.activeDiets.map((String diet) {
                return Chip(
                  label: Text(_dietDisplayName(diet)),
                  backgroundColor: _dietColor(diet),
                  labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                );
              }).toList(),
            ),

          const Spacer(),

          // Сообщение об ошибке
          if (controller.errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      controller.errorMessage!,
                      style: TextStyle(color: Colors.red[700], fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => controller.clearError(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _dietDisplayName(String dietKey) {
    const Map<String, String> names = {
      'no_sugar': 'Без сахара',
      'keto': 'Кето',
      'low_fodmap': 'Low-FODMAP',
      'lactose_free': 'Без лактозы',
    };
    return names[dietKey] ?? dietKey;
  }

  Color _dietColor(String dietKey) {
    const Map<String, Color> colors = {
      'no_sugar': Color(0xFF42A5F5),
      'keto': Color(0xFFFF7043),
      'low_fodmap': Color(0xFFAB47BC),
      'lactose_free': Color(0xFF26A69A),
    };
    return colors[dietKey] ?? Colors.grey;
  }
}

// Кнопка сканирования
class _BottomScanButton extends StatelessWidget {
  final ScannerController controller;

  const _BottomScanButton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            onPressed: controller.isProcessing
                ? null
                : () => _onScanPressed(context),
            icon: controller.isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.camera_alt),
            label: Text(
              controller.isProcessing ? 'Обработка...' : 'Сканировать чек',
              style: const TextStyle(fontSize: 18),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onScanPressed(BuildContext context) {
    // Заглушка: симулируем сканирование тестовыми данными
    controller.scanReceiptFromFile('test_receipt.jpg');

    // В реальном приложении здесь будет:
    // 1. Открытие камеры
    // 2. Получение фото
    // 3. Передача пути в controller.scanReceiptFromFile(path)
  }
}