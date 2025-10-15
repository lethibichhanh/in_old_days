// File: event_map_screen.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import '../l10n/app_localizations.dart';

import '../db/db_helper.dart';
import '../models/event.dart';
import 'event_detail_screen.dart';

// --- Khai báo màu sắc Pastel Tươi sáng (Đồng bộ) ---
const Color kPrimaryColor = Color(0xFF81C784); // Xanh Mint Nhẹ (Light Mint)
const Color kAppBarColor = Color(0xFF4DB6AC); // Xanh Mint Đậm hơn
const Color kAccentColor = Color(0xFFFFAB91); // Hồng Đào/Coral Nhạt
const Color kBackgroundColor = Color(0xFFF9F9F9); // Nền trắng ngà
const Color kCardColor = Colors.white;
const Color kTitleTextColor = Color(0xFF424242); // Xám Đen Nhẹ
const Color kSubtextColor = Color(0xFF9E9E9E); // Xám Rất Nhẹ

// Màn hình hiển thị bản đồ và các sự kiện dưới dạng marker
class EventMapScreen extends StatefulWidget {
  final int year;
  final int? month;
  final int? day; // Đã thêm day
  final List<EventModel>? events;
  final int? userId;

  const EventMapScreen({
    super.key,
    required this.year,
    this.month,
    this.day,
    this.events,
    this.userId,
  });

  @override
  State<EventMapScreen> createState() => _EventMapScreenState();
}

class _EventMapScreenState extends State<EventMapScreen> {
  List<EventModel> _events = [];
  bool _loading = true;
  maplibre.MaplibreMapController? _controller;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _controller?.onSymbolTapped.clear();
    super.dispose();
  }

  /// 📦 Load sự kiện từ DB (ĐÃ SỬA LOGIC LỌC NGÀY/THÁNG/NĂM)
  Future<void> _loadEvents() async {
    List<EventModel> events = widget.events ?? [];

    if (widget.events == null) {
      List<Map<String, dynamic>> rawData = [];

      // ✅ LOGIC ĐÃ SỬA ĐỂ ƯU TIÊN LỌC CHÍNH XÁC: Day > Month > Year
      if (widget.day != null && widget.month != null) {
        // 1. Lọc theo ngày cụ thể (Cần đủ Year, Month, Day)
        final selectedDate = DateTime(widget.year, widget.month!, widget.day!);
        rawData = await DBHelper.eventsOfDay(selectedDate);
      } else if (widget.month != null) {
        // 2. Lọc theo tháng (Nếu chỉ có Year và Month)
        rawData = await DBHelper.eventsOfMonth(widget.year, widget.month!);
      } else {
        // 3. Lọc theo năm (Nếu chỉ có Year)
        rawData = await DBHelper.eventsOfYear(widget.year);
      }

      events = rawData.map((e) => EventModel.fromMap(e)).toList();
    }

    // Lọc sự kiện có vị trí (latitude/longitude) hợp lệ
    _events = events.where((e) => e.latitude != null && e.longitude != null && e.eventId != null).toList();
    _events.sort((a, b) => a.eventId!.compareTo(b.eventId!));

    setState(() => _loading = false);
  }

  /// 🖼️ Tải và resize marker icon mặc định MỘT LẦN
  Future<Uint8List> _loadDefaultMarkerImage() async {
    final data = await rootBundle.load('assets/marker.png');
    final bytes = data.buffer.asUint8List();
    final decoded = img.decodeImage(bytes);

    // Resize ảnh về kích thước 80x80 để tăng tính ổn định
    if (decoded != null) {
      final resized = img.copyResize(decoded, width: 80, height: 80);
      return Uint8List.fromList(img.encodePng(resized));
    }
    return bytes;
  }

  /// 🧭 Lọc GeoJSON để loại bỏ các tỉnh trùng nhau (Giữ nguyên)
  Map<String, dynamic> _filterDuplicateProvinceFeatures(Map<String, dynamic> geoJson) {
    final features = geoJson['features'] as List<dynamic>? ?? [];
    final Map<String, dynamic> uniqueFeatures = {};
    final Set<String> uniqueNames = {};
    for (final feature in features) {
      if (feature is Map<String, dynamic> && feature['properties'] is Map<String, dynamic>) {
        final name = feature['properties']['ten_tinh'] ?? feature['properties']['name'];
        if (name != null && name is String && !uniqueNames.contains(name)) {
          uniqueNames.add(name);
          uniqueFeatures[name] = feature;
        }
      }
    }
    return {
      'type': 'FeatureCollection',
      'name': geoJson['name'] ?? 'Vietnam',
      'features': uniqueFeatures.values.toList(),
    };
  }

  /// 🗺️ Thêm lớp bản đồ Việt Nam (Giữ nguyên)
  Future<void> _addProvinceLayers() async {
    if (_controller == null) return;
    const sourceId = 'vn-provinces-source';
    Map<String, dynamic>? geoJson;

    final tr = AppLocalizations.of(context)!;
    final mapError = tr.translate('map_geojson_error');

    try {
      final data = await rootBundle.loadString('assets/vn.json');
      geoJson = jsonDecode(data);
    } catch (_) {
      debugPrint(mapError);
      return;
    }

    if (geoJson == null) return;
    final filtered = _filterDuplicateProvinceFeatures(geoJson);
    await _controller!.addGeoJsonSource(sourceId, filtered);

    // Lớp đường ranh giới
    await _controller!.addLineLayer(sourceId, 'vn-outline', maplibre.LineLayerProperties(
      lineColor: MapHexColor(kPrimaryColor).toHexString(),
      lineWidth: 1.5,
    ));

    // Lớp tên tỉnh
    await _controller!.addSymbolLayer(sourceId, 'vn-label', maplibre.SymbolLayerProperties(
      textField: ['get', 'ten_tinh'],
      textSize: 10,
      textColor: MapHexColor(kTitleTextColor).toHexString(),
      textHaloColor: MapHexColor(kCardColor).toHexString(),
      textHaloWidth: 1.2,
      symbolPlacement: 'point',
      textAllowOverlap: false,
      textIgnorePlacement: false,
      textOpacity: ['interpolate', ['linear'], ['zoom'], 4, 0.0, 5, 0.8, 6, 1.0],
    ));
  }


  /// 📌 Thêm Symbol cho từng Sự kiện (Sử dụng addSymbol) (Giữ nguyên)
  Future<void> _addEventSymbols() async {
    if (_controller == null || _events.isEmpty) return;

    final markerBytes = await _loadDefaultMarkerImage();
    const defaultIconId = "default-event-marker";

    try {
      await _controller!.addImage(defaultIconId, markerBytes);
    } catch (e) {
      debugPrint("❌ Lỗi đăng ký Image mặc định: $e");
      return;
    }

    for (final e in _events) {
      if (e.latitude == null || e.longitude == null || e.eventId == null) continue;

      await _controller!.addSymbol(
        maplibre.SymbolOptions(
          geometry: maplibre.LatLng(e.latitude!, e.longitude!),
          iconImage: defaultIconId,
          iconSize: 2.5,
        ),
        {"eventId": e.eventId.toString()},
      );
    }
    debugPrint("✅ Đã thêm ${_events.length} symbols.");
  }


  /// 🗺️ Tự động xác định vùng zoom theo sự kiện (Giữ nguyên)
  maplibre.LatLngBounds _calculateBounds() {
    if (_events.isEmpty) {
      // Bounds mặc định cho Việt Nam
      return maplibre.LatLngBounds(
        southwest: const maplibre.LatLng(8, 102),
        northeast: const maplibre.LatLng(24, 110),
      );
    }

    double minLat = double.infinity, maxLat = double.negativeInfinity;
    double minLon = double.infinity, maxLon = double.negativeInfinity;

    for (final e in _events) {
      if (e.latitude == null || e.longitude == null) continue;
      if (e.latitude! < minLat) minLat = e.latitude!;
      if (e.latitude! > maxLat) maxLat = e.latitude!;
      if (e.longitude! < minLon) minLon = e.longitude!;
      if (e.longitude! > maxLon) maxLon = e.longitude!;
    }

    return maplibre.LatLngBounds(
      southwest: maplibre.LatLng(minLat - 0.2, minLon - 0.2),
      northeast: maplibre.LatLng(maxLat + 0.2, maxLon + 0.2),
    );
  }

  /// Khi bản đồ được khởi tạo (ĐÃ SỬA: Bỏ zoom tự động)
  Future<void> _onMapCreated(maplibre.MaplibreMapController controller) async {
    _controller = controller;

    // Chờ cho các tác vụ bất đồng bộ hoàn thành
    await Future.wait([
      _addProvinceLayers(),
      _addEventSymbols(),
    ]);

    // ✅ ĐÃ SỬA: Bỏ zoom tự động. Di chuyển về trung tâm VN ở mức zoom mặc định.
    await _controller!.animateCamera(
        maplibre.CameraUpdate.newLatLngZoom(const maplibre.LatLng(16.0, 107.0), 5.0)
    );

    _controller!.onSymbolTapped.add((symbol) {
      final raw = symbol.data?["eventId"];

      if (raw == null) return;
      int? eid = raw is String ? int.tryParse(raw) : (raw is int ? raw : null);

      if (eid == null) return;

      final eventIndex = _events.indexWhere((ev) => ev.eventId == eid);

      if (eventIndex != -1) {
        final event = _events[eventIndex];
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventDetailScreen(eventId: event.eventId!, userId: widget.userId),
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;

    // ✅ KHAI BÁO CÁC CHUỖI DỊCH VÀ XÂY DỰNG TIÊU ĐỀ
    final mapTitlePrefix = tr.translate('map_title_prefix');
    final monthPrefix = tr.translate('month_prefix');
    final dayPrefix = tr.translate('day_prefix');
    final eventCountText = tr.translate('map_event_count');


    final title = StringBuffer(mapTitlePrefix);

    // Cập nhật logic xây dựng tiêu đề
    if (widget.day != null && widget.month != null) {
      // Ví dụ: Sự kiện Ngày 25/10/2025
      title.write(' $dayPrefix ${widget.day}/${widget.month}/${widget.year}');
    } else if (widget.month != null) {
      // Ví dụ: Sự kiện Tháng 10/2025
      title.write(' $monthPrefix ${widget.month}/${widget.year}');
    } else {
      // Ví dụ: Sự kiện Năm 2025
      title.write(' ${widget.year}');
    }


    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(
          title.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: kAppBarColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : Stack(
        children: [
          maplibre.MaplibreMap(
            // ✅ Đảm bảo styleString hợp lệ và có thể tải được
            styleString: 'https://demotiles.maplibre.org/style.json',
            initialCameraPosition: const maplibre.CameraPosition(
              target: maplibre.LatLng(16.0, 107.0), // Trung tâm VN
              zoom: 4.8,
            ),
            onMapCreated: _onMapCreated,
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: kAppBarColor.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '📍 ${_events.length} $eventCountText',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// FIX LỖI CONFLICT: Đổi tên extension thành MapHexColor
extension MapHexColor on Color {
  String toHexString({bool withHash = true}) {
    final hex = value.toRadixString(16).padLeft(8, '0');
    final rgb = hex.substring(2);
    return (withHash ? '#' : '') + rgb;
  }
}