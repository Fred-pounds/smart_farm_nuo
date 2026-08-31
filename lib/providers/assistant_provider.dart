import 'package:flutter/foundation.dart';

import '../models/assistant.dart';
import '../services/assistant_config.dart';
import '../services/assistant_service.dart';

/// Performs a pump request and returns an honest account of what happened.
///
/// Injected rather than held as a `FarmProvider` reference so the assistant's
/// control flow can be tested without Firebase — and so there is exactly one
/// way for the model to reach the pump.
typedef PumpCommander = Future<String> Function(bool start);

/// Builds the current farm state block. Called fresh on every request.
typedef FarmStateBuilder = String Function();

/// The conversation, and the bridge between the model and the farm.
///
/// The safety property this class exists to hold: **the model cannot move
/// water.** It can ask. Every request runs through the injected
/// [PumpCommander], which is wired to the same `FarmProvider.requestPump` the
/// on-screen button uses — so automatic-mode refusal, the command lock, the
/// debounce and the offline check all apply unchanged. The model is then told
/// what actually happened and can only report that.
class AssistantProvider extends ChangeNotifier {
  final AssistantService _service = AssistantService();

  /// How many times the model may call a tool within one question before the
  /// app stops looping. A farm question needs at most one device action; more
  /// than this is a malfunction, not a workflow.
  static const int _maxToolRounds = 3;

  final List<ChatTurn> _turns = [];

  /// The conversation in API shape. Deliberately holds no farm state — that is
  /// appended fresh per request and never persisted into history, so an old
  /// reading can never be answered as if it were current.
  final List<Map<String, dynamic>> _wire = [];

  bool _busy = false;
  String? _error;

  PumpCommander? _pumpCommander;
  FarmStateBuilder? _farmState;

  List<ChatTurn> get turns => List.unmodifiable(_turns);
  bool get isBusy => _busy;
  String? get error => _error;
  bool get isAvailable => AssistantConfig.isConfigured;

  /// True when this build carries an extractable key. Surfaced so the app
  /// can warn rather than pretend the arrangement is safe to distribute.
  bool get usesEmbeddedKey => AssistantConfig.usesEmbeddedKey;

  bool get isEmpty => _turns.isEmpty;

  /// Connects the assistant to the farm. Called once, from the shell.
  void attach({
    required PumpCommander pumpCommander,
    required FarmStateBuilder farmState,
  }) {
    _pumpCommander = pumpCommander;
    _farmState = farmState;
  }

  void clear() {
    _turns.clear();
    _wire.clear();
    _error = null;
    notifyListeners();
  }

  Future<void> ask(String question) async {
    final text = question.trim();
    if (text.isEmpty || _busy) return;

    final buildState = _farmState;
    if (buildState == null) {
      _fail('The assistant is not connected to the farm yet.');
      return;
    }

    _turns.add(ChatTurn(role: ChatRole.farmer, text: text));
    _wire.add({'role': 'user', 'content': text});
    _busy = true;
    _error = null;
    notifyListeners();

    try {
      await _runTurn(buildState);
    } on AssistantException catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail('Something went wrong talking to the assistant. ($e)');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Sends, then services any tool calls and sends again, until the model
  /// answers in prose or the round limit is hit.
  Future<void> _runTurn(FarmStateBuilder buildState) async {
    for (var round = 0; round <= _maxToolRounds; round++) {
      // Rebuilt every round: a pump command issued in the previous round has
      // changed the farm, and the model must see the new state, not the old.
      final reply = await _service.send(
        wireMessages: _wire,
        farmState: buildState(),
      );

      if (reply.text.isNotEmpty) {
        _turns.add(
          ChatTurn(
            role: ChatRole.assistant,
            text: reply.wasTruncated
                ? '${reply.text}…\n\n(cut off — ask me to continue)'
                : reply.text,
          ),
        );
        notifyListeners();
      }

      if (!reply.wantsToolUse) {
        // A model that produced neither prose nor a tool call has failed in a
        // way the farmer would otherwise see as silence.
        if (reply.text.isEmpty) {
          _turns.add(
            ChatTurn(
              role: ChatRole.assistant,
              text: 'The model returned nothing. Try rephrasing the question.',
              isProblem: true,
            ),
          );
        }
        return;
      }

      if (round == _maxToolRounds) {
        _turns.add(
          ChatTurn(
            role: ChatRole.assistant,
            text:
                'I stopped after several attempts to control the pump. Use '
                'the pump card on the Farm screen instead.',
            isProblem: true,
          ),
        );
        return;
      }

      // Echo the assistant turn, then answer each call in its own tool
      // message — this wire format wants one message per call, unlike
      // Anthropic's, which batches them into a single user turn.
      _wire.add(reply.assistantMessage);
      for (final call in reply.toolCalls) {
        _wire.add(await _runTool(call));
      }
    }
  }

  /// Executes one tool call and builds its result block.
  ///
  /// Unknown tools return an error result rather than throwing: an
  /// unrecognised call is the model's mistake to recover from, not a reason to
  /// drop the conversation.
  Future<Map<String, dynamic>> _runTool(AssistantToolCall call) async {
    if (call.name != PumpIntent.toolName) {
      return _toolResult(
        call.id,
        'Unknown tool "${call.name}".',
        isError: true,
      );
    }

    final intent = PumpIntent.tryParse(call.id, call.input);
    if (intent == null) {
      return _toolResult(
        call.id,
        'Could not read that request. Provide action as "start" or "stop" '
        'and a short reason.',
        isError: true,
      );
    }

    final commander = _pumpCommander;
    if (commander == null) {
      return _toolResult(
        call.id,
        'The pump is not reachable from the assistant in this build.',
        isError: true,
      );
    }

    final outcome = await commander(intent.start);

    // Shown to the farmer regardless of what the model says next, so a device
    // action can never happen silently or be described only in the model's
    // own words.
    _turns.add(
      ChatTurn(
        role: ChatRole.system,
        text:
            '${intent.start ? "Start" : "Stop"} pump requested — '
            '${intent.reason}\n$outcome',
        isDeviceOutcome: true,
      ),
    );
    notifyListeners();

    return _toolResult(call.id, outcome);
  }

  Map<String, dynamic> _toolResult(
    String id,
    String content, {
    bool isError = false,
  }) {
    return {
      'role': 'tool',
      'tool_call_id': id,
      // This format has no error flag, so the marker goes in the text the
      // model reads.
      'content': isError ? 'ERROR: $content' : content,
    };
  }

  void _fail(String message) {
    _error = message;
    _turns.add(
      ChatTurn(role: ChatRole.assistant, text: message, isProblem: true),
    );
    notifyListeners();
  }
}
