// lib/domain/usecases/scan_receipt.dart
import '../../data/datasources/local_database.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/models/receipt.dart';
import '../../data/models/scanned_item.dart';
import '../../data/models/product.dart';
import '../../data/models/diet_rule.dart';

class ScanReceiptUseCase {
  final ProductRepository _productRepository;

  ScanReceiptUseCase(this._productRepository);

  // Главный метод: принимает сырые строки из OCR, возвращает готовый чек с анализом
  Receipt execute(List<String> rawLines, List<String> activeDiets) {
    // Шаг 1: Создаем чек из сырых строк
    Receipt receipt = Receipt.fromRawLines(rawLines);

    // Шаг 2: Нормализуем каждую строку и ищем продукт в базе
    final List<ScannedItem> analyzedItems = [];

    for (final ScannedItem item in receipt.items) {
      // Нормализация строки: удаляем бренды, вес, приводим к нижнему регистру
      final String normalized = _normalizeLine(item.rawText);

      // Ищем продукт сначала по точному ключу, потом по токенам
      Product? matchedProduct = _productRepository.findByKey(normalized);

      if (matchedProduct == null) {
        matchedProduct = _productRepository.findByNormalizedText(normalized);
      }

      // Шаг 3: Если продукт найден, считаем вердикты для активных диет
      Map<String, DietRule>? dietResults;
      if (matchedProduct != null) {
        dietResults = _calculateDietResults(matchedProduct, activeDiets);
      }

      // Обновляем элемент чека с результатами анализа
      analyzedItems.add(
        item.copyWith(
          normalizedText: normalized,
          matchedProduct: matchedProduct,
          dietResults: dietResults,
        ),
      );
    }

    // Возвращаем обновленный чек
    return receipt.copyWith(items: analyzedItems);
  }

  // Нормализация строки чека по правилам из базы
  String _normalizeLine(String rawLine) {
    String normalized = rawLine;

    // Правило 1: Удаляем слова ЦЕЛИКОМ заглавными буквами (бренды)
    normalized = normalized.replaceAll(RegExp(r'\b[A-ZА-Я]{2,}\b'), '');

    // Правило 2: Удаляем вес/объем в конце (180г, 200мл, 1л, 1кг, 0.5кг)
    normalized = normalized.replaceAll(RegExp(r'\d+\.?\d*\s*(г|мл|л|кг|шт)\b'), '');

    // Правило 3: Удаляем ТМ, ТЗ, АО, ООО, кавычки, звездочки
    normalized = normalized.replaceAll(RegExp(r'\b(ТМ|ТЗ|АО|ООО|ОАО|ЗАО|ИП)\b'), '');
    normalized = normalized.replaceAll(RegExp(r'["«»\*]'), '');

    // Правило 4: Приводим к нижнему регистру
    normalized = normalized.toLowerCase();

    // Правило 5: Удаляем всё после запятой
    if (normalized.contains(',')) {
      normalized = normalized.split(',').first;
    }

    // Правило 6: Удаляем лишние пробелы
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();

    return normalized;
  }

  // Расчет вердиктов диет для найденного продукта
  Map<String, DietRule> _calculateDietResults(Product product, List<String> activeDiets) {
    final Map<String, DietRule> results = {};

    for (final String dietKey in activeDiets) {
      final DietRule? rule = product.getRule(dietKey);

      if (rule != null) {
        results[dietKey] = rule;
      } else {
        // Если для диеты нет правила, считаем продукт разрешенным по умолчанию
        results[dietKey] = const DietRule(
          verdict: 'allowed',
          condition: null,
          reason: null,
        );
      }
    }

    return results;
  }
}