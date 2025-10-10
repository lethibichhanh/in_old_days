import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;

import '../db/db_helper.dart';
import '../models/event.dart';
import 'event_detail_screen.dart';

// Màn hình hiển thị bản đồ và các sự kiện dưới dạng marker
class EventMapScreen extends StatefulWidget {
  final int year;
  final int? month;
  final int? day;
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

  /// 📦 Load sự kiện từ DB
  Future<void> _loadEvents() async {
    List<EventModel> events = widget.events ?? [];

    if (widget.events == null) {
      List<Map<String, dynamic>> rawData;
      if (widget.month == null) {
        rawData = await DBHelper.eventsOfYear(widget.year);
      } else {
        rawData = await DBHelper.eventsOfMonth(widget.year, widget.month!);
      }

      events = rawData.map((e) => EventModel.fromMap(e)).toList();

      if (widget.day != null) {
        events = events.where((e) {
          if (e.date == null) return false;
          return e.date!.year == widget.year &&
              e.date!.month == widget.month &&
              e.date!.day == widget.day;
        }).toList();
      }
    }

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

  /// 🧭 Lọc GeoJSON để loại bỏ các tỉnh trùng nhau
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

  /// 🗺️ Thêm lớp bản đồ Việt Nam
  Future<void> _addProvinceLayers() async {
    if (_controller == null) return;
    const sourceId = 'vn-provinces-source';
    Map<String, dynamic>? geoJson;
    try {
      final data = await rootBundle.loadString('assets/vn.json');
      geoJson = jsonDecode(data);
    } catch (_) {
      debugPrint("⚠️ Không tìm thấy file GeoJSON trong assets/vn.json");
      return;
    }

    if (geoJson == null) return;
    final filtered = _filterDuplicateProvinceFeatures(geoJson);
    await _controller!.addGeoJsonSource(sourceId, filtered);

    // Lớp đường ranh giới
    await _controller!.addLineLayer(sourceId, 'vn-outline', maplibre.LineLayerProperties(lineColor: '#006666', lineWidth: 1.2,));
    // Lớp tên tỉnh
    await _controller!.addSymbolLayer(sourceId, 'vn-label', maplibre.SymbolLayerProperties(
      textField: ['get', 'ten_tinh'],
      textSize: 10,
      textColor: '#222222',
      textHaloColor: '#FFFFFF',
      textHaloWidth: 1.2,
      symbolPlacement: 'point',
      textAllowOverlap: false,
      textIgnorePlacement: false,
      textOpacity: ['interpolate', ['linear'], ['zoom'], 4, 0.0, 5, 0.8, 6, 1.0],
    ));
  }


  /// 📌 Thêm Symbol cho từng Sự kiện (Sử dụng addSymbol)
  Future<void> _addEventSymbols() async {
    if (_controller == null || _events.isEmpty) return;

    final markerBytes = await _loadDefaultMarkerImage();
    const defaultIconId = "default-event-marker";

    try {
      // Thêm ảnh marker MỘT LẦN VÀO BẢN ĐỒ
      await _controller!.addImage(defaultIconId, markerBytes);
    } catch (e) {
      debugPrint("❌ Lỗi đăng ký Image mặc định: $e");
      return;
    }

    // Thêm từng Symbol
    for (final e in _events) {
      if (e.latitude == null || e.longitude == null || e.eventId == null) continue;

      await _controller!.addSymbol(
        maplibre.SymbolOptions(
          geometry: maplibre.LatLng(e.latitude!, e.longitude!),
          iconImage: defaultIconId,
          // Tăng iconSize để mở rộng vùng chạm (hitbox) và dễ bấm hơn
          iconSize: 2.5,
        ),
        // Dữ liệu cho Symbol Tapped
        {"eventId": e.eventId.toString()},
      );
    }
    debugPrint("✅ Đã thêm ${_events.length} symbols.");
  }


  /// 🗺️ Tự động xác định vùng zoom theo sự kiện
  maplibre.LatLngBounds _calculateBounds() {
    if (_events.isEmpty) {
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

    // Thêm padding nhẹ
    return maplibre.LatLngBounds(
      southwest: maplibre.LatLng(minLat - 0.2, minLon - 0.2),
      northeast: maplibre.LatLng(maxLat + 0.2, maxLon + 0.2),
    );
  }

  /// Khi bản đồ được khởi tạo
  Future<void> _onMapCreated(maplibre.MaplibreMapController controller) async {
    _controller = controller;

    await _addProvinceLayers();

    // Thêm các Marker Sự kiện
    await _addEventSymbols();

    // Tự zoom
    final bounds = _calculateBounds();
    if (_events.isNotEmpty) {
      await _controller!.animateCamera(maplibre.CameraUpdate.newLatLngBounds(bounds,
          top: 150, bottom: 200, left: 50, right: 50));
    }

    // Xử lý chạm Marker (Symbol)
    _controller!.onSymbolTapped.add((symbol) {
      final raw = symbol.data?["eventId"];

      if (raw == null) return;

      // Đảm bảo eventId là kiểu int
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
    final title = StringBuffer('🗺️ Sự kiện — ${widget.year}');
    if (widget.month != null) title.write(' / Tháng ${widget.month}');
    if (widget.day != null) title.write(' / Ngày ${widget.day}');

    return Scaffold(
      appBar: AppBar(title: Text(title.toString())),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          maplibre.MaplibreMap(
            styleString: 'https://demotiles.maplibre.org/style.json',
            initialCameraPosition: const maplibre.CameraPosition(
              target: maplibre.LatLng(16.0, 106.0),
              zoom: 4.8,
            ),
            onMapCreated: _onMapCreated,
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '📍 ${_events.length} sự kiện có vị trí',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}