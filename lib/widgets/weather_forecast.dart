part of 'maritime_weather.dart';

class _Forecast extends StatelessWidget {
  const _Forecast(this.slots);
  final List<WeatherInfoItem> slots;
  @override
  Widget build(BuildContext context) {
    final days = <DateTime, List<WeatherInfoItem>>{};
    for (final s in slots) {
      final d = _wib(s.validAt);
      (days[DateTime.utc(d.year, d.month, d.day)] ??= []).add(s);
    }
    final points = slots.where((s) => s.temperature != null).toList();
    final theme = Theme.of(context);
    final title = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.bold,
    );
    const weekdays = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        _Panel(
          children: [
            Text('Tren suhu', style: title),
            const SizedBox(height: 8),
            if (points.isEmpty)
              const Text('Data suhu tidak tersedia.')
            else if (points.length == 1)
              Text(
                '${_value(points.single.temperature, ' °C')}  ·  ${_stamp(points.single.validAt)}',
              )
            else ...[
              Text(_range(points)),
              const SizedBox(height: 10),
              Semantics(
                label:
                    'Grafik suhu menurut waktu. Nilai tiap jam tersedia di prakiraan per hari.',
                child: SizedBox(
                  height: 90,
                  child: CustomPaint(
                    key: const Key('temperature-line'),
                    painter: _Trend(points, theme.colorScheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_stamp(points.first.validAt)} – ${_stamp(points.last.validAt)}',
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        Text('Prakiraan per hari', style: title),
        const SizedBox(height: 8),
        for (final entry in days.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _Panel(
              children: [
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  shape: const Border(),
                  collapsedShape: const Border(),
                  title: Text(
                    '${weekdays[entry.key.weekday - 1]}, ${_date(entry.key)}',
                  ),
                  subtitle: Text(
                    '${entry.value.length} waktu prakiraan  ·  ${_range(entry.value)}',
                  ),
                  children: [
                    for (final s in entry.value)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(_icon(s.condition)),
                        title: Text(_time(_wib(s.validAt))),
                        subtitle: Text(
                          '${s.condition ?? _missing}  ·  ${_value(s.temperature, ' °C')}',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String _range(List<WeatherInfoItem> slots) {
  final values = slots.map((s) => s.temperature).whereType<num>().toList()
    ..sort();
  if (values.isEmpty) return 'Suhu tidak tersedia';
  if (values.first == values.last) return _value(values.first, ' °C');
  return '${_value(values.first, '')}–${_value(values.last, ' °C')}';
}

class _Trend extends CustomPainter {
  const _Trend(this.points, this.color);
  final List<WeatherInfoItem> points;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final values = points.map((s) => s.temperature!).toList()..sort();
    final low = values.first, high = values.last;
    final start = points.first.validAt,
        duration = points.last.validAt.difference(start).inMicroseconds;
    final brush = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final grid = Paint()..color = color.withValues(alpha: .18);
    for (final y in [4.0, size.height / 2, size.height - 4]) {
      canvas.drawLine(Offset(4, y), Offset(size.width - 4, y), grid);
    }
    Offset? previous;
    for (final s in points) {
      final x = duration == 0
          ? 0.5
          : s.validAt.difference(start).inMicroseconds / duration;
      final y = high == low ? 0.5 : (high - s.temperature!) / (high - low);
      final p = Offset(4 + x * (size.width - 8), 4 + y * (size.height - 8));
      if (previous != null) canvas.drawLine(previous, p, brush);
      canvas.drawCircle(p, 3.5, brush);
      previous = p;
    }
  }

  @override
  bool shouldRepaint(_Trend old) => old.points != points || old.color != color;
}
