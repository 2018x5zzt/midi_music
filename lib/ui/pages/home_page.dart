import 'package:flutter/cupertino.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../../core/midi/midi_parser.dart';
import '../../core/midi/midi_player.dart';
import 'player_page.dart';

/// 首页 - MIDI 文件列表
///
/// iOS 风格简约设计：顶部导航栏 + 文件列表 + 导入按钮。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MidiFileParser _parser = MidiFileParser();
  bool _isLoading = false;

  /// 选择并解析 MIDI 文件
  Future<void> _pickAndLoadMidi() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.single.path;
    if (filePath == null) return;

    setState(() => _isLoading = true);

    try {
      final songData = await _parser.parseFile(filePath);
      if (!mounted) return;

      final player = context.read<MidiPlayerController>();
      player.loadSong(songData);

      // 导航到播放器页面
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => const PlayerPage(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('无法解析 MIDI 文件: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('错误'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('确定'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('MIDI 伴奏'),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator(radius: 16))
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 图标
            const Icon(
              CupertinoIcons.music_note_2,
              size: 80,
              color: CupertinoColors.systemBlue,
            ),
            const SizedBox(height: 24),
            // 标题
            Text(
              'MIDI 伴奏播放器',
              style: CupertinoTheme.of(context)
                  .textTheme
                  .navLargeTitleTextStyle,
            ),
            const SizedBox(height: 8),
            Text(
              '选择一个 MIDI 文件开始播放',
              style: CupertinoTheme.of(context)
                  .textTheme
                  .textStyle
                  .copyWith(color: CupertinoColors.secondaryLabel),
            ),
            const SizedBox(height: 40),
            // 导入按钮
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                onPressed: _pickAndLoadMidi,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.folder_open, size: 20),
                    SizedBox(width: 8),
                    Text('选择 MIDI 文件'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
