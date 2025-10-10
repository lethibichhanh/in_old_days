import 'package:flutter/material.dart';
import '../services/db_helper.dart';

class EventDetailScreen extends StatefulWidget {
  final int eventId;
  const EventDetailScreen({Key? key, required this.eventId}) : super(key: key);

  @override
  _EventDetailScreenState createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  Map<String, dynamic>? _event;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final e = await DBHelper.instance.getEventById(widget.eventId);
    setState(() {
      _event = e;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_event == null) return Scaffold(body: Center(child: Text('Không tìm thấy sự kiện.')));

    final title = _event!['title'] ?? _event!['name'] ?? 'Sự kiện';
    final desc  = _event!['description'] ?? '';
    final date  = _event!['date'] ?? _event!['event_date'] ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(title.toString())),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (date != null && date.toString().isNotEmpty)
              Text(date.toString(), style: TextStyle(color: Colors.grey[600])),
            SizedBox(height: 12),
            Text(title.toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text(desc.toString(), style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
