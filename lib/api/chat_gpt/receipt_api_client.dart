/*
 Copyright (c) OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
 with the following exceptions:
   * Permitted for internal use within your own business or organization only.
   * Any external distribution, resale, or incorporation into products for
    third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// lib/src/api/receipt_api_client.dart
import 'dart:convert';
import 'dart:io';

import '../../ai/ai_provider.dart';
import '../../ai/ai_provider_factory.dart';
import '../../ai/providers/openai_provider.dart';

class ReceiptApiClient {
  /// Accepts an optional [AIProvider] for testing; otherwise uses the factory.
  ReceiptApiClient({AIProvider? provider}) : _injected = provider;

  final AIProvider? _injected;

  static const _systemPrompt =
      'Extract the following fields from the base64-encoded receipt image: '
      'receipt_date (YYYY-MM-DD), job/order number (if present), supplier '
      '(if present), total_excluding_tax (in cents), tax (in cents), '
      'total_including_tax (in cents). Respond with a JSON object only.';

  /// Uploads a receipt image and extracts data via the configured AI provider.
  Future<Map<String, dynamic>> extractData(String filePath) async {
    final provider = _injected ?? await AIProviderFactory.create();
    if (provider == null) {
      throw Exception(
        'No AI provider configured. Add an API key in Settings.',
      );
    }

    final bytes = await File(filePath).readAsBytes();

    final rawResponse = await provider.analyzeImage(
      bytes,
      _systemPrompt,
      systemPrompt: _systemPrompt,
    );

    final normalized = OpenAIProvider.normalizeContent(rawResponse);
    return jsonDecode(normalized) as Map<String, dynamic>;
  }
}
