/// Abstract interface for AI provider integrations.
///
/// Each provider (OpenAI, OpenRouter, etc.) implements this interface
/// to provide a consistent API for text completion, structured extraction,
/// and image analysis throughout the app.
abstract class AiProvider {
  /// Human-readable name of the provider (e.g. "OpenRouter", "OpenAI").
  String get name;

  /// Whether the provider is configured with valid credentials.
  Future<bool> get isAvailable;

  /// Generate a text completion from the given [systemPrompt] and [userPrompt].
  ///
  /// Returns the assistant's response text, or `null` if the provider
  /// is unavailable or the request fails.
  Future<String?> complete({
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.2,
  });

  /// Extract structured JSON from [userPrompt] using the given [systemPrompt].
  ///
  /// The provider should request JSON output format. Returns the parsed
  /// JSON map, or `null` if unavailable.
  Future<Map<String, dynamic>?> extractJson({
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.1,
  });

  /// Analyze a base64-encoded image with an optional [prompt].
  ///
  /// Returns the assistant's analysis text, or `null` if unavailable.
  Future<String?> analyzeImage({
    required String base64Image,
    required String mimeType,
    String prompt = 'Describe this image.',
    double temperature = 0.2,
  });
}
