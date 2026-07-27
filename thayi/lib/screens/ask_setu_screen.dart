import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../data/chat_service.dart';
import '../l10n/app_localizations.dart';
import '../l10n/content.dart';
import '../providers.dart';
import '../routes.dart';
import '../theme/tokens.dart';
import '../widgets/setu_scaffold.dart';
import 'danger_alert_screen.dart';

class _Message {
  _Message.fromMother(this.text)
      : fromMother = true,
        answer = null,
        blocked = false;
  _Message.fromSetu(this.answer)
      : fromMother = false,
        text = null,
        blocked = false;
  _Message.blocked()
      : fromMother = false,
        text = null,
        answer = null,
        blocked = true;

  final bool fromMother;
  final String? text;
  final ChatAnswer? answer;

  /// A note in the transcript saying the message was held back on purpose.
  final bool blocked;
}

class AskSetuScreen extends ConsumerStatefulWidget {
  const AskSetuScreen({super.key});

  @override
  ConsumerState<AskSetuScreen> createState() => _AskSetuScreenState();
}

class _AskSetuScreenState extends ConsumerState<AskSetuScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _speech = SpeechToText();

  final List<_Message> _messages = [];
  bool _thinking = false;
  bool _listening = false;
  bool _speechReady = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String raw, {ChatAnswer? preferred}) async {
    final text = raw.trim();
    if (text.isEmpty || _thinking) return;

    // ---- The safety gate. This runs on every message, before anything
    // ---- is handed to the chat service. It is a keyword matcher, not a
    // ---- model call, and it is the reason the message may never be sent.
    final match = ref.read(dangerSignDetectorProvider).detect(text);
    if (match != null) {
      setState(() {
        _messages
          ..add(_Message.fromMother(text))
          ..add(_Message.blocked());
        _input.clear();
      });
      _scrollToEnd();
      await DangerAlertScreen.show(context, match);
      return;
    }

    setState(() {
      _messages.add(_Message.fromMother(text));
      _input.clear();
      _thinking = true;
    });
    _scrollToEnd();

    final reply = await ref
        .read(chatServiceProvider)
        .ask(text, preferredAnswer: preferred);
    if (!mounted) return;
    setState(() {
      _messages.add(_Message.fromSetu(reply.answer));
      _thinking = false;
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _toggleMic() async {
    final l = AppLocalizations.of(context);

    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    // Explain before asking. The system dialog on its own means nothing to
    // someone who has never been asked for a microphone before.
    final status = await Permission.microphone.status;
    if (!status.isGranted) {
      if (!mounted) return;
      final agreed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: C.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(S.radius),
          ),
          title: Text(l.micPermissionTitle, style: T.h2),
          content: Text(l.micPermissionBody, style: T.body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                minimumSize: const Size(120, S.tapMin),
              ),
              child: Text(l.micAllow),
            ),
          ],
        ),
      );
      if (agreed != true) return;
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        _toast(l.micDenied);
        return;
      }
    }

    if (!_speechReady) {
      _speechReady = await _speech.initialize(
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') {
            if (mounted) setState(() => _listening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
    }
    if (!_speechReady) {
      _toast(l.micUnavailable);
      return;
    }

    final localeId =
        ref.read(localeControllerProvider).languageCode == 'kn'
            ? 'kn_IN'
            : 'en_IN';

    setState(() => _listening = true);
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        partialResults: true,
      ),
      onResult: (result) {
        _input.value = TextEditingValue(
          text: result.recognizedWords,
          selection:
              TextSelection.collapsed(offset: result.recognizedWords.length),
        );
        if (result.finalResult && mounted) {
          setState(() => _listening = false);
        }
      },
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: T.body)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mother = ref.watch(motherProvider).valueOrNull;

    return SetuScaffold(
      title: l.askSetuTitle,
      showEmergencyButton: false,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(S.screen, S.md, S.screen, S.md),
              children: [
                _Bubble.setu(text: l.chatWelcome),
                for (final m in _messages) ...[
                  const SizedBox(height: S.md),
                  if (m.blocked)
                    _BlockedNote()
                  else if (m.fromMother)
                    _Bubble.mother(text: m.text!)
                  else ...[
                    _Bubble.setu(text: l.chatAnswer(m.answer!)),
                    if (m.answer == ChatAnswer.fallback) ...[
                      const SizedBox(height: S.sm),
                      _ContactAshaButton(
                        onDone: () => _toast(
                          l.messageSentToAsha(
                            mother == null ? '' : l.ashaName(mother.asha),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
                if (_thinking) ...[
                  const SizedBox(height: S.md),
                  _Bubble.setu(text: l.chatThinking, muted: true),
                ],
                const SizedBox(height: S.lg),
              ],
            ),
          ),
          _Composer(
            input: _input,
            listening: _listening,
            onSend: () => _send(_input.text),
            onMic: _toggleMic,
            onSuggestion: (q) =>
                _send(l.suggestedQuestion(q.id), preferred: q.answer),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble.mother({required this.text})
      : fromMother = true,
        muted = false;
  const _Bubble.setu({required this.text, this.muted = false})
      : fromMother = false;

  final String text;
  final bool fromMother;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: fromMother ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: S.md, vertical: S.md),
        decoration: BoxDecoration(
          color: fromMother ? C.terraSoft : C.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(S.radius),
            topRight: const Radius.circular(S.radius),
            bottomLeft: Radius.circular(fromMother ? S.radius : S.xs),
            bottomRight: Radius.circular(fromMother ? S.xs : S.radius),
          ),
          boxShadow: kCardShadow,
        ),
        child: Text(
          text,
          style: muted ? T.bodySoft : T.body,
        ),
      ),
    );
  }
}

class _BlockedNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(S.md),
      decoration: BoxDecoration(
        color: C.redSoft,
        borderRadius: BorderRadius.circular(S.radius),
        border: Border.all(color: C.red, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: C.red, size: 26),
          const SizedBox(width: S.sm),
          Expanded(
            child: Text(
              l.dangerInterruptNote,
              style: T.body.copyWith(color: C.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactAshaButton extends StatelessWidget {
  const _ContactAshaButton({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () {
          onDone();
          Navigator.pushNamed(context, Routes.asha);
        },
        icon: const Icon(Icons.person_outline, size: 24),
        label: Text(l.contactAshaFromChat),
        style: OutlinedButton.styleFrom(
          foregroundColor: C.terra,
          side: const BorderSide(color: C.terra, width: 1.5),
          minimumSize: const Size(0, S.tapMin),
          padding: const EdgeInsets.symmetric(horizontal: S.md),
          textStyle: T.button.copyWith(fontSize: 17),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.input,
    required this.listening,
    required this.onSend,
    required this.onMic,
    required this.onSuggestion,
  });

  final TextEditingController input;
  final bool listening;
  final VoidCallback onSend;
  final VoidCallback onMic;
  final void Function(SuggestedQuestion) onSuggestion;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: C.bg,
        border: Border(top: BorderSide(color: C.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tappable questions matter more than the text field for someone
            // who cannot type.
            SizedBox(
              height: 108,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(S.screen, S.sm, S.screen, 0),
                children: [
                  for (final topic in ChatTopic.values)
                    Padding(
                      padding: const EdgeInsets.only(right: S.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.chatTopic(topic), style: T.label),
                          const SizedBox(height: S.xs),
                          Row(
                            children: [
                              for (final q in kSuggestedQuestions
                                  .where((q) => q.topic == topic))
                                Padding(
                                  padding: const EdgeInsets.only(right: S.sm),
                                  child: _Chip(
                                    label: l.suggestedQuestion(q.id),
                                    onTap: () => onSuggestion(q),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(S.screen, S.sm, S.screen, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: input,
                      minLines: 1,
                      maxLines: 4,
                      style: T.body,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                      decoration: InputDecoration(
                        hintText: listening ? l.chatListening : l.chatHint,
                      ),
                    ),
                  ),
                  const SizedBox(width: S.sm),
                  _RoundButton(
                    icon: listening ? Icons.stop : Icons.mic_none,
                    label: l.chatSpeak,
                    color: listening ? C.red : C.tealSoft,
                    iconColor: listening ? C.onDark : C.teal,
                    onTap: onMic,
                  ),
                  const SizedBox(width: S.sm),
                  _RoundButton(
                    icon: Icons.send,
                    label: l.chatSend,
                    color: C.teal,
                    iconColor: C.onDark,
                    onTap: onSend,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(S.screen, S.sm, S.screen, S.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: C.textSoft),
                  const SizedBox(width: S.xs),
                  Flexible(
                    child: Text(
                      l.chatDisclaimer,
                      style: T.label.copyWith(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: C.tealSoft,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48, maxWidth: 260),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: S.md),
          child: Text(
            label,
            style: T.body.copyWith(fontSize: 17, color: C.teal),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: S.tapMin,
            height: S.tapMin,
            child: Icon(icon, color: iconColor, size: 28),
          ),
        ),
      ),
    );
  }
}
