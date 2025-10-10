import 'package:flutter/foundation.dart';

/// 📌 Model đại diện cho một sự kiện lịch sử
class EventModel {
  final int? eventId;

  /// 🏷️ Tiêu đề và mô tả
  final String title;
  final String description;

  /// 🗓️ Thông tin ngày tháng, năm
  final DateTime? date;
  final int? year;

  /// 📍 Thông tin vị trí
  final int? locationId;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final String? region;

  /// 🖼️ Các trường bổ sung
  final String? imageUrl;
  final String? source;

  EventModel({
    this.eventId,
    required this.title,
    required this.description,
    this.date,
    this.year,
    this.locationId,
    this.latitude,
    this.longitude,
    this.locationName,
    this.region,
    this.imageUrl,
    this.source,
  });

  /// ✅ Parse từ Map (row SQLite) -> EventModel
  factory EventModel.fromMap(Map<String, dynamic> m) {
    // --- ID sự kiện ---
    int? eventIdValue;
    if (m['event_id'] != null) {
      eventIdValue = m['event_id'] is int
          ? m['event_id']
          : int.tryParse(m['event_id'].toString());
    }

    // --- Title & Description ---
    String titleValue = (m['title'] ?? '').toString().trim();
    String descriptionValue = (m['description'] ?? '').toString().trim();

    // --- Parse Date ---
    DateTime? dt;
    if (m['date'] != null) {
      final rawDate = m['date'].toString().replaceAll('/', '-').trim();
      try {
        dt = DateTime.tryParse(rawDate);
      } catch (e) {
        if (kDebugMode) {
          debugPrint("⚠️ Lỗi parse ngày từ DB: $rawDate → $e");
        }
      }
    }

    // --- Parse Year ---
    int? yearValue;
    if (m['year'] != null) {
      yearValue = m['year'] is int
          ? m['year']
          : int.tryParse(m['year'].toString());
    }

    // --- Parse Location ID ---
    int? locationIdValue;
    if (m['location_id'] != null) {
      locationIdValue = m['location_id'] is int
          ? m['location_id']
          : int.tryParse(m['location_id'].toString());
    }

    // --- Parse Tọa độ ---
    double? lat;
    double? lon;
    if (m['latitude'] != null) {
      lat = m['latitude'] is num
          ? (m['latitude'] as num).toDouble()
          : double.tryParse(m['latitude'].toString());
    }
    if (m['longitude'] != null) {
      lon = m['longitude'] is num
          ? (m['longitude'] as num).toDouble()
          : double.tryParse(m['longitude'].toString());
    }

    // --- Parse Image ---
    String? imagePath = m['image_url']?.toString().trim();
    if (imagePath != null && imagePath.isNotEmpty) {
      imagePath = imagePath.replaceAll("\\", "/");
    }

    return EventModel(
      eventId: eventIdValue,
      title: titleValue,
      description: descriptionValue,
      date: dt,
      year: yearValue,
      locationId: locationIdValue,
      imageUrl: imagePath,
      source: m['source']?.toString(),
      latitude: lat,
      longitude: lon,
      locationName: m['locationName']?.toString(), // ✅ đúng theo DB
      region: m['region']?.toString(),
    );
  }

  /// ✅ Convert model -> Map (để insert/update DB)
  Map<String, dynamic> toMap() {
    return {
      'event_id': eventId,
      'title': title,
      'description': description,
      'date': date?.toIso8601String(),
      'year': year,
      'location_id': locationId,
      'image_url': imageUrl,
      'source': source,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName, // ✅ giữ nguyên tên đúng DB
      'region': region,
    };
  }

  /// 👉 Hàm hỗ trợ hiển thị nhanh tóm tắt
  String get shortDescription {
    if (description.length > 100) {
      return description.substring(0, 100) + "...";
    }
    return description;
  }

  /// 👉 copyWith để update 1 phần
  EventModel copyWith({
    int? eventId,
    String? title,
    String? description,
    DateTime? date,
    int? year,
    int? locationId,
    double? latitude,
    double? longitude,
    String? locationName,
    String? region,
    String? imageUrl,
    String? source,
  }) {
    return EventModel(
      eventId: eventId ?? this.eventId,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      year: year ?? this.year,
      locationId: locationId ?? this.locationId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      region: region ?? this.region,
      imageUrl: imageUrl ?? this.imageUrl,
      source: source ?? this.source,
    );
  }

  /// 👉 Tạo Event rỗng (dùng khi không tìm thấy)
  factory EventModel.empty() {
    return EventModel(
      eventId: null,
      title: "Không rõ",
      description: "Không có dữ liệu",
    );
  }

  @override
  String toString() {
    return "EventModel(id: $eventId, title: $title, date: $date, lat: $latitude, lon: $longitude, location: $locationName, imageUrl: $imageUrl)";
  }
}
