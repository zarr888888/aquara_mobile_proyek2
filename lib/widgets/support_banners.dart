import 'dart:async';
import 'package:flutter/material.dart';

/// Titles/assets/order recovered from e88bf1e, not inferred from the screenshot.
const supportBanners = [
  ('Analisa Panen Cerdas', 'assets/banner_analisausaha.png'),
  ('Cek Harga & Stok Pasar Hari Ini', 'assets/banner_hargapasar.png'),
  ('Diskusi Bersama Komunitas', 'assets/banner_forum.png'),
  ('Foto Ikan dan AI Menjawabnya', 'assets/banner konsultasi ai.png'),
];

class SupportBanners extends StatefulWidget {
  const SupportBanners({
    super.key,
    required this.onSelected,
    this.initialPaused = false,
    this.onPausedChanged,
  });
  final ValueChanged<int> onSelected;
  final bool initialPaused;
  final ValueChanged<bool>? onPausedChanged;
  static const interval = Duration(seconds: 3);
  static const transition = Duration(milliseconds: 500);
  @override
  State<SupportBanners> createState() => _SupportBannersState();
}

class _SupportBannersState extends State<SupportBanners>
    with WidgetsBindingObserver {
  final _controller = PageController(viewportFraction: .92);
  Timer? _timer;
  late bool _paused = widget.initialPaused;
  bool _foreground = true,
      _current = true,
      _reduced = false,
      _animating = false;
  int _generation = 0, _page = 0;
  bool get _enabled =>
      mounted && !_paused && _foreground && _current && !_reduced;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _current = ModalRoute.isCurrentOf(context) ?? true;
    _reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (!_enabled) {
      _stop();
    } else {
      _schedule();
    }
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _generation++;
    if (_animating && _controller.hasClients) {
      // Stop at the currently selected slide, including an interrupted wrap.
      _controller.jumpToPage(_page);
    }
    _animating = false;
  }

  void _schedule() {
    if (!_enabled || _timer != null || _animating) return;
    final generation = _generation;
    _timer = Timer(SupportBanners.interval, () async {
      _timer = null;
      if (!_enabled || generation != _generation) return;
      if (!_controller.hasClients) {
        _schedule();
        return;
      }
      _animating = true;
      if (_page == supportBanners.length) {
        _controller.jumpToPage(0);
      }
      // A trailing copy of the first slide allows a one-slide forward wrap.
      await _controller.animateToPage(
        (_page % supportBanners.length) + 1,
        duration: SupportBanners.transition,
        curve: Curves.easeInOut,
      );
      if (!mounted || generation != _generation) return;
      _animating = false;
      if (_controller.hasClients && _page == supportBanners.length) {
        _controller.jumpToPage(0);
      }
      _schedule();
    });
  }

  void _pause(bool value, {bool dragging = false}) {
    _timer?.cancel();
    _timer = null;
    _generation++;
    if (!dragging) _stop();
    // A user drag has already cancelled the driven scroll activity.
    _animating = false;
    setState(() => _paused = value);
    widget.onPausedChanged?.call(value);
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _schedule();
    } else {
      _stop();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 160 + MediaQuery.textScalerOf(context).scale(72),
        child: NotificationListener<ScrollStartNotification>(
          onNotification: (notification) {
            if (notification.dragDetails != null) _pause(true, dragging: true);
            return false;
          },
          child: PageView.builder(
            key: const Key('support-banners'),
            controller: _controller,
            itemCount: supportBanners.length + 1,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, page) {
              final index = page % supportBanners.length;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Material(
                  clipBehavior: Clip.antiAlias,
                  borderRadius: BorderRadius.circular(20),
                  child: Ink(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage(supportBanners[index].$2),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: InkWell(
                      key: ValueKey('support-banner-$page'),
                      onTap: () {
                        _stop();
                        widget.onSelected(index);
                        // The inherited route status suspends until return.
                        _schedule();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        alignment: Alignment.bottomLeft,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                          ),
                        ),
                        child: Text(
                          supportBanners[index].$1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${_page % supportBanners.length + 1} / ${supportBanners.length}',
            ),
            Tooltip(
              message: _paused
                  ? 'Lanjutkan banner otomatis'
                  : 'Jeda banner otomatis',
              child: TextButton.icon(
                key: const Key('support-playback'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => _pause(!_paused),
                icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                label: Text(_paused ? 'Lanjut' : 'Jeda'),
              ),
            ),
          ],
        ),
      ),
      if (_reduced)
        const Text(
          'Gerak otomatis dinonaktifkan oleh pengaturan aksesibilitas.',
        ),
    ],
  );
}
