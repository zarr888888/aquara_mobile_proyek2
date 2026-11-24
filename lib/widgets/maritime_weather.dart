import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/external_info.dart';
import 'samudera_theme.dart';

part 'weather_forecast.dart';

const _navy = Color(0xff094874);
const _headerBacking = Color(0xff007bb0);
const _missing = 'Tidak tersedia';
const _ports = {'XJ022': 'Karangsong', 'XJ021': 'Eretan'};
String _value(num? n, String unit) => n == null
    ? _missing
    : '${n.toString().replaceFirst(RegExp(r'\.0$'), '').replaceAll('.', ',')}$unit';
DateTime _wib(DateTime t) => t.toUtc().add(const Duration(hours: 7));
String _two(int n) => '$n'.padLeft(2, '0');
String _date(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';
String _time(DateTime d) => '${_two(d.hour)}:${_two(d.minute)} WIB';
String _stamp(DateTime t) => '${_date(_wib(t))} ${_time(_wib(t))}';
IconData _icon(String? condition) {
  final s = condition?.toLowerCase() ?? '';
  if (s.contains('petir') || s.contains('badai')) return Icons.thunderstorm;
  if (s.contains('hujan')) return Icons.water_drop;
  if (s.contains('awan')) return Icons.cloud;
  if (s.contains('cerah')) return Icons.wb_sunny;
  return Icons.thermostat;
}

class _HeaderPlate extends StatelessWidget {
  const _HeaderPlate(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: _headerBacking,
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
}

class _HeaderSymbol extends StatelessWidget {
  const _HeaderSymbol(this.condition);
  final String? condition;

  @override
  Widget build(BuildContext context) {
    final label = condition?.trim().toLowerCase();
    if (label != 'berawan' && label != 'berawan tebal') {
      return Icon(_icon(condition), size: 48, color: Colors.white);
    }
    return const SizedBox.square(
      dimension: 48,
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 2,
            child: Icon(
              Icons.cloud_queue_rounded,
              size: 34,
              color: Colors.white,
            ),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: Icon(Icons.cloud_rounded, size: 38, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class MaritimeWeather extends StatelessWidget {
  const MaritimeWeather({
    super.key,
    required this.code,
    required this.bulletin,
    required this.now,
    required this.busy,
    required this.failure,
    required this.wait,
    required this.reload,
    required this.select,
  });
  final String code;
  final WeatherBulletin? bulletin;
  final DateTime now;
  final bool busy;
  final String? failure, wait;
  final VoidCallback? reload;
  final ValueChanged<String> select;

  @override
  Widget build(BuildContext context) {
    final theme = samuderaTheme(Theme.of(context).brightness);
    final dark = theme.brightness == Brightness.dark;
    final b = bulletin;
    final slot = b?.slotAt(now);
    final expired = b != null && !now.isBefore(b.to);
    final label = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.bold,
    );
    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: dark
            ? theme.colorScheme.surface
            : const Color(0xfff2f6f8),
        appBar: AppBar(
          title: const _HeaderPlate(Text('Cuaca Maritim')),
          backgroundColor: SamuderaColors.blue,
          foregroundColor: Colors.white,
          titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
            color: Colors.white,
          ),
          iconTheme: theme.appBarTheme.iconTheme,
          actionsIconTheme: theme.appBarTheme.actionsIconTheme?.copyWith(
            color: Colors.white,
          ),
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: SamuderaColors.blue,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemStatusBarContrastEnforced: false,
          ),
          actions: [
            IconButton(
              key: const Key('external-info-refresh'),
              tooltip: 'Muat ulang',
              onPressed: reload,
              style: IconButton.styleFrom(
                backgroundColor: _headerBacking,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _headerBacking,
                disabledForegroundColor: Colors.white60,
              ),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                key: ValueKey(code),
                padding: EdgeInsets.zero,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
                    color: SamuderaColors.blue,
                    child: DefaultTextStyle(
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: Colors.white,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final e in _ports.entries)
                                ChoiceChip(
                                  label: Text(e.value),
                                  selected: e.key == code,
                                  selectedColor: Colors.white,
                                  backgroundColor: _navy,
                                  checkmarkColor: _navy,
                                  labelStyle: theme.textTheme.labelLarge
                                      ?.copyWith(
                                        color: e.key == code
                                            ? _navy
                                            : Colors.white,
                                      ),
                                  onSelected: (v) {
                                    if (v && e.key != code) select(e.key);
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _HeaderPlate(
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'SAMUDERA  /  PELABUHAN',
                                  style: TextStyle(
                                    letterSpacing: 1.6,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  b?.location ?? _ports[code]!,
                                  key: const Key('weather-port'),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (slot != null) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 20,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        _value(slot.temperature, '°C'),
                                        style: TextStyle(
                                          fontSize: slot.temperature == null
                                              ? 22
                                              : 54,
                                          fontWeight: FontWeight.bold,
                                          height: 1.15,
                                        ),
                                      ),
                                      _HeaderSymbol(slot.condition),
                                    ],
                                  ),
                                  Text(
                                    slot.condition ?? _missing,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (b != null) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Sumber: ${b.source}',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: _navy,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                                if (slot != null)
                                  _HeaderPlate(
                                    Text('Prakiraan ${_stamp(slot.validAt)}'),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (busy)
                          const Center(child: CircularProgressIndicator()),
                        if (failure != null) Text(failure!),
                        if (wait != null) Text(wait!),
                        if (expired)
                          const Text('Prakiraan kedaluwarsa.')
                        else if (b != null) ...[
                          if (b.upcoming)
                            Text('Berlaku mulai ${_stamp(b.from)}'),
                          if (slot == null)
                            const Text('Belum ada prakiraan.')
                          else ...[
                            Text('Kondisi laut', style: label),
                            const SizedBox(height: 8),
                            _SeaCards(slot),
                            const SizedBox(height: 10),
                            _Panel(
                              children: [
                                _Caption(Icons.air, 'Angin'),
                                Text(
                                  'Angin dari: ${slot.direction ?? _missing}',
                                ),
                                const Divider(),
                                Text(
                                  'Kecepatan: ${_value(slot.wind, ' knot')}  ·  ${_value(slot.windKmh, ' km/jam')}',
                                ),
                                Text('Hembusan: ${_value(slot.gust, ' knot')}'),
                              ],
                            ),
                          ],
                          if (b.slots.isNotEmpty) _Forecast(b.slots),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.icon, this.title);
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary),
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    ],
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: Theme.of(context).dividerColor.withValues(alpha: .18),
      ),
    ),
    color: Theme.of(context).colorScheme.surface,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}

class _SeaCards extends StatelessWidget {
  const _SeaCards(this.s);
  final WeatherInfoItem s;
  @override
  Widget build(BuildContext context) {
    Widget metric(IconData icon, String title, num? n, String detail) => _Panel(
      children: [
        _Caption(icon, title),
        const SizedBox(height: 8),
        Text(
          _value(n, ' m'),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(detail),
      ],
    );
    final wave = metric(
          Icons.waves,
          'Gelombang',
          s.wave,
          s.category ?? _missing,
        ),
        tide = metric(
          Icons.swap_vert,
          'Pasang Surut',
          s.tide,
          'Tinggi muka air',
        );
    return LayoutBuilder(
      builder: (context, c) =>
          c.maxWidth >= 300 * MediaQuery.textScalerOf(context).scale(14) / 14
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: wave),
                const SizedBox(width: 10),
                Expanded(child: tide),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [wave, const SizedBox(height: 10), tide],
            ),
    );
  }
}
