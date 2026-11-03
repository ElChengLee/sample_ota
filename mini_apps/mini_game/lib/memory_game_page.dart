import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'main.dart';
import 'shell_bridge.dart';

/// Game lật thẻ 4x4: tìm 8 cặp icon giống nhau với ít lượt nhất.
class MemoryGamePage extends StatefulWidget {
  const MemoryGamePage({super.key});

  @override
  State<MemoryGamePage> createState() => _MemoryGamePageState();
}

class _CardData {
  _CardData(this.icon, this.color);

  final IconData icon;
  final Color color;
  bool faceUp = false;
  bool matched = false;
}

class _MemoryGamePageState extends State<MemoryGamePage> {
  static const _bestKey = 'mini_game.bestMoves';
  static const _icons = <(IconData, Color)>[
    (Icons.local_cafe, Color(0xFF8D6E63)),
    (Icons.icecream, Color(0xFFEC407A)),
    (Icons.cake, Color(0xFFAB47BC)),
    (Icons.local_pizza, Color(0xFFFF7043)),
    (Icons.eco, Color(0xFF66BB6A)),
    (Icons.star, Color(0xFFFFCA28)),
    (Icons.favorite, Color(0xFFE53935)),
    (Icons.rocket_launch, Color(0xFF42A5F5)),
  ];

  late List<_CardData> _cards;
  final _open = <int>[];
  var _moves = 0;
  var _busy = false;
  int? _best;
  final _stopwatch = Stopwatch();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _best = int.tryParse(LocalStore.get(_bestKey) ?? '');
    _newGame();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _newGame() {
    final deck = [for (final (icon, color) in _icons) ...[_CardData(icon, color), _CardData(icon, color)]]
      ..shuffle(Random());
    _ticker?.cancel();
    _stopwatch
      ..stop()
      ..reset();
    setState(() {
      _cards = deck;
      _open.clear();
      _moves = 0;
      _busy = false;
    });
  }

  Future<void> _flip(int index) async {
    final card = _cards[index];
    if (_busy || card.faceUp || card.matched) return;

    if (!_stopwatch.isRunning) {
      _stopwatch.start();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    }

    setState(() {
      card.faceUp = true;
      _open.add(index);
    });
    if (_open.length < 2) return;

    _moves++;
    final [a, b] = _open;
    _open.clear();
    if (_cards[a].icon == _cards[b].icon) {
      setState(() => _cards[a].matched = _cards[b].matched = true);
      if (_cards.every((c) => c.matched)) await _onWin();
      return;
    }

    _busy = true;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _cards[a].faceUp = _cards[b].faceUp = false;
      _busy = false;
    });
  }

  Future<void> _onWin() async {
    _stopwatch.stop();
    _ticker?.cancel();
    final isRecord = _best == null || _moves < _best!;
    if (isRecord) {
      _best = _moves;
      LocalStore.set(_bestKey, '$_moves');
      // Toast native của Shell (standalone thì chỉ log).
      unawaited(ShellBridge.instance.showToast('Kỷ lục mới: $_moves lượt!'));
    }
    setState(() {});

    final again = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.emoji_events, size: 40),
        title: Text(isRecord ? 'Kỷ lục mới!' : 'Hoàn thành!'),
        content: Text('$_moves lượt trong ${_formatTime(_stopwatch.elapsed)}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Thoát')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Chơi lại')),
        ],
      ),
    );
    if (again == false) {
      unawaited(ShellBridge.instance.close());
    } else {
      // Chơi lại, hoặc dialog bị đóng bằng Back/chạm ngoài.
      _newGame();
    }
  }

  String _formatTime(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final embedded = ShellBridge.instance.isEmbedded;

    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder<String?>(
          valueListenable: playerName,
          builder: (context, name, _) => Text(name == null ? 'Lật thẻ' : 'Chào $name'),
        ),
        actions: [
          if (!embedded)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(label: const Text('standalone'), visualDensity: VisualDensity.compact),
            ),
          IconButton(tooltip: 'Ván mới', onPressed: _newGame, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _Stat(label: 'Lượt', value: '$_moves'),
                      _Stat(label: 'Thời gian', value: _formatTime(_stopwatch.elapsed)),
                      _Stat(label: 'Kỷ lục', value: _best == null ? '-' : '$_best'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: GridView.count(
                          crossAxisCount: 4,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            for (var i = 0; i < _cards.length; i++)
                              _FlipCard(card: _cards[i], onTap: () => _flip(i)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Text(
                    'Mini Game v$kBuildVersion · Flutter thuần',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.outline),
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

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Text(value, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          Text(label, style: text.labelMedium),
        ],
      ),
    );
  }
}

class _FlipCard extends StatelessWidget {
  const _FlipCard({required this.card, required this.onTap});

  final _CardData card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showFace = card.faceUp || card.matched;

    return TweenAnimationBuilder<double>(
      tween: Tween(end: showFace ? 1 : 0),
      duration: const Duration(milliseconds: 250),
      builder: (context, t, _) {
        // Xoay quanh trục Y; qua nửa vòng thì đổi sang mặt trước.
        final front = t > 0.5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(pi * t),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..rotateY(front ? pi : 0),
            child: Material(
              color: front
                  ? (card.matched ? scheme.secondaryContainer : scheme.surfaceContainerHighest)
                  : scheme.primary,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Center(
                  child: front
                      ? Icon(card.icon, size: 36, color: card.color)
                      : Icon(Icons.question_mark, size: 28, color: scheme.onPrimary.withValues(alpha: 0.6)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
