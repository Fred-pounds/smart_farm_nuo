import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/assistant.dart';
import '../providers/assistant_provider.dart';
import '../providers/farm_profile_provider.dart';
import '../theme/theme.dart';

/// The farm assistant.
///
/// Answers questions about this farm from the state the app already holds, and
/// can request a pump change — which is validated exactly like a button press.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    await context.read<AssistantProvider>().ask(text);
    _scrollToEnd();
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: Tokens.motionBase,
        curve: Tokens.curveStandard,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final assistant = context.watch<AssistantProvider>();
    final farmName = context.watch<FarmProfileProvider>().displayName;

    return GlassScaffold(
      title: 'Ask',
      subtitle: 'About $farmName',
      insideShell: false,
      actions: [
        if (!assistant.isEmpty)
          IconButton(
            tooltip: 'Clear conversation',
            icon: const Icon(Icons.delete_outline_rounded, size: 21),
            onPressed: assistant.clear,
          ),
      ],
      builder: (context, contentPadding) {
        if (!assistant.isAvailable) {
          return ListView(
            padding: contentPadding,
            children: const [_NotConfigured()],
          );
        }

        return Column(
          children: [
            Expanded(
              child: assistant.isEmpty
                  ? ListView(
                      padding: contentPadding,
                      children: [_Suggestions(onPick: _ask)],
                    )
                  : ListView.separated(
                      controller: _scroll,
                      padding: contentPadding,
                      itemCount: assistant.turns.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: Tokens.space3),
                      itemBuilder: (context, i) =>
                          _Bubble(turn: assistant.turns[i]),
                    ),
            ),
            _Composer(
              controller: _input,
              busy: assistant.isBusy,
              onSend: _send,
            ),
          ],
        );
      },
    );
  }

  Future<void> _ask(String question) async {
    await context.read<AssistantProvider>().ask(question);
    _scrollToEnd();
  }
}

/// One line of the conversation.
class _Bubble extends StatelessWidget {
  final ChatTurn turn;

  const _Bubble({required this.turn});

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;

    // Device outcomes are rendered as events, not opinions — the farmer should
    // be able to tell "the app did this" from "the assistant said this".
    if (turn.isDeviceOutcome) {
      return Panel(
        accentBorder: colors.water,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.bolt_rounded, size: 18, color: colors.water),
            const SizedBox(width: Tokens.space3),
            Expanded(
              child: Text(
                turn.text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.inkSecondary,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isFarmer = turn.role == ChatRole.farmer;

    return Align(
      alignment: isFarmer ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space4,
            vertical: Tokens.space3,
          ),
          decoration: BoxDecoration(
            color: isFarmer ? colors.growth : colors.panel,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(Tokens.radiusMd),
              topRight: const Radius.circular(Tokens.radiusMd),
              bottomLeft: Radius.circular(isFarmer ? Tokens.radiusMd : 4),
              bottomRight: Radius.circular(isFarmer ? 4 : Tokens.radiusMd),
            ),
            border: isFarmer
                ? null
                : Border.all(
                    color: turn.isProblem ? colors.alert : colors.panelBorder,
                  ),
          ),
          child: Text(
            turn.text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isFarmer
                  ? Theme.of(context).colorScheme.onPrimary
                  : turn.isProblem
                  ? colors.alert
                  : colors.inkPrimary,
              height: 1.45,
            ),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.busy,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final bottom = MediaQuery.of(context).padding.bottom;

    return GlassSurface(
      strong: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Tokens.space5,
          Tokens.space3,
          Tokens.space3,
          Tokens.space3 + bottom,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !busy,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Ask about your farm…',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: Tokens.space2),
            SizedBox(
              width: 44,
              height: 44,
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton.filled(
                      onPressed: onSend,
                      icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: colors.growth,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  final ValueChanged<String> onPick;

  const _Suggestions({required this.onPick});

  static const List<String> _questions = [
    'How is my farm doing?',
    'Why is the pump off?',
    'Does my soil need water today?',
    'What does the weather mean for irrigation?',
    'Is anything wrong right now?',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ask about your farm',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: Tokens.space2),
        Text(
          'Answers come from your live readings — never from guesswork. If a '
          'sensor is not reporting, it will say so.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.inkSecondary),
        ),
        const SizedBox(height: Tokens.space6),
        for (final q in _questions) ...[
          Panel(
            padding: const EdgeInsets.symmetric(
              horizontal: Tokens.space4,
              vertical: Tokens.space3,
            ),
            onTap: () => onPick(q),
            child: Row(
              children: [
                Expanded(
                  child: Text(q, style: Theme.of(context).textTheme.titleSmall),
                ),
                Icon(
                  Icons.north_east_rounded,
                  size: 16,
                  color: colors.inkTertiary,
                ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space2),
        ],
      ],
    );
  }
}

class _NotConfigured extends StatelessWidget {
  const _NotConfigured();

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;

    return EmptyState(
      art: FarmArt.offline,
      title: 'Assistant not set up',
      message:
          'This build has no assistant credentials. Rebuild with an API key, '
          'or point the app at a server that holds one:\n\n'
          'flutter build apk --release \\\n'
          '  --dart-define=ANTHROPIC_API_KEY=sk-ant-…',
      action: Text(
        'Everything else in the app works without it.',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colors.inkTertiary),
      ),
    );
  }
}
