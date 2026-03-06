import 'dart:async';
import 'package:flutter/material.dart';

/// 타이프라이터 효과 텍스트 위젯
/// 글자가 하나씩 나타나며, 탭하면 즉시 전체 표시
class TypingText extends StatefulWidget {
  final String text;
  final Duration charDelay;
  final TextStyle? style;
  final VoidCallback? onComplete;

  const TypingText({
    super.key,
    required this.text,
    this.charDelay = const Duration(milliseconds: 50),
    this.style,
    this.onComplete,
  });

  @override
  State<TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText> {
  String _displayed = '';
  Timer? _timer;
  int _charIndex = 0;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTyping() {
    _timer = Timer.periodic(widget.charDelay, (timer) {
      if (_charIndex >= widget.text.length) {
        timer.cancel();
        _onComplete();
        return;
      }
      if (mounted) {
        setState(() {
          _charIndex++;
          _displayed = widget.text.substring(0, _charIndex);
        });
      }
    });
  }

  void _skipToEnd() {
    _timer?.cancel();
    if (mounted && !_completed) {
      setState(() {
        _displayed = widget.text;
        _charIndex = widget.text.length;
      });
      _onComplete();
    }
  }

  void _onComplete() {
    if (_completed) return;
    _completed = true;
    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _skipToEnd,
      child: Text(
        _displayed,
        style: widget.style,
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// NPC 인트로 대사 시퀀스 위젯
/// 여러 줄의 대사를 순차적으로 타이핑 애니메이션으로 표시
class IntroSequence extends StatefulWidget {
  final List<String> lines;
  final Duration lineDelay;
  final TextStyle? style;
  final VoidCallback? onComplete;

  const IntroSequence({
    super.key,
    required this.lines,
    this.lineDelay = const Duration(milliseconds: 1500),
    this.style,
    this.onComplete,
  });

  @override
  State<IntroSequence> createState() => _IntroSequenceState();
}

class _IntroSequenceState extends State<IntroSequence> {
  int _currentLine = 0;
  bool _allComplete = false;

  void _onLineComplete() {
    Future.delayed(widget.lineDelay, () {
      if (!mounted || _allComplete) return;
      if (_currentLine < widget.lines.length - 1) {
        setState(() {
          _currentLine++;
        });
      } else {
        _allComplete = true;
        widget.onComplete?.call();
      }
    });
  }

  void _skipAll() {
    if (_allComplete) return;
    setState(() {
      _currentLine = widget.lines.length - 1;
      _allComplete = true;
    });
    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _skipAll,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i <= _currentLine && i < widget.lines.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: i == _currentLine && !_allComplete
                  ? TypingText(
                      key: ValueKey('line_$i'),
                      text: widget.lines[i],
                      charDelay: const Duration(milliseconds: 60),
                      style: widget.style,
                      onComplete: _onLineComplete,
                    )
                  : Text(
                      widget.lines[i],
                      style: widget.style,
                      textAlign: TextAlign.center,
                    ),
            ),
        ],
      ),
    );
  }
}
