// lib/features/scanner/controller/scanner_controller.dart
import 'package:flutter/material.dart';
import '../../../domain/usecases/scan_receipt.dart';
import '../../../data/models/receipt.dart';
import '../../../services/ocr_service.dart';
import '../../../data/repositories/receipt_repository.dart';
import 'dart:io';

class ScannerController extends ChangeNotifier {
  final ScanReceiptUseCase _scanReceiptUseCase;
  final OcrService _ocrService;
  final ReceiptRepository _receiptRepository;

  // Состояния экрана сканера
  bool _isProcessing = false;
  String? _errorMessage;
  Receipt? _currentReceipt;

  // Выбранные диеты (загружаются из настроек)
  List<String> _activeDiets = [];

  ScannerController({
    required ScanReceiptUseCase scanReceiptUseCase,
    required OcrService ocrService,
    required ReceiptRepository receiptRepository,
  })  : _scanReceiptUseCase = scanReceiptUseCase,
        _ocrService = ocrService,
        _receiptRepository = receiptRepository;

  // Геттеры для UI
  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;
  Receipt? get currentReceipt => _currentReceipt;
  List<String> get activeDiets => _activeDiets;

  // Установка активных диет (вызывается при входе на экран сканера)
  void setActiveDiets(List<String> diets) {
    _activeDiets = diets;
    notifyListeners();
  }

  // Главный метод: сканирование чека по пути к фото
  Future<void> scanReceiptFromFile(String imagePath) async {
    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Шаг 1: Проверяем, что файл существует
      final File file = File(imagePath);
      if (!await file.exists()) {
        throw Exception('Файл не найден');
      }

      // Шаг 2: Распознаем текст через OCR
      final List<String> allLines = await _ocrService.recognizeText(imagePath);

      if (allLines.isEmpty) {
        throw Exception('Не удалось распознать текст на изображении');
      }

      // Шаг 3: Отфильтровываем служебные строки
      final List<String> productLines = _ocrService.filterReceiptLines(allLines);

      if (productLines.isEmpty) {
        throw Exception('Не найдено товарных позиций в чеке');
      }

      // Шаг 4: Анализируем чек через юзкейс
      _currentReceipt = _scanReceiptUseCase.execute(productLines, _activeDiets);

      // Шаг 5: Сохраняем чек в историю
      await _receiptRepository.saveReceipt(_currentReceipt!);

    } catch (e) {
      _errorMessage = e.toString();
      _currentReceipt = null;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  // Метод для real-time сканирования с камеры
  Future<void> scanFromCameraImage(dynamic cameraImage) async {
    if (_isProcessing) return;

    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Шаг 1: Распознаем текст с кадра камеры
      final List<String> allLines = await _ocrService.recognizeFromCameraImage(cameraImage);

      // Шаг 2: Фильтруем строки
      final List<String> productLines = _ocrService.filterReceiptLines(allLines);

      if (productLines.isEmpty) return;

      // Шаг 3: Анализируем
      _currentReceipt = _scanReceiptUseCase.execute(productLines, _activeDiets);

      // Шаг 4: Сохраняем
      await _receiptRepository.saveReceipt(_currentReceipt!);

    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  // Сброс результатов (для нового сканирования)
  void reset() {
    _currentReceipt = null;
    _errorMessage = null;
    _isProcessing = false;
    notifyListeners();
  }

  // Очистка ошибки
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}