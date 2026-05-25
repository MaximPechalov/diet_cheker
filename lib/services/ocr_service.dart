// lib/services/ocr_service.dart
import 'dart:io';

class OcrService {
  // Распознает текст с изображения чека
  // Принимает путь к файлу изображения
  // Возвращает список распознанных строк
  Future<List<String>> recognizeText(String imagePath) async {
    try {
      final File imageFile = File(imagePath);

      // Проверяем, что файл существует
      if (!await imageFile.exists()) {
        throw Exception('Файл изображения не найден: $imagePath');
      }

      // Загружаем изображение в InputImage
      final InputImage inputImage = InputImage.fromFilePath(imagePath);

      // Получаем экземпляр TextRecognizer
      final TextRecognizer textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );

      // Распознаем текст
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

      // Извлекаем строки текста
      final List<String> lines = [];

      for (final TextBlock block in recognizedText.blocks) {
        for (final TextLine line in block.lines) {
          final String text = line.text.trim();

          // Пропускаем пустые строки
          if (text.isNotEmpty) {
            lines.add(text);
          }
        }
      }

      // Закрываем распознаватель для освобождения ресурсов
      textRecognizer.close();

      return lines;
    } catch (e) {
      throw Exception('Ошибка распознавания текста: $e');
    }
  }

  // Распознает текст с камеры в реальном времени
  // Принимает InputImage от камеры
  // Возвращает список распознанных строк
  Future<List<String>> recognizeFromCameraImage(dynamic cameraImage) async {
    try {
      // cameraImage должен быть InputImage из плагина камеры
      final InputImage inputImage = cameraImage as InputImage;

      final TextRecognizer textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );

      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

      final List<String> lines = [];

      for (final TextBlock block in recognizedText.blocks) {
        for (final TextLine line in block.lines) {
          final String text = line.text.trim();
          if (text.isNotEmpty) {
            lines.add(text);
          }
        }
      }

      textRecognizer.close();

      return lines;
    } catch (e) {
      throw Exception('Ошибка распознавания текста с камеры: $e');
    }
  }

  // Фильтрует строки, которые похожи на товарные позиции в чеке
  // Отсеивает служебную информацию (название магазина, ИНН, дату)
  List<String> filterReceiptLines(List<String> allLines) {
    final List<String> productLines = [];

    for (final String line in allLines) {
      // Пропускаем строки, похожие на служебную информацию
      if (_isServiceLine(line)) {
        continue;
      }

      productLines.add(line);
    }

    return productLines;
  }

  // Проверяет, является ли строка служебной информацией
  bool _isServiceLine(String line) {
    final String lowerLine = line.toLowerCase();

    // Признаки служебных строк
    final List<String> servicePatterns = [
      'инн',
      'касса',
      'смена',
      'чек',
      'продажа',
      'итог',
      'сумма',
      'сдача',
      'ндс',
      'кассир',
      'магазин',
      'адрес',
      'телефон',
      'дата',
      'время',
      'ккт',
      'фн',
      'фд',
      'фп',
      'реквизиты',
      'благодарим',
      'спасибо',
      'покуп',
    ];

    for (final String pattern in servicePatterns) {
      if (lowerLine.contains(pattern)) {
        return true;
      }
    }

    // Строки короче 3 символов — скорее всего мусор
    if (line.length < 3) {
      return true;
    }

    // Строки, состоящие только из цифр и спецсимволов
    if (RegExp(r'^[\d\s.,;:!#$%^&*()_+\-=\[\]{}|\\/]+$').hasMatch(line)) {
      return true;
    }

    return false;
  }
}