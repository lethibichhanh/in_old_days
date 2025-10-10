// lib/models/historical_figure.dart

import 'package:flutter/foundation.dart';

class HistoricalFigure {
  final int figureId;
  final String name;
  final String? description;
  final String? dob; // Ngày sinh
  final String? dod; // Ngày mất
  final String? imageUrl;

  // ✅ CONSTRUCTOR
  HistoricalFigure({
    required this.figureId,
    required this.name,
    this.description,
    this.dob,
    this.dod,
    this.imageUrl,
  });

  // ================== DB MAPPING ==================

  // ✅ Phương thức toMap() để dùng cho DB Update/Insert
  Map<String, dynamic> toMap() {
    return {
      // figureId cần thiết cho UPDATE
      'figure_id': figureId,
      'name': name,
      'description': description,
      'dob': dob,
      'dod': dod,
      'image_url': imageUrl,
    };
  }

  // ✅ FACTORY FROM MAP (Logic ánh xạ an toàn)
  factory HistoricalFigure.fromMap(Map<String, dynamic> map) {

    // 1. Kiểm tra cột 'name' trước
    final nameString = (map['name'] as dynamic)?.toString();

    if (nameString == null || nameString.isEmpty) {
      // Nếu tên rỗng, in log và trả về đối tượng lỗi để lọc ở DBHelper
      debugPrint("❌ Dữ liệu lỗi: Cột 'name' bị thiếu hoặc rỗng. Trả về đối tượng lỗi.");
      return HistoricalFigure(
        figureId: -99, // Giá trị đặc biệt để DBHelper.getAllFigures() lọc bỏ
        name: "LỖI DỮ LIỆU",
      );
    }

    // 2. Xử lý figureId
    final figureIdString = (map['figure_id'] as dynamic)?.toString();
    final parsedFigureId = int.tryParse(figureIdString ?? '0');

    if (parsedFigureId == null || parsedFigureId == 0) {
      debugPrint("⚠️ Lỗi ánh xạ figureId cho nhân vật: $nameString. figure_id: $figureIdString. Sẽ dùng 0.");
    }

    return HistoricalFigure(
      figureId: parsedFigureId ?? 0,
      name: nameString,
      description: (map['description'] as dynamic)?.toString(),
      dob: (map['dob'] as dynamic)?.toString(),
      dod: (map['dod'] as dynamic)?.toString(),
      imageUrl: (map['image_url'] as dynamic)?.toString(),
    );
  }

  // ================== GETTERS ==================

  // ✅ GETTER lifeSpan
  String get lifeSpan {
    final start = dob ?? '';
    final end = dod ?? '';

    if (start.isEmpty && end.isEmpty) {
      return 'Không rõ năm sinh/mất';
    }

    // Cố gắng trích xuất năm từ chuỗi ngày (có thể là YYYY-MM-DD hoặc YYYY)
    final startYearString = start.length >= 4 ? start.substring(0, 4) : start;
    final endYearString = end.length >= 4 ? end.substring(0, 4) : end;

    final startYear = int.tryParse(startYearString);
    final endYear = int.tryParse(endYearString);

    // Kiểm tra và tính tuổi
    if (startYear != null && endYear != null && startYear <= endYear) {
      final age = endYear - startYear;

      // Hiển thị ngày/năm đầy đủ nếu có, nếu không thì chỉ hiển thị năm
      final dobDisplay = (start.length > 4) ? start : startYear.toString();
      final dodDisplay = (end.length > 4) ? end : endYear.toString();

      return '$dobDisplay - $dodDisplay ($age tuổi)';
    }

    // Trường hợp chỉ có ngày sinh hoặc ngày mất
    if (start.isNotEmpty && end.isEmpty) return 'Sinh năm $start';
    if (start.isEmpty && end.isNotEmpty) return 'Mất năm $end';

    // Trường hợp không tính được tuổi hoặc dữ liệu không hợp lệ (như "TK 10")
    return '$start - $end';
  }
}