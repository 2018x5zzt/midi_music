import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/midi/midi_parser.dart';
import '../../core/midi/midi_player.dart';
import '../../core/settings/app_settings.dart';
import '../widgets/player_helpers.dart';
import 'settings_page.dart';

class PracticeScoreMetadata {
  final String title;
  final String composer;
  final String category;
  final String level;
  final String duration;
  final String saves;
  final Color accent;
  final int seed;
  final String? assetPath;

  const PracticeScoreMetadata({
    required this.title,
    required this.composer,
    required this.category,
    required this.level,
    required this.duration,
    required this.saves,
    required this.accent,
    required this.seed,
    this.assetPath,
  });
}

class ScorePracticePage extends StatefulWidget {
  final PracticeScoreMetadata score;

  const ScorePracticePage({super.key, required this.score});

  @override
  State<ScorePracticePage> createState() => _ScorePracticePageState();
}

class _ScorePracticePageState extends State<ScorePracticePage> {
  final MidiFileParser _parser = MidiFileParser();

  var _isLoadingScore = false;
  var _isPreviewPlaying = false;
  var _tempoFactor = 1.0;
  var _loopEnabled = false;
  var _annotationsVisible = true;
  var _aiTempoEnabled = false;

  /// 当前曲目是否已加载到全局播放器（按 songId 区分，避免误判其他曲目）。
  bool _isScoreLoaded(MidiPlayerController player) {
    return player.songData != null &&
        player.currentSongId == widget.score.title;
  }

  Future<bool> _loadAssetScore() async {
    final assetPath = widget.score.assetPath;
    if (assetPath == null) {
      _showAlert('曲库资源未接入', '这首曲目暂时只有谱面预览，请先导入 MIDI 文件排练。');
      return false;
    }

    setState(() => _isLoadingScore = true);
    var loaded = false;
    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      final song = _parser.parseBytes(
        bytes,
        fileName: assetPath.split('/').last,
      );
      if (!mounted) return false;

      final player = context.read<MidiPlayerController>();
      final settings = context.read<AppSettingsController>();
      player.loadSong(song, songId: widget.score.title);
      player.setSpeed(settings.defaultPlaybackSpeed);
      setState(() => _tempoFactor = player.playbackSpeed);
      loaded = true;
    } catch (error) {
      if (!mounted) return false;
      _showAlert('载入失败', '无法载入内置 MIDI：$error');
    } finally {
      if (mounted) {
        setState(() => _isLoadingScore = false);
      }
    }
    return loaded;
  }

  Future<void> _togglePlayback(MidiPlayerController player) async {
    // 若当前曲目尚未加载（或加载的是别的曲子），先把这首加载进来再播放，
    // 否则会出现「显示已载入却没声音 / 播放成上一首」的问题。
    if (!_isScoreLoaded(player)) {
      if (widget.score.assetPath == null) {
        setState(() => _isPreviewPlaying = !_isPreviewPlaying);
        return;
      }
      final loaded = await _loadAssetScore();
      if (!loaded || !mounted) return;
    }
    if (player.isPlaying) {
      player.pause();
      return;
    }
    if (!player.isSoundfontReady) {
      _showAlert('音色库未就绪', '请等待音色库准备完成后再播放。');
      return;
    }
    player.play();
  }

  void _seek(MidiPlayerController player, double value) {
    if (player.songData == null) return;
    player.seekTo(value * player.totalDuration);
  }

  void _setTempo(MidiPlayerController player, double value) {
    setState(() => _tempoFactor = value);
    if (player.songData != null) {
      player.setSpeed(value);
    }
  }

  void _showAlert(String title, String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('好的'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final score = widget.score;

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF5EBD7),
      navigationBar: CupertinoNavigationBar(
        border: null,
        backgroundColor: const Color(0xFFF5EBD7).withValues(alpha: 0.92),
        previousPageTitle: '乐库',
        middle: Text(
          score.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF2A2118)),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 0),
          onPressed: () => unawaited(
            Navigator.of(context).push(
              CupertinoPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
          ),
          child: const Icon(
            CupertinoIcons.gear_alt_fill,
            size: 18,
            color: Color(0xFF5F4A35),
          ),
        ),
      ),
      child: Consumer<MidiPlayerController>(
        builder: (context, player, _) {
          final hasLoadedSong = _isScoreLoaded(player);
          final progress = hasLoadedSong && player.totalDuration > 0
              ? (player.currentTime / player.totalDuration).clamp(0.0, 1.0)
              : (_isPreviewPlaying ? 0.18 : 0.0);
          final tempo = hasLoadedSong ? player.playbackSpeed : _tempoFactor;

          return Stack(
            children: [
              SafeArea(
                bottom: false,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _PracticeHeader(
                        score: score,
                        hasLoadedSong: hasLoadedSong,
                        isLoading: _isLoadingScore,
                        onLoadAssetScore: _loadAssetScore,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _ScorePaper(
                        score: score,
                        progress: progress,
                        annotationsVisible: _annotationsVisible,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _PracticeTimeline(
                        player: player,
                        isScoreLoaded: hasLoadedSong,
                        progress: progress,
                        onSeek: (value) => _seek(player, value),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 142),
                      sliver: SliverToBoxAdapter(
                        child: _PracticeOptions(
                          tempo: tempo,
                          aiTempoEnabled: _aiTempoEnabled,
                          loopEnabled: _loopEnabled,
                          annotationsVisible: _annotationsVisible,
                          onTempoChanged: (value) => _setTempo(player, value),
                          onToggleAiTempo: () {
                            setState(() => _aiTempoEnabled = !_aiTempoEnabled);
                          },
                          onToggleLoop: () {
                            setState(() => _loopEnabled = !_loopEnabled);
                          },
                          onToggleAnnotations: () {
                            setState(
                              () => _annotationsVisible = !_annotationsVisible,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _PracticeToolbar(
                  isPlaying: player.isPlaying || _isPreviewPlaying,
                  loopEnabled: _loopEnabled,
                  annotationsVisible: _annotationsVisible,
                  aiTempoEnabled: _aiTempoEnabled,
                  onPlayPause: () => _togglePlayback(player),
                  onToggleLoop: () {
                    setState(() => _loopEnabled = !_loopEnabled);
                  },
                  onToggleAnnotations: () {
                    setState(() => _annotationsVisible = !_annotationsVisible);
                  },
                  onToggleAiTempo: () {
                    setState(() => _aiTempoEnabled = !_aiTempoEnabled);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PracticeHeader extends StatelessWidget {
  final PracticeScoreMetadata score;
  final bool hasLoadedSong;
  final bool isLoading;
  final VoidCallback onLoadAssetScore;

  const _PracticeHeader({
    required this.score,
    required this.hasLoadedSong,
    required this.isLoading,
    required this.onLoadAssetScore,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  score.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 28,
                    height: 1.08,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF241A11),
                    fontFamily: 'Georgia',
                    fontFamilyFallback: ['Times New Roman', 'Noto Serif'],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${score.composer} · ${score.level} · ${score.duration}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF7E6C55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _LoadScoreButton(
            hasLoadedSong: hasLoadedSong,
            isLoading: isLoading,
            onPressed: onLoadAssetScore,
          ),
        ],
      ),
    );
  }
}

class _LoadScoreButton extends StatelessWidget {
  final bool hasLoadedSong;
  final bool isLoading;
  final VoidCallback onPressed;

  const _LoadScoreButton({
    required this.hasLoadedSong,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      minimumSize: const Size(0, 0),
      borderRadius: BorderRadius.circular(999),
      color: hasLoadedSong ? const Color(0xFF385F4D) : const Color(0xFF2D241B),
      onPressed: isLoading ? null : onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            const CupertinoActivityIndicator(radius: 8)
          else
            Icon(
              hasLoadedSong
                  ? CupertinoIcons.check_mark_circled_solid
                  : CupertinoIcons.arrow_down_doc_fill,
              size: 15,
              color: CupertinoColors.white,
            ),
          const SizedBox(width: 6),
          Text(
            hasLoadedSong ? '已载入' : '载入',
            style: const TextStyle(fontSize: 12, color: CupertinoColors.white),
          ),
        ],
      ),
    );
  }
}

class _ScorePaper extends StatelessWidget {
  final PracticeScoreMetadata score;
  final double progress;
  final bool annotationsVisible;

  const _ScorePaper({
    required this.score,
    required this.progress,
    required this.annotationsVisible,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF9F1DF),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: AspectRatio(
          aspectRatio: 0.72,
          child: CustomPaint(
            painter: _PracticeScorePainter(
              title: score.title,
              composer: score.composer,
              accent: score.accent,
              seed: score.seed,
              progress: progress,
              annotationsVisible: annotationsVisible,
            ),
          ),
        ),
      ),
    );
  }
}

class _PracticeTimeline extends StatelessWidget {
  final MidiPlayerController player;
  final bool isScoreLoaded;
  final double progress;
  final ValueChanged<double> onSeek;

  const _PracticeTimeline({
    required this.player,
    required this.isScoreLoaded,
    required this.progress,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final hasSong = isScoreLoaded && player.totalDuration > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
      child: Column(
        children: [
          CupertinoSlider(
            value: progress,
            min: 0,
            max: 1,
            activeColor: const Color(0xFF5C4A36),
            thumbColor: const Color(0xFF2D241B),
            onChanged: hasSong ? onSeek : null,
          ),
          Row(
            children: [
              Text(
                hasSong ? formatClock(player.currentTime) : '0:00',
                style: const TextStyle(fontSize: 12, color: Color(0xFF7E6C55)),
              ),
              const Spacer(),
              Text(
                hasSong ? formatClock(player.totalDuration) : '预览模式',
                style: const TextStyle(fontSize: 12, color: Color(0xFF7E6C55)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PracticeOptions extends StatelessWidget {
  final double tempo;
  final bool aiTempoEnabled;
  final bool loopEnabled;
  final bool annotationsVisible;
  final ValueChanged<double> onTempoChanged;
  final VoidCallback onToggleAiTempo;
  final VoidCallback onToggleLoop;
  final VoidCallback onToggleAnnotations;

  const _PracticeOptions({
    required this.tempo,
    required this.aiTempoEnabled,
    required this.loopEnabled,
    required this.annotationsVisible,
    required this.onTempoChanged,
    required this.onToggleAiTempo,
    required this.onToggleLoop,
    required this.onToggleAnnotations,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.white.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD4C4A7)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '排练控制',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2A2118),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(CupertinoIcons.metronome, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${tempo.toStringAsFixed(2)}x',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2A2118),
                  ),
                ),
                Expanded(
                  child: CupertinoSlider(
                    value: tempo.clamp(0.5, 1.5),
                    min: 0.5,
                    max: 1.5,
                    divisions: 20,
                    activeColor: const Color(0xFF5C4A36),
                    onChanged: onTempoChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _OptionChip(
                  label: 'AI 跟随',
                  icon: CupertinoIcons.sparkles,
                  selected: aiTempoEnabled,
                  onPressed: onToggleAiTempo,
                ),
                _OptionChip(
                  label: '循环',
                  icon: CupertinoIcons.repeat,
                  selected: loopEnabled,
                  onPressed: onToggleLoop,
                ),
                _OptionChip(
                  label: '标注',
                  icon: CupertinoIcons.pencil,
                  selected: annotationsVisible,
                  onPressed: onToggleAnnotations,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  const _OptionChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      minimumSize: const Size(0, 0),
      borderRadius: BorderRadius.circular(999),
      color: selected ? const Color(0xFF2D241B) : const Color(0xFFE8DCC6),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: selected ? CupertinoColors.white : const Color(0xFF4B3A28),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? CupertinoColors.white : const Color(0xFF4B3A28),
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeToolbar extends StatelessWidget {
  final bool isPlaying;
  final bool loopEnabled;
  final bool annotationsVisible;
  final bool aiTempoEnabled;
  final VoidCallback onPlayPause;
  final VoidCallback onToggleLoop;
  final VoidCallback onToggleAnnotations;
  final VoidCallback onToggleAiTempo;

  const _PracticeToolbar({
    required this.isPlaying,
    required this.loopEnabled,
    required this.annotationsVisible,
    required this.aiTempoEnabled,
    required this.onPlayPause,
    required this.onToggleLoop,
    required this.onToggleAnnotations,
    required this.onToggleAiTempo,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF3E3540).withValues(alpha: 0.98),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 78,
          child: Row(
            children: [
              _ToolbarItem(
                icon: CupertinoIcons.music_note_list,
                label: '谱面',
                selected: true,
                onPressed: () {},
              ),
              _ToolbarItem(
                icon: CupertinoIcons.hand_draw,
                label: '指法',
                selected: false,
                onPressed: () {},
              ),
              _ToolbarItem(
                icon: CupertinoIcons.arrow_up_arrow_down,
                label: '移调',
                selected: false,
                onPressed: () {},
              ),
              _ToolbarItem(
                icon: CupertinoIcons.repeat,
                label: '循环',
                selected: loopEnabled,
                onPressed: onToggleLoop,
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                onPressed: onPlayPause,
                child: Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    isPlaying
                        ? CupertinoIcons.pause_fill
                        : CupertinoIcons.play_fill,
                    size: 28,
                    color: const Color(0xFF2D241B),
                  ),
                ),
              ),
              _ToolbarItem(
                icon: CupertinoIcons.pencil,
                label: '标注',
                selected: annotationsVisible,
                onPressed: onToggleAnnotations,
              ),
              _ToolbarItem(
                icon: CupertinoIcons.sparkles,
                label: '跟随',
                selected: aiTempoEnabled,
                onPressed: onToggleAiTempo,
              ),
              _ToolbarItem(
                icon: CupertinoIcons.doc_text,
                label: '视奏',
                selected: false,
                onPressed: () {},
              ),
              _ToolbarItem(
                icon: CupertinoIcons.ellipsis,
                label: '更多',
                selected: false,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _ToolbarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 7),
        minimumSize: const Size(0, 0),
        onPressed: onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected
                  ? const Color(0xFFF4DFAE)
                  : CupertinoColors.white.withValues(alpha: 0.64),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: selected
                    ? const Color(0xFFF4DFAE)
                    : CupertinoColors.white.withValues(alpha: 0.64),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticeScorePainter extends CustomPainter {
  final String title;
  final String composer;
  final Color accent;
  final int seed;
  final double progress;
  final bool annotationsVisible;

  const _PracticeScorePainter({
    required this.title,
    required this.composer,
    required this.accent,
    required this.seed,
    required this.progress,
    required this.annotationsVisible,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()..color = const Color(0xFF15110D);
    final staff = Paint()
      ..color = const Color(0xFF15110D)
      ..strokeWidth = math.max(0.85, size.width / 760);
    final thin = Paint()
      ..color = const Color(0xFF15110D).withValues(alpha: 0.72)
      ..strokeWidth = math.max(0.55, size.width / 980);
    final cursorPaint = Paint()
      ..color = accent.withValues(alpha: 0.26)
      ..style = PaintingStyle.fill;
    final annotationPaint = Paint()
      ..color = accent.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    _drawTitle(canvas, size);

    final left = size.width * 0.08;
    final right = size.width * 0.95;
    final firstTop = size.height * 0.18;
    final systemGap = size.height * 0.205;
    final staffGap = size.height * 0.055;
    final lineGap = size.height * 0.0092;
    final clefWidth = size.width * 0.06;
    final keySigWidth = size.width * 0.085;
    const systemCount = 4;
    final cursorSystem = (progress * systemCount).floor().clamp(
      0,
      systemCount - 1,
    );
    final cursorLocal = (progress * systemCount - cursorSystem).clamp(0.0, 1.0);

    for (var system = 0; system < systemCount; system += 1) {
      final top = firstTop + system * systemGap;
      final trebleTop = top;
      final bassTop = top + staffGap;
      final startX = left + size.width * 0.045;
      // 谱号 + 调号占据起始一段，音符/小节线从这里之后才开始，避免互相重叠。
      final contentLeft = startX + clefWidth + keySigWidth;
      final span = right - contentLeft;

      _drawBrace(canvas, left, trebleTop, bassTop + lineGap * 4, thin);
      _drawTrebleClef(canvas, startX, trebleTop, lineGap, ink);
      _drawBassClef(canvas, startX, bassTop, lineGap, ink);
      _drawKeySignature(canvas, startX + clefWidth, trebleTop, ink);
      _drawKeySignature(canvas, startX + clefWidth, bassTop, ink);

      for (var line = 0; line < 5; line += 1) {
        final trebleY = trebleTop + line * lineGap;
        final bassY = bassTop + line * lineGap;
        canvas.drawLine(Offset(startX, trebleY), Offset(right, trebleY), staff);
        canvas.drawLine(Offset(startX, bassY), Offset(right, bassY), staff);
      }

      final barCount = system == 0 ? 5 : 4;
      for (var bar = 0; bar <= barCount; bar += 1) {
        final x = contentLeft + span * bar / barCount;
        canvas.drawLine(
          Offset(x, trebleTop),
          Offset(x, bassTop + lineGap * 4),
          thin,
        );
      }

      if (system == cursorSystem) {
        final x = contentLeft + span * cursorLocal;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              x - size.width * 0.006,
              trebleTop - lineGap * 1.6,
              size.width * 0.018,
              staffGap + lineGap * 7.2,
            ),
            Radius.circular(size.width * 0.006),
          ),
          cursorPaint,
        );
      }

      if (annotationsVisible && system < 3) {
        final x = contentLeft + span * (0.18 + system * 0.12);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, bassTop - lineGap * 1.4, 18, 18),
            const Radius.circular(4),
          ),
          annotationPaint,
        );
      }

      _drawNotes(
        canvas,
        contentLeft,
        right,
        trebleTop,
        lineGap,
        system,
        true,
        ink,
      );
      _drawNotes(
        canvas,
        contentLeft,
        right,
        bassTop,
        lineGap,
        system,
        false,
        ink,
      );

      _drawMeasureNumber(canvas, system, left * 0.72, trebleTop);
    }
  }

  void _drawTitle(Canvas canvas, Size size) {
    _drawText(
      canvas,
      title,
      Offset(size.width / 2, size.height * 0.055),
      fontSize: math.max(18, size.width * 0.036),
      color: const Color(0xFF15110D),
      anchor: _TextAnchor.center,
      weight: FontWeight.w600,
    );
    _drawText(
      canvas,
      composer,
      Offset(size.width * 0.92, size.height * 0.105),
      fontSize: math.max(10, size.width * 0.017),
      color: const Color(0xFF2B231B),
      anchor: _TextAnchor.right,
    );
    _drawText(
      canvas,
      'Allegretto',
      Offset(size.width * 0.18, size.height * 0.155),
      fontSize: math.max(11, size.width * 0.018),
      color: const Color(0xFF15110D),
      anchor: _TextAnchor.left,
      weight: FontWeight.w600,
    );
  }

  void _drawBrace(
    Canvas canvas,
    double x,
    double top,
    double bottom,
    Paint paint,
  ) {
    final path = Path()
      ..moveTo(x + 10, top)
      ..cubicTo(x - 8, top + 18, x - 8, bottom - 18, x + 10, bottom);
    canvas.drawPath(path, paint..style = PaintingStyle.stroke);
  }

  /// 矢量高音谱号（G 谱号）。用绘制代替 Unicode 字形，避免 iOS 缺字显示成 "?"。
  void _drawTrebleClef(
    Canvas canvas,
    double x,
    double top,
    double gap,
    Paint ink,
  ) {
    final stroke = Paint()
      ..color = ink.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.1, gap * 0.5)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final cx = x + gap * 1.4;
    final path = Path()
      ..moveTo(cx + gap * 0.8, top - gap * 0.4)
      ..cubicTo(
        cx - gap * 1.3,
        top - gap * 0.2,
        cx - gap * 1.2,
        top + gap * 2.4,
        cx + gap * 0.3,
        top + gap * 2.7,
      )
      ..cubicTo(
        cx + gap * 1.7,
        top + gap * 3.0,
        cx + gap * 1.4,
        top + gap * 0.7,
        cx - gap * 0.2,
        top + gap * 1.0,
      )
      ..cubicTo(
        cx - gap * 1.0,
        top + gap * 1.2,
        cx - gap * 0.3,
        top + gap * 3.6,
        cx + gap * 0.4,
        top + gap * 4.2,
      )
      ..cubicTo(
        cx + gap * 1.0,
        top + gap * 4.7,
        cx + gap * 0.5,
        top + gap * 5.4,
        cx - gap * 0.2,
        top + gap * 5.1,
      );
    canvas.drawPath(path, stroke);
    canvas.drawCircle(
      Offset(cx + gap * 0.15, top + gap * 1.85),
      gap * 0.55,
      ink,
    );
  }

  /// 矢量低音谱号（F 谱号）：弯钩 + 两个点。
  void _drawBassClef(
    Canvas canvas,
    double x,
    double top,
    double gap,
    Paint ink,
  ) {
    final stroke = Paint()
      ..color = ink.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.1, gap * 0.55)
      ..strokeCap = StrokeCap.round;
    final sx = x + gap * 0.6;
    final path = Path()
      ..moveTo(sx, top + gap * 0.7)
      ..cubicTo(
        sx + gap * 2.4,
        top - gap * 0.2,
        sx + gap * 2.8,
        top + gap * 2.4,
        sx + gap * 0.9,
        top + gap * 3.1,
      )
      ..cubicTo(
        sx + gap * 0.2,
        top + gap * 3.4,
        sx - gap * 0.3,
        top + gap * 3.0,
        sx - gap * 0.1,
        top + gap * 2.5,
      );
    canvas.drawPath(path, stroke);
    canvas.drawCircle(Offset(sx + gap * 0.4, top + gap * 0.7), gap * 0.5, ink);
    canvas.drawCircle(Offset(sx + gap * 3.1, top + gap * 0.7), gap * 0.3, ink);
    canvas.drawCircle(Offset(sx + gap * 3.1, top + gap * 1.7), gap * 0.3, ink);
  }

  /// 矢量四分休止符，替换 Unicode '𝄽'（同样会缺字成 "?"）。
  void _drawRest(Canvas canvas, double cx, double midY, double gap, Paint ink) {
    final stroke = Paint()
      ..color = ink.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, gap * 0.7)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(cx - gap * 0.6, midY - gap * 1.6)
      ..lineTo(cx + gap * 0.5, midY - gap * 0.4)
      ..lineTo(cx - gap * 0.5, midY + gap * 0.6)
      ..lineTo(cx + gap * 0.6, midY + gap * 1.8);
    canvas.drawPath(path, stroke);
  }

  void _drawKeySignature(Canvas canvas, double x, double top, Paint paint) {
    for (var i = 0; i < 3; i += 1) {
      _drawText(
        canvas,
        '#',
        Offset(x + 12 + i * 9, top - 8 + (i.isEven ? 0 : 6)),
        fontSize: 17,
        color: paint.color,
        anchor: _TextAnchor.left,
        weight: FontWeight.w700,
      );
    }
  }

  void _drawMeasureNumber(Canvas canvas, int system, double x, double y) {
    final number = switch (system) {
      0 => '',
      1 => '5',
      2 => '8',
      _ => '11',
    };
    if (number.isEmpty) return;
    _drawText(
      canvas,
      number,
      Offset(x, y - 8),
      fontSize: 12,
      color: const Color(0xFF15110D),
      anchor: _TextAnchor.left,
    );
  }

  void _drawNotes(
    Canvas canvas,
    double left,
    double right,
    double top,
    double gap,
    int system,
    bool treble,
    Paint ink,
  ) {
    final width = right - left;
    final noteCount = treble ? 14 : 8;
    for (var i = 0; i < noteCount; i += 1) {
      final t = (i + 0.5) / noteCount;
      final x = left + width * t;
      final step = (i * 2 + seed + system + (treble ? 1 : 4)) % 5;
      final y = top + gap * step;
      final isRest = !treble && i % 4 == 1;
      if (isRest) {
        _drawRest(canvas, x, top + gap * 2, gap, ink);
        continue;
      }

      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 9.0, height: 6.2),
        ink,
      );
      // 高音谱表符干一律朝上、低音谱表朝下，避免符干伸进相邻谱表造成重叠。
      final stemUp = treble;
      final stemEnd = stemUp ? y - gap * 2.8 : y + gap * 2.8;
      final stemX = stemUp ? x + 4 : x - 4;
      canvas.drawLine(Offset(stemX, y), Offset(stemX, stemEnd), ink);
      if (treble && i % 3 != 0) {
        canvas.drawLine(
          Offset(stemX, stemEnd),
          Offset(stemX + 12, stemEnd + 2),
          ink,
        );
      }
      if (annotationsVisible && treble && i % 7 == 2) {
        _drawText(
          canvas,
          '${(i + system) % 5 + 1}',
          Offset(x, y - gap * 3.9),
          fontSize: 10,
          color: const Color(0xFF15110D),
          anchor: _TextAnchor.center,
        );
      }
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    required double fontSize,
    required Color color,
    required _TextAnchor anchor,
    FontWeight weight = FontWeight.normal,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize, color: color, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (anchor) {
      _TextAnchor.left => offset.dx,
      _TextAnchor.center => offset.dx - textPainter.width / 2,
      _TextAnchor.right => offset.dx - textPainter.width,
    };
    textPainter.paint(canvas, Offset(dx, offset.dy));
  }

  @override
  bool shouldRepaint(covariant _PracticeScorePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.annotationsVisible != annotationsVisible ||
        oldDelegate.accent != accent ||
        oldDelegate.seed != seed ||
        oldDelegate.title != title ||
        oldDelegate.composer != composer;
  }
}

enum _TextAnchor { left, center, right }
