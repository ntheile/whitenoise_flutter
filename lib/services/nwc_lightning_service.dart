import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:whitenoise/src/rust/api/lightning.dart';

/// Provider for NWC Lightning service
final nwcLightningServiceProvider = Provider<NwcLightningService>((ref) {
  return NwcLightningService();
});

/// Service for managing Nostr Wallet Connect (NWC) operations
class NwcLightningService {
  static const String _nwcUriKey = 'nwc_connection_uri';
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  /// Save NWC connection URI securely
  Future<void> saveConnectionUri(String uri) async {
    debugPrint('💾 Attempting to save NWC URI: ${uri.length} chars');
    await _storage.write(key: _nwcUriKey, value: uri);
    debugPrint('✅ NWC URI saved successfully');
    
    // Verify it was saved
    final retrieved = await _storage.read(key: _nwcUriKey);
    debugPrint('🔍 Verification read: ${retrieved != null ? "${retrieved.length} chars" : "null"}');
  }

  /// Get saved NWC connection URI
  Future<String?> getConnectionUri() async {
    final uri = await _storage.read(key: _nwcUriKey);
    debugPrint('🔑 NWC URI retrieved: ${uri != null ? "${uri.length} chars" : "null"}');
    return uri;
  }

  /// Delete saved NWC connection URI
  Future<void> deleteConnectionUri() async {
    await _storage.delete(key: _nwcUriKey);
  }

  /// Get node information from NWC
  Future<LightningNodeInfo> getNodeInfo() async {
    final uri = await getConnectionUri();
    if (uri == null || uri.isEmpty) {
      throw Exception('No NWC connection URI found');
    }

    final config = NostrWalletConnectConfig(
      nwcUri: uri,
      socks5Proxy: null,
      acceptInvalidCerts: null,
      httpTimeout: null,
    );

    return await nwcGetInfo(config: config);
  }

  /// Create a Lightning invoice
  Future<LightningTransaction> createInvoice({
    int? amountMsats,
    String? description,
    int? expiry,
  }) async {
    final uri = await getConnectionUri();
    if (uri == null || uri.isEmpty) {
      throw Exception('No NWC connection URI found');
    }

    final config = NostrWalletConnectConfig(
      nwcUri: uri,
      socks5Proxy: null,
      acceptInvalidCerts: null,
      httpTimeout: null,
    );

    final params = CreateInvoiceParams(
      amountMsats: amountMsats,
      description: description,
      expiry: expiry,
    );

    return await nwcCreateInvoice(config: config, params: params);
  }

  /// Pay a Lightning invoice
  Future<PayInvoiceResponse> payInvoice({
    required String invoice,
    double? feeLimitPercentage,
  }) async {
    final uri = await getConnectionUri();
    if (uri == null || uri.isEmpty) {
      throw Exception('No NWC connection URI found');
    }

    final config = NostrWalletConnectConfig(
      nwcUri: uri,
      socks5Proxy: null,
      acceptInvalidCerts: null,
      httpTimeout: null,
    );

    final params = PayInvoiceParams(
      invoice: invoice,
      feeLimitPercentage: feeLimitPercentage,
    );

    return await nwcPayInvoice(config: config, params: params);
  }

  /// Lookup a Lightning invoice by payment hash
  Future<LightningTransaction> lookupInvoice(String paymentHash) async {
    final uri = await getConnectionUri();
    if (uri == null || uri.isEmpty) {
      throw Exception('No NWC connection URI found');
    }

    final config = NostrWalletConnectConfig(
      nwcUri: uri,
      socks5Proxy: null,
      acceptInvalidCerts: null,
      httpTimeout: null,
    );

    return await nwcLookupInvoice(config: config, paymentHash: paymentHash);
  }

  /// List Lightning transactions
  Future<List<LightningTransaction>> listTransactions({
    int from = 0,
    int limit = 20,
    String? search,
  }) async {
    final uri = await getConnectionUri();
    if (uri == null || uri.isEmpty) {
      throw Exception('No NWC connection URI found');
    }

    final config = NostrWalletConnectConfig(
      nwcUri: uri,
      socks5Proxy: null,
      acceptInvalidCerts: null,
      httpTimeout: null,
    );

    final params = ListTransactionsParams(
      from: from,
      limit: limit,
      search: search,
    );

    return await nwcListTransactions(config: config, params: params);
  }

  /// Convert millisatoshis to satoshis
  int msatsToSats(int msats) {
    return msats ~/ 1000;
  }

  /// Convert satoshis to millisatoshis
  int satsToMsats(int sats) {
    return sats * 1000;
  }
}
