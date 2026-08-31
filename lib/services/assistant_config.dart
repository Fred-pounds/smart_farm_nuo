/// Where the assistant gets its model, endpoint and (optional) credentials.
///
/// The app speaks the **OpenAI-compatible chat-completions** shape, which is
/// the de-facto standard for open-weights model servers. One client therefore
/// covers every free option worth using, and switching between them is a build
/// flag rather than a rewrite:
///
/// | Backend | Cost | Notes |
/// |---|---|---|
/// | **Groq** (default) | Free tier | Hosted, very fast, no card. Good tool calling. |
/// | **OpenRouter** | Free tier | Aggregator; models suffixed `:free`. |
/// | **Ollama** | Free, local | Runs on your own machine. No key, no quota, works offline. |
/// | Together / vLLM / llama.cpp / LM Studio | Varies | Any OpenAI-compatible server. |
///
/// The model must support **tool calling** — the assistant asks for pump
/// changes through a function call, and a model that cannot emit one simply
/// won't be able to control anything (it will still answer questions).
///
/// ```bash
/// # Groq free tier (default endpoint, just add a key)
/// flutter build apk --release --dart-define=ASSISTANT_API_KEY=gsk_...
///
/// # Ollama on your laptop, phone on the same Wi-Fi — no key at all
/// flutter build apk --release \
///   --dart-define=ASSISTANT_BASE_URL=http://192.168.1.20:11434/v1 \
///   --dart-define=ASSISTANT_MODEL=qwen2.5:14b
///
/// # OpenRouter free tier
/// flutter build apk --release \
///   --dart-define=ASSISTANT_BASE_URL=https://openrouter.ai/api/v1 \
///   --dart-define=ASSISTANT_MODEL=meta-llama/llama-3.3-70b-instruct:free \
///   --dart-define=ASSISTANT_API_KEY=sk-or-...
/// ```
class AssistantConfig {
  const AssistantConfig._();

  /// OpenAI-compatible base URL, including the `/v1`.
  ///
  /// Defaults to Groq's free endpoint. Ollama is `http://<host>:11434/v1`.
  static const String baseUrl = String.fromEnvironment(
    'ASSISTANT_BASE_URL',
    defaultValue: 'https://api.groq.com/openai/v1',
  );

  /// The open-weights model to use.
  ///
  /// Provider model IDs drift — they get renamed and retired regularly — so
  /// this is a build flag rather than a constant to edit in code. If a request
  /// comes back "model not found", check the provider's current list and pass
  /// `--dart-define=ASSISTANT_MODEL=...`.
  static const String model = String.fromEnvironment(
    'ASSISTANT_MODEL',
    defaultValue: 'llama-3.3-70b-versatile',
  );

  /// Bearer token. Empty is correct and expected for a local Ollama server.
  static const String apiKey = String.fromEnvironment('ASSISTANT_API_KEY');

  /// Caps the reply. Farm answers are short; this leaves room for a tool call
  /// plus a sentence or two.
  static const int maxTokens = 1024;

  /// Low, because the assistant reasons over a context the app has already
  /// assembled rather than exploring. Also keeps smaller models from
  /// embroidering — the failure mode that matters here.
  static const double temperature = 0.2;

  /// A local server needs no key; a hosted one does.
  static bool get isConfigured => apiKey.isNotEmpty || isLocalEndpoint;

  /// True when pointed at a machine on the local network or this device —
  /// the only arrangement with no secret in the APK at all.
  static bool get isLocalEndpoint =>
      baseUrl.contains('localhost') ||
      baseUrl.contains('127.0.0.1') ||
      baseUrl.contains('10.0.2.2') ||
      RegExp(
        r'//192\.168\.|//10\.|//172\.(1[6-9]|2\d|3[01])\.',
      ).hasMatch(baseUrl);

  /// True when this build carries an extractable key.
  static bool get usesEmbeddedKey => apiKey.isNotEmpty;

  /// Shown in Settings so the farmer (and you) can see what is actually
  /// answering, rather than guessing from behaviour.
  static String get description {
    if (!isConfigured) return 'Not set up';
    final host = Uri.tryParse(baseUrl)?.host ?? baseUrl;
    return '$model via $host';
  }
}
