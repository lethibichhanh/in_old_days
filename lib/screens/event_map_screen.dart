import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import '../db/db_helper.dart';
import '../models/event.dart';
import 'event_detail_screen.dart'; // <-- thêm dòng này

class EventMapScreen extends StatefulWidget {
  final int year;
  final int? month;
  final int? day;
  final List<EventModel>? events;

  const EventMapScreen({
    super.key,
    required this.year,
    this.month,
    this.day,
    this.events,
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
    _controller = null;
    super.dispose();
  }

  // --- Lọc GeoJSON trùng tên tỉnh
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

    _events = events.where((e) => e.latitude != null && e.longitude != null && e.eventId != null).toList();
    _events.sort((a, b) => a.eventId!.compareTo(b.eventId!));

    setState(() => _loading = false);
  }

  Future<Uint8List?> _loadImageFromAssets(String relativePath) async {
    try {
      String path = relativePath.startsWith('assets/') ? relativePath : 'assets/$relativePath';
      final data = await rootBundle.load(path);
      final bytes = data.buffer.asUint8List();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      final resized = img.copyResize(decoded, width: 80, height: 80);
      return Uint8List.fromList(img.encodePng(resized));
    } catch (e) {
      debugPrint("⚠️ Không thể tải ảnh $relativePath: $e");
      return null;
    }
  }

  Future<Uint8List> _loadFallbackAsset() async {
    final byteData = await rootBundle.load('assets/marker.png');
    return byteData.buffer.asUint8List();
  }

  Future<void> _addProvinceLayers() async {
    if (_controller == null) return;

    const sourceId = 'vn-provinces-source';
    final candidateFiles = ['assets/vn.json'];

    Map<String, dynamic>? geoJson;
    String? usedFile;

    for (final path in candidateFiles) {
      try {
        final data = await rootBundle.loadString(path);
        geoJson = jsonDecode(data);
        usedFile = path;
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

    await _controller!.addFillLayer(
      sourceId,
      'vn-fill',
      maplibre.FillLayerProperties(
        fillColor: '#C7E6E1',
        fillOpacity: 0.35,
        fillOutlineColor: '#008080',
      ),
    );

    await _controller!.addLineLayer(
      sourceId,
      'vn-outline',
      maplibre.LineLayerProperties(
        lineColor: '#006666',
        lineWidth: 1.2,
      ),
    );

    await _controller!.addSymbolLayer(
      sourceId,
      'vn-label',
      maplibre.SymbolLayerProperties(
        textField: ['get', 'ten_tinh'],
        textSize: 10,
        textColor: '#222222',
        textHaloColor: '#FFFFFF',
        textHaloWidth: 1.2,
      ),
    );
  }

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

    return maplibre.LatLngBounds(
      southwest: maplibre.LatLng(minLat - 0.2, minLon - 0.2),
      northeast: maplibre.LatLng(maxLat + 0.2, maxLon + 0.2),
    );
  }

  Future<void> _onMapCreated(maplibre.MaplibreMapController controller) async {
    _controller = controller;
    await _addProvinceLayers();

    for (final e in _events) {
      try {
        final iconId = 'marker-${e.eventId}';
        Uint8List? markerBytes = (e.imageUrl != null && e.imageUrl!.isNotEmpty)
            ? await _loadImageFromAssets(e.imageUrl!)
            : null;
        markerBytes ??= await _loadFallbackAsset();

        await _controller!.addImage(iconId, markerBytes);
        await _controller!.addSymbol(
          maplibre.SymbolOptions(
            geometry: maplibre.LatLng(e.latitude!, e.longitude!),
            iconImage: iconId,
            iconSize: 1.0,
          ),
          {"eventId": e.eventId.toString()},
        );
      } catch (ex) {
        debugPrint("❌ Lỗi thêm marker cho ${e.title}: $ex");
      }
    }

    final bounds = _calculateBounds();
    await _controller!.animateCamera(
      maplibre.CameraUpdate.newLatLngBounds(bounds,
          top: 100, bottom: 150, left: 50, right: 50),
    );

    _controller!.onSymbolTapped.add((symbol) {
      final raw = symbol.data?["eventId"];
      int? eid = raw is String ? int.tryParse(raw) : (raw is int ? raw : null);

      if (eid == null) return;

      final event = _events.firstWhere(
            (ev) => ev.eventId == eid,
        orElse: () => EventModel.empty(),
      );

      if (event.eventId != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EventDetailScreen(event: event),
          ),
        );
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '📍 ${_events.length} sự kiện có vị trí',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}