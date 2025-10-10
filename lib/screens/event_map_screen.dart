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
  final int? userId; // Dùng để truyền cho EventDetailScreen

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
    // Luôn dọn dẹp controller
    _controller?.onSymbolTapped.clear();
    _controller = null;
    super.dispose();
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

  /// 📦 Load sự kiện từ DB (Giữ nguyên)
  Future<void> _loadEvents() async {
    List<EventModel> events = [];

    if (widget.events != null) {
      events = widget.events!;
    } else {
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

    // Lọc các sự kiện có tọa độ hợp lệ
    _events = events.where((e) => e.latitude != null && e.longitude != null && e.eventId != null).toList();
    _events.sort((a, b) => a.eventId!.compareTo(b.eventId!));

    debugPrint("Đã tải ${_events.length} sự kiện có vị trí hợp lệ.");

    setState(() => _loading = false);
  }

  /// 🖼️ Tải ảnh marker từ assets
  Future<Uint8List?> _loadImageFromAssets(String relativePath) async {
    try {
      String path = relativePath.replaceAll("\\", "/").replaceAll('-', '_');

      if (!path.startsWith('assets/')) {
        path = 'assets/Image/$path';
      }

      List<String> candidates = [];
      if (path.endsWith(".png") || path.endsWith(".jpg") || path.endsWith(".jpeg")) {
        candidates.add(path);
      } else {
        candidates.add("$path.png");
        candidates.add("$path.jpg");
      }

      for (var p in candidates) {
        try {
          final data = await rootBundle.load(p);
          final bytes = data.buffer.asUint8List();
          final decoded = img.decodeImage(bytes);
          if (decoded != null) {
            // ✅ GIẢM KÍCH THƯỚC: Resize ảnh marker về kích thước nhỏ hơn (ví dụ 60x60) để tăng tính ổn định
            final resized = img.copyResize(decoded, width: 60, height: 60);
            return Uint8List.fromList(img.encodePng(resized));
          }
        } catch (_) {
          // Tiếp tục thử ứng viên tiếp theo
        }
      }

      return null;
    } catch (e) {
      debugPrint("⚠️ Không thể tải ảnh $relativePath: $e");
      return null;
    }
  }

  /// 📌 Ảnh mặc định khi không có ảnh sự kiện
  Future<Uint8List> _loadFallbackAsset() async {
    try {
      final byteData = await rootBundle.load('assets/marker.png');
      final bytes = byteData.buffer.asUint8List();
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        // ✅ GIẢM KÍCH THƯỚC: Resize ảnh marker về kích thước nhỏ hơn (ví dụ 60x60)
        final resized = img.copyResize(decoded, width: 60, height: 60);
        return Uint8List.fromList(img.encodePng(resized));
      }
      return Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 2, 0, 0, 0, 105, 203, 61, 19, 0, 0, 0, 13, 73, 68, 65, 84, 8, 215, 99, 100, 12, 0, 0, 0, 130, 0, 1, 0, 2, 0, 1, 103, 63, 107, 73, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130]);
    } catch (e) {
      debugPrint("⚠️ Lỗi tải ảnh fallback: $e");
      return Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 2, 0, 0, 0, 105, 203, 61, 19, 0, 0, 0, 13, 73, 68, 65, 84, 8, 215, 99, 100, 12, 0, 0, 0, 130, 0, 1, 0, 2, 0, 1, 103, 63, 107, 73, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130]);
    }
  }

  /// 🗺️ Thêm lớp bản đồ Việt Nam (CHỈ GIỮ LẠI OUTLINE VÀ LABEL)
  Future<void> _addProvinceLayers() async {
    if (_controller == null) return;

    const sourceId = 'vn-provinces-source';
    final candidateFiles = ['assets/vn.json'];

    Map<String, dynamic>? geoJson;

    for (final path in candidateFiles) {
      try {
        final data = await rootBundle.loadString(path);
        geoJson = jsonDecode(data);
        break;
      } catch (_) {}
    }

    if (geoJson == null) {
      debugPrint("⚠️ Không tìm thấy file GeoJSON trong assets/");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('⚠️ Thiếu file bản đồ Việt Nam trong assets/'),
        ));
      }
      return;
    }

    final filtered = _filterDuplicateProvinceFeatures(geoJson);

    await _controller!.addGeoJsonSource(sourceId, filtered);

    // ✅ Giữ lại: Lớp đường ranh giới
    await _controller!.addLineLayer(
      sourceId,
      'vn-outline',
      maplibre.LineLayerProperties(
        lineColor: '#006666',
        lineWidth: 1.2,
      ),
    );

    // ✅ Giữ lại: Lớp tên tỉnh
    await _controller!.addSymbolLayer(
      sourceId,
      'vn-label',
      maplibre.SymbolLayerProperties(
        textField: ['get', 'ten_tinh'],
        textSize: 10,
        textColor: '#222222',
        textHaloColor: '#FFFFFF',
        textHaloWidth: 1.2,
        symbolPlacement: 'point',
        textAllowOverlap: false,
        textIgnorePlacement: false,
        textOpacity: [
          'interpolate',
          ['linear'],
          ['zoom'],
          4,
          0.0,
          5,
          0.8,
          6,
          1.0
        ],
      ),
    );
  }

  /// 📌 Thêm lớp Symbols cho Sự kiện
  Future<void> _addEventSymbolsLayer() async {
    if (_controller == null || _events.isEmpty) return;

    const sourceId = 'event-points-source';
    const layerId = 'event-markers-layer';
    final List<Map<String, dynamic>> features = [];

    // 1. Xóa Source/Layer cũ nếu có để tránh trùng lặp
    try {
      await _controller!.removeLayer(layerId);
      await _controller!.removeSource(sourceId);
    } catch (_) {
      // Bỏ qua nếu chưa tồn tại
    }

    // 2. Chuẩn bị GeoJSON Features và tải hình ảnh
    for (final e in _events) {
      if (e.eventId == null || e.latitude == null || e.longitude == null) continue;

      try {
        final iconId = 'marker-${e.eventId}';
        Uint8List? markerBytes =
        (e.imageUrl != null && e.imageUrl!.isNotEmpty)
            ? await _loadImageFromAssets(e.imageUrl!)
            : null;
        markerBytes ??= await _loadFallbackAsset();

        // Thêm hình ảnh/icon trước
        if (markerBytes != null) {
          try {
            await _controller!.addImage(iconId, markerBytes);
          } catch (e) {
            debugPrint("❌ Lỗi đăng ký Image $iconId: $e");
            continue;
          }
        } else {
          debugPrint("❌ KHÔNG TẢI ĐƯỢC FALLBACK HOẶC IMAGE cho sự kiện ID: ${e.eventId}");
          continue;
        }

        features.add({
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [e.longitude!, e.latitude!]
          },
          'properties': {
            // Key này rất quan trọng cho onSymbolTapped
            'eventId': e.eventId.toString(),
            'iconId': iconId,
            'title': e.title ?? '',
          },
        });
      } catch (ex) {
        debugPrint("❌ Lỗi chuẩn bị GeoJSON cho ${e.title}: $ex");
      }
    }

    if (features.isEmpty) {
      debugPrint("⚠️ KHÔNG CÓ FEATURE NÀO HỢP LỆ để thêm vào bản đồ.");
      return;
    }

    final geoJson = {
      'type': 'FeatureCollection',
      'features': features,
    };

    // 3. Thêm nguồn dữ liệu GeoJSON
    await _controller!.addGeoJsonSource(sourceId, geoJson);
    debugPrint("✅ Thêm GeoJSON Source với ${features.length} features.");

    // 4. Thêm Symbol Layer.
    await _controller!.addSymbolLayer(
      sourceId,
      layerId,
      maplibre.SymbolLayerProperties(
        iconImage: ['get', 'iconId'],
        // 🚀 Tăng iconSize lên 2.0 để mở rộng vùng chạm (hitbox)
        iconSize: 2.0,
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
      ),
    );

    debugPrint("✅ Thêm lớp sự kiện Symbols xong.");
  }


  /// 🗺️ Tự động xác định vùng zoom theo sự kiện (Giữ nguyên)
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

    // 1. Thêm các lớp Bản đồ Việt Nam
    await _addProvinceLayers();

    // 2. Thêm các Marker Sự kiện.
    await _addEventSymbolsLayer();

    // 3. Tự zoom
    final bounds = _calculateBounds();
    if (_events.isNotEmpty) {
      // Đã tăng padding để tránh bị che bởi AppBar
      await _controller!.animateCamera(maplibre.CameraUpdate.newLatLngBounds(bounds,
          top: 150, bottom: 200, left: 50, right: 50));
    }

    // 🚀 Xử lý chạm Marker (Symbol) - Vị trí của sự kiện chạm
    _controller!.onSymbolTapped.add((symbol) {

      // ✨ DEBUGGING MỚI: Luôn log để xác nhận sự kiện chạm có được kích hoạt không
      debugPrint("=========================================");
      debugPrint("✨ SỰ KIỆN CHẠM MARKER ĐÃ ĐƯỢC KÍCH HOẠT!");
      debugPrint("✨ Dữ liệu Marker: ${symbol.data}");
      debugPrint("=========================================");

      final raw = symbol.data?["eventId"];
      if (raw == null) {
        debugPrint("⚠️ Lỗi: Không tìm thấy 'eventId' trong dữ liệu marker.");
        return;
      }

      // Đảm bảo eventId là kiểu int
      int? eid = raw is String ? int.tryParse(raw) : (raw is int ? raw : null);

      if (eid == null) {
        debugPrint("⚠️ Không thể parse event ID: $raw");
        return;
      }

      debugPrint("✅ Đã lấy được Event ID: $eid. Đang tìm sự kiện...");

      // Dùng indexWhere để tìm kiếm hiệu quả và an toàn hơn
      final eventIndex = _events.indexWhere((ev) => ev.eventId == eid);

      if (eventIndex != -1) {
        final event = _events[eventIndex];
        debugPrint("✅ Tìm thấy sự kiện: ${event.title} (ID: $eid). BẮT ĐẦU ĐIỀU HƯỚNG.");

        if (mounted) {
          // **Thực hiện điều hướng**
          Navigator.push(
            context,
            MaterialPageRoute(
              // Truyền eventId và userId
              builder: (context) => EventDetailScreen(eventId: event.eventId!, userId: widget.userId),
            ),
          );
        }
      } else {
        // Thông báo nếu không tìm thấy sự kiện
        debugPrint("❌ KHÔNG TÌM THẤY sự kiện ID $eid trong danh sách ${_events.length} sự kiện đã tải.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Không tìm thấy dữ liệu sự kiện $eid!'),
          ));
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