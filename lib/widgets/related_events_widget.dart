import 'package:flutter/material.dart';
import '../services/db_helper.dart';
import 'event_detail_screen.dart'; // sẽ tạo phía dưới

class RelatedEventsWidget extends StatefulWidget {
  final int figureId;
  const RelatedEventsWidget({Key? key, required this.figureId}) : super(key: key);

  @override
  _RelatedEventsWidgetState createState() => _RelatedEventsWidgetState();
}

class _RelatedEventsWidgetState extends State<RelatedEventsWidget> {
  bool _loading = true;
  List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; });
    try {
      final evs = await DBHelper.instance.getRelatedEventsForFigure(widget.figureId);
      setState(() {
        _events = evs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _events = [];
        _loading = false;
      });
      debugPrint('Error loading related events: $e');
    }
  }

  String _snippet(String? s, [int max = 120]) {
    if (s == null) return '';
    final t = s.replaceAll('\n', ' ').trim();
    return t.length <= max ? t : (t.substring(0, max) + '…');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text('Không có sự kiện liên quan.', style: TextStyle(color: Colors.grey[700])),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _events.length,
      separatorBuilder: (_, __) => Divider(height: 1),
      itemBuilder: (context, index) {
        final ev = _events[index];
        final title = (ev['title'] ?? ev['name'] ?? 'Sự kiện chưa có tiêu đề').toString();
        final desc = (ev['description'] ?? '').toString();
        final date = ev['event_date']?.toString() ?? '';

        return ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          leading: CircleAvatar(child: Text(date.isNotEmpty ? date.split('-').first : '?')), // tạm dùng năm
          title: Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (date.isNotEmpty) Text(date, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              SizedBox(height: 6),
              Text(_snippet(desc), style: TextStyle(fontSize: 13)),
            ],
          ),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => EventDetailScreen(eventId: ev['event_id'] as int),
            ));
          },
        );
      },
    );
  }
}
