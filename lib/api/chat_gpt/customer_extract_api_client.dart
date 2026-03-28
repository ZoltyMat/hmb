import '../../ai/ai_provider.dart';
import '../../ai/ai_provider_factory.dart';
import '../../util/dart/parse/parse_address.dart';
import '../../util/dart/parse/parse_customer.dart';

class CustomerExtractApiClient {
  /// Accepts an optional [AIProvider] for testing; otherwise uses the factory.
  CustomerExtractApiClient({AIProvider? provider}) : _injected = provider;

  final AIProvider? _injected;

  Future<ParsedCustomer?> extract(String text) async {
    final provider = _injected ?? await AIProviderFactory.create();
    if (provider == null) {
      return null;
    }

    const systemPrompt =
        'Extract customer details from the message. Return JSON only '
        'with keys: customerName, companyName, firstName, surname, '
        'email, mobile, '
        'addressLine1, addressLine2, suburb, state, postcode. '
        'If a company is clearly associated with the customer, set '
        'companyName and prefer customerName to be the company name. '
        'Use empty strings for unknown fields.';

    final parsed = await provider.extractStructured(
      text,
      systemPrompt: systemPrompt,
      temperature: 0.1,
    );

    final firstName = (parsed['firstName'] as String?)?.trim() ?? '';
    final surname = (parsed['surname'] as String?)?.trim() ?? '';
    final companyName = (parsed['companyName'] as String?)?.trim() ?? '';
    final customerNameRaw =
        (parsed['customerName'] as String?)?.trim() ?? '';
    final personName = [
      firstName,
      surname,
    ].where((p) => p.isNotEmpty).join(' ');
    final customerName = companyName.isNotEmpty
        ? companyName
        : (customerNameRaw.isNotEmpty ? customerNameRaw : personName);

    final address = ParsedAddress(
      street: (parsed['addressLine1'] as String?)?.trim() ?? '',
      city: (parsed['suburb'] as String?)?.trim() ?? '',
      state: (parsed['state'] as String?)?.trim() ?? '',
      postalCode: (parsed['postcode'] as String?)?.trim() ?? '',
    );

    return ParsedCustomer(
      customerName: customerName,
      companyName: companyName,
      email: (parsed['email'] as String?)?.trim() ?? '',
      mobile: (parsed['mobile'] as String?)?.trim() ?? '',
      firstname: firstName,
      surname: surname,
      address: address,
    );
  }
}
