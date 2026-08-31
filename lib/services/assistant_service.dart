import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/assistant.dart';
import 'assistant_config.dart';

/// Talks to an open-weights model over the OpenAI-compatible
/// chat-completions API.
///
/// One wire format, many free backends — Groq, OpenRouter, Together, vLLM,
/// llama.cpp, LM Studio and Ollama all speak it. See [AssistantConfig] for how
/// to point this at each.
class AssistantService {
  static final AssistantService _instance = AssistantService._internal();
  factory AssistantService() => _instance;
  AssistantService._internal();

  final http.Client _client = http.Client();

  /// Generous: a local Ollama server on modest hardware can take a while to
  /// produce a first token, and timing it out looks like a broken app.
  static const Duration _timeout = Duration(seconds: 90);

  /// Standing instructions.
  ///
  /// Written for a mid-sized open model, which means it is more explicit and
  /// more repetitive than a prompt for a frontier model would be. The rules it
  /// states are also enforced structurally elsewhere — the app validates every
  /// pump request and reports the real outcome — so this prompt improves
  /// behaviour but is never the only thing standing between the model and the
  /// relay.
  static const String _instructions = '''
You are the farm assistant inside Smart Farm, an app a farmer uses to watch and
control a real irrigation controller. Your answers change what someone does
with water, a pump, and a crop. Being wrong costs them money.

RULE 1 — ONLY USE THE FARM STATE BELOW.
The <farm_state> block is your only source of facts about this farm. It is
rebuilt fresh for every message and always describes the farm right now.
- If a number is not in that block, you do not know it. Say so.
- Never invent or estimate a sensor reading, pump state, or weather value.
- If a value says "not reporting", tell the farmer that sensor is not
  reporting. Do not substitute a typical value.
- If a value is marked STALE, or the link is DOWN, say how old it is in the
  same sentence as the value.

RULE 2 — THE PUMP'S STATE IS THE MEASURED STATE.
The farm state lists a measured pump state and a last command. Only the
measured state is real. A command that was sent does not mean the pump moved.

RULE 3 — HOW THIS FARM DECIDES TO IRRIGATE. Never reorder these:
1. Soil moisture decides WHETHER to water. Nothing else starts irrigation.
   This probe reads HIGHER when the soil is DRIER. Above the threshold = dry.
2. Air temperature and humidity decide HOW LONG to water. They never start
   or stop a cycle on their own.
3. Weather can DELAY watering when rain is likely. It can never start it.

RULE 4 — CONTROLLING THE PUMP.
Call the request_pump function only when the farmer asks you to run or stop
the pump. Never call it to check something; it moves water.
- The function makes a request. The app may refuse it. The pump has not
  changed when the function returns.
- The function result tells you what actually happened. Repeat only that.
  If it says the command was sent but not confirmed, say exactly that. Never
  say "the pump is now on" unless the result says CONFIRMED.
- In automatic mode, manual commands are refused on purpose. That is not a
  fault. Explain that the controller is running the pump and the farmer can
  switch to manual themselves. You cannot change the mode.

HOW TO WRITE.
Answer in one or two short sentences. Plain words. No headings, no bullet
lists, no markdown. Say what it means before you say the number: "the soil is
dry" then "1,870". Never mention Firebase, ADC, JSON, or field names — the
farmer does not use those. If something in the farm state looks broken, say so
and say what to check.
''';

  /// Sends one turn.
  ///
  /// [farmState] is placed at the end of the system message rather than in the
  /// conversation, so it is always present, always current, and never
  /// accumulates: an old reading can never be answered as though it were live.
  /// Putting it last also keeps the stable prefix intact for servers that do
  /// prefix caching.
  Future<AssistantReply> send({
    required List<Map<String, dynamic>> wireMessages,
    required String farmState,
  }) async {
    if (!AssistantConfig.isConfigured) {
      throw const AssistantException(
        'The assistant is not set up on this build. It needs a model server '
        'to talk to.',
      );
    }

    final body = <String, dynamic>{
      'model': AssistantConfig.model,
      'max_tokens': AssistantConfig.maxTokens,
      'temperature': AssistantConfig.temperature,
      'tools': [PumpIntent.toolDefinition],
      'tool_choice': 'auto',
      'messages': [
        {'role': 'system', 'content': '$_instructions\n\n$farmState'},
        ...wireMessages,
      ],
    };

    late final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('${AssistantConfig.baseUrl}/chat/completions'),
            headers: {
              'content-type': 'application/json',
              if (AssistantConfig.apiKey.isNotEmpty)
                'authorization': 'Bearer ${AssistantConfig.apiKey}',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } catch (e) {
      throw AssistantException(_networkMessage(e));
    }

    if (response.statusCode != 200) {
      throw AssistantException(_httpMessage(response));
    }

    return _parse(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  AssistantReply _parse(Map<String, dynamic> json) {
    final choices = json['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw const AssistantException('The model returned an empty reply.');
    }

    final choice = (choices.first as Map).cast<String, dynamic>();
    final message = ((choice['message'] as Map?) ?? const {})
        .cast<String, dynamic>();
    final finishReason = (choice['finish_reason'] as String?) ?? 'stop';

    final text = (message['content'] as String?)?.trim() ?? '';
    final rawCalls = (message['tool_calls'] as List?) ?? const [];

    final toolCalls = <AssistantToolCall>[];
    final echoedCalls = <Map<String, dynamic>>[];

    for (final raw in rawCalls) {
      if (raw is! Map) continue;
      final fn = (raw['function'] as Map?)?.cast<String, dynamic>();
      if (fn == null) continue;

      final id = raw['id'] as String? ?? '';
      final name = fn['name'] as String? ?? '';

      // Unlike Anthropic's API, arguments arrive as a JSON *string*. Smaller
      // models sometimes emit malformed JSON here; an unparseable call becomes
      // an empty argument map, which `PumpIntent.tryParse` then rejects — so a
      // bad call is refused rather than guessed at.
      Map<String, dynamic> args = const {};
      final rawArgs = fn['arguments'];
      if (rawArgs is String && rawArgs.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(rawArgs);
          if (decoded is Map) args = decoded.cast<String, dynamic>();
        } catch (_) {
          // Leave args empty; validation downstream will refuse it.
        }
      } else if (rawArgs is Map) {
        // A few servers return an object instead of a string.
        args = rawArgs.cast<String, dynamic>();
      }

      toolCalls.add(AssistantToolCall(id: id, name: name, input: args));
      echoedCalls.add({
        'id': id,
        'type': 'function',
        'function': {'name': name, 'arguments': jsonEncode(args)},
      });
    }

    return AssistantReply(
      text: text,
      toolCalls: toolCalls,
      finishReason: finishReason,
      assistantMessage: {
        'role': 'assistant',
        'content': text.isEmpty ? null : text,
        if (echoedCalls.isNotEmpty) 'tool_calls': echoedCalls,
      },
    );
  }

  static String _networkMessage(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') ||
        s.contains('Failed host') ||
        s.contains('Connection refused')) {
      return AssistantConfig.isLocalEndpoint
          ? 'Could not reach the model server at ${AssistantConfig.baseUrl}. '
                'Check it is running and that this phone is on the same '
                'network.'
          : 'No internet connection, so the assistant cannot answer. Your farm '
                'readings on the other screens are unaffected.';
    }
    if (s.contains('TimeoutException')) {
      return 'The model took too long to reply. Try again, or use a smaller '
          'model.';
    }
    return 'Could not reach the assistant. Try again.';
  }

  static String _httpMessage(http.Response response) {
    String detail = '';
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] is Map) {
        detail = (body['error']['message'] as String?) ?? '';
      }
    } catch (_) {
      // Not JSON; the status code will have to carry the message.
    }

    return switch (response.statusCode) {
      401 ||
      403 => 'The model server rejected the key this build was compiled with.',
      404 =>
        'The model "${AssistantConfig.model}" was not found on this server. '
            'Provider model names change — check the current list and rebuild '
            'with --dart-define=ASSISTANT_MODEL=...',
      429 =>
        'The free tier is rate limited right now. Wait a moment and try again.',
      >= 500 => 'The model server is having trouble. Try again shortly.',
      _ =>
        'The assistant request failed (${response.statusCode}). '
            '${detail.isEmpty ? "" : detail}',
    };
  }

  void dispose() => _client.close();
}
