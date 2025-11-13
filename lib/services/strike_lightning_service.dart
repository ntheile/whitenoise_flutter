import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';
import 'package:whitenoise/src/rust/api/lightning.dart';

/// Service for managing Strike Lightning payments
class StrikeLightningService {
  StrikeLightningService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secureStorage;
  final _logger = Logger('StrikeLightningService');
  static const String _apiKeyStorageKey = 'strike_api_key';

  /// Save Strike API key securely
  Future<void> saveApiKey(String apiKey) async {
    try {
      await _secureStorage.write(key: _apiKeyStorageKey, value: apiKey);
      _logger.info('Strike API key saved');
    } catch (e, st) {
      _logger.severe('Failed to save Strike API key', e, st);
      rethrow;
    }
  }

  /// Get stored Strike API key
  Future<String?> getApiKey() async {
    try {
      return await _secureStorage.read(key: _apiKeyStorageKey);
    } catch (e, st) {
      _logger.severe('Failed to read Strike API key', e, st);
      return null;
    }
  }

  /// Delete stored Strike API key
  Future<void> deleteApiKey() async {
    try {
      await _secureStorage.delete(key: _apiKeyStorageKey);
      _logger.info('Strike API key deleted');
    } catch (e, st) {
      _logger.severe('Failed to delete Strike API key', e, st);
      rethrow;
    }
  }

  /// Check if API key is configured
  Future<bool> hasApiKey() async {
    final apiKey = await getApiKey();
    return apiKey != null && apiKey.isNotEmpty;
  }

  /// Create Strike configuration
  Future<StrikeLightningConfig?> getConfig() async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }

    return StrikeLightningConfig(
      apiKey: apiKey,
      baseUrl: 'https://api.strike.me/v1',
      socks5Proxy: null,
      acceptInvalidCerts: false,
      httpTimeout: 60,
    );
  }

  /// Get Strike node information and balance
  Future<LightningNodeInfo> getNodeInfo() async {
    final config = await getConfig();
    if (config == null) {
      throw Exception('Strike API key not configured');
    }

    try {
      return await strikeGetInfo(config: config);
    } catch (e, st) {
      _logger.severe('Failed to get Strike node info', e, st);
      rethrow;
    }
  }

  /// Create a Lightning invoice
  Future<LightningTransaction> createInvoice({
    required int amountSats,
    String? description,
    int? expirySeconds,
  }) async {
    final config = await getConfig();
    if (config == null) {
      throw Exception('Strike API key not configured');
    }

    try {
      final params = CreateInvoiceParams(
        amountMsats: amountSats * 1000,
        description: description,
        expiry: expirySeconds,
      );

      return await strikeCreateInvoice(config: config, params: params);
    } catch (e, st) {
      _logger.severe('Failed to create Strike invoice', e, st);
      rethrow;
    }
  }

  /// Pay a Lightning invoice
  Future<PayInvoiceResponse> payInvoice({
    required String invoice,
    double? feeLimitPercentage,
  }) async {
    final config = await getConfig();
    if (config == null) {
      throw Exception('Strike API key not configured');
    }

    try {
      final params = PayInvoiceParams(
        invoice: invoice,
        feeLimitPercentage: feeLimitPercentage ?? 1.0,
      );

      return await strikePayInvoice(config: config, params: params);
    } catch (e, st) {
      _logger.severe('Failed to pay Strike invoice', e, st);
      rethrow;
    }
  }

  /// Lookup a Lightning invoice by payment hash
  Future<LightningTransaction> lookupInvoice(String paymentHash) async {
    final config = await getConfig();
    if (config == null) {
      throw Exception('Strike API key not configured');
    }

    try {
      return await strikeLookupInvoice(
        config: config,
        paymentHash: paymentHash,
      );
    } catch (e, st) {
      _logger.severe('Failed to lookup Strike invoice', e, st);
      rethrow;
    }
  }

  /// List Lightning transactions
  Future<List<LightningTransaction>> listTransactions({
    int from = 0,
    int limit = 20,
    String? search,
  }) async {
    final config = await getConfig();
    if (config == null) {
      throw Exception('Strike API key not configured');
    }

    try {
      final params = ListTransactionsParams(
        from: from,
        limit: limit,
        search: search,
      );

      return await strikeListTransactions(config: config, params: params);
    } catch (e, st) {
      _logger.severe('Failed to list Strike transactions', e, st);
      rethrow;
    }
  }
}

/// Provider for Strike Lightning service
final strikeLightningServiceProvider = Provider<StrikeLightningService>((ref) {
  return StrikeLightningService();
});
