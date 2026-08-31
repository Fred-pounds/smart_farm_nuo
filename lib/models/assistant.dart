/// Who said a line in the assistant conversation.
enum ChatRole { farmer, assistant, system }

/// One line in the visible conversation.
///
/// Separate from the wire format sent to the model: the transcript the farmer
/// reads and the message array the API receives diverge deliberately — tool
/// plumbing and the injected farm state never appear on screen, and the farm
/// state is never replayed into history (see `AssistantProvider`).
class ChatTurn {
  final ChatRole role;
  final String text;
  final DateTime at;

  /// Set when this turn reports the outcome of a device action, so the UI can
  /// mark it as an event rather than an opinion.
  final bool isDeviceOutcome;

  /// Set when the turn is an error or refusal rather than an answer.
  final bool isProblem;

  ChatTurn({
    required this.role,
    required this.text,
    DateTime? at,
    this.isDeviceOutcome = false,
    this.isProblem = false,
  }) : at = at ?? DateTime.now();
}

/// A pump action the model asked for.
///
/// This is a *request*, not an action. It is validated by the same
/// `PumpCommandMachine` that guards the on-screen button — the model has no
/// privileged path to the relay, and no way to bypass automatic mode, the
/// command lock, or the offline check.
class PumpIntent {
  /// True to start the pump, false to stop it.
  final bool start;

  /// The model's stated reason, echoed back to the farmer so an unexplained
  /// device action is impossible.
  final String reason;

  /// The API's id for this tool call; the result must be returned against it.
  final String toolUseId;

  const PumpIntent({
    required this.start,
    required this.reason,
    required this.toolUseId,
  });

  static const String toolName = 'request_pump';

  /// The tool schema, in OpenAI function-calling shape.
  ///
  /// Kept deliberately small — two fields, one of them a two-value enum.
  /// Smaller open-weights models are far more reliable at filling a narrow
  /// schema than a rich one, and the app validates every field anyway
  /// ([tryParse]), so a malformed call is refused rather than acted on.
  static Map<String, dynamic> get toolDefinition => {
    'type': 'function',
    'function': {
      'name': toolName,
      'description':
          'Request a change to the irrigation pump. This only creates a '
          'request: the app validates it against the operating mode, an '
          'in-flight command lock, and connectivity, and may refuse it. The '
          'pump has NOT changed when this returns — the result will say '
          'exactly what happened, and you must report only that.',
      'parameters': {
        'type': 'object',
        'properties': {
          'action': {
            'type': 'string',
            'enum': ['start', 'stop'],
            'description': 'start to run the pump, stop to halt it.',
          },
          'reason': {
            'type': 'string',
            'description':
                'One short sentence on why, in terms the farmer can check '
                'against the farm state.',
          },
        },
        'required': ['action', 'reason'],
        'additionalProperties': false,
      },
    },
  };

  static PumpIntent? tryParse(String toolUseId, Map<String, dynamic> input) {
    final action = input['action'];
    final reason = input['reason'];
    if (action is! String || reason is! String) return null;
    if (action != 'start' && action != 'stop') return null;
    return PumpIntent(
      start: action == 'start',
      reason: reason,
      toolUseId: toolUseId,
    );
  }
}

/// One tool call the model made, before the app has done anything about it.
class AssistantToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> input;

  const AssistantToolCall({
    required this.id,
    required this.name,
    required this.input,
  });
}

/// A parsed reply from the model.
class AssistantReply {
  /// Prose for the farmer. Empty when the model only called a tool.
  final String text;

  final List<AssistantToolCall> toolCalls;

  /// The provider's `finish_reason`.
  final String finishReason;

  /// The assistant message exactly as it must be echoed back to continue a
  /// tool-calling exchange. Rebuilt rather than passed through, so a provider
  /// that returns extra fields cannot corrupt the next request.
  final Map<String, dynamic> assistantMessage;

  const AssistantReply({
    required this.text,
    required this.toolCalls,
    required this.finishReason,
    required this.assistantMessage,
  });

  bool get wantsToolUse => toolCalls.isNotEmpty;

  /// The reply was cut off mid-sentence by the token cap. Worth telling the
  /// farmer rather than presenting a truncated answer as complete.
  bool get wasTruncated => finishReason == 'length';
}

/// Something went wrong reaching or using the model.
class AssistantException implements Exception {
  final String message;
  const AssistantException(this.message);

  @override
  String toString() => message;
}
