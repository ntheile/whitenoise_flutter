import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:whitenoise/config/providers/toast_message_provider.dart';
import 'package:whitenoise/services/strike_lightning_service.dart';
import 'package:whitenoise/services/nwc_lightning_service.dart';
import 'package:whitenoise/ui/core/themes/assets.dart';
import 'package:whitenoise/ui/core/themes/src/extensions.dart';
import 'package:whitenoise/ui/core/ui/info_box.dart';
import 'package:whitenoise/ui/core/ui/wn_app_bar.dart';
import 'package:whitenoise/ui/core/ui/wn_button.dart';
import 'package:whitenoise/ui/core/ui/wn_icon_button.dart';
import 'package:whitenoise/ui/core/ui/wn_text_field.dart';
import 'package:whitenoise/utils/clipboard_utils.dart';
import 'package:whitenoise/utils/localization_extensions.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final TextEditingController _connectionSecretController = TextEditingController();
  final TextEditingController _strikeApiKeyController = TextEditingController();
  bool _isLoadingStrike = false;
  String? _strikeNodeInfo;
  bool _isLoadingNwc = false;
  String? _nwcNodeInfo;

  @override
  void initState() {
    super.initState();
    // Load saved credentials after the frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStrikeApiKey();
      _loadNwcUri();
    });
  }

  Future<void> _loadStrikeApiKey() async {
    final service = ref.read(strikeLightningServiceProvider);
    final apiKey = await service.getApiKey();
    debugPrint('📝 Loading Strike API key: ${apiKey != null ? "Found (${apiKey.length} chars)" : "Not found"}');
    if (apiKey != null && mounted) {
      setState(() {
        _strikeApiKeyController.text = apiKey;
      });
      debugPrint('✅ Strike API key loaded into text field');
      // Automatically test connection to load balance
      await _testStrikeConnection();
    }
  }

  Future<void> _loadNwcUri() async {
    final service = ref.read(nwcLightningServiceProvider);
    final uri = await service.getConnectionUri();
    debugPrint('📝 Loading NWC URI: ${uri != null ? "Found (${uri.length} chars)" : "Not found"}');
    if (uri != null && mounted) {
      setState(() {
        _connectionSecretController.text = uri;
      });
      debugPrint('✅ NWC URI loaded into text field');
      // Auto-test connection if URI exists
      _testNwcConnection();
    }
  }

  Future<void> _saveNwcUri() async {
    final uri = _connectionSecretController.text.trim();
    if (uri.isEmpty) {
      ref.read(toastMessageProvider.notifier).showError(
        'Please enter NWC connection string',
      );
      return;
    }

    if (!uri.startsWith('nostr+walletconnect://')) {
      ref.read(toastMessageProvider.notifier).showError(
        'Invalid NWC URI. Must start with nostr+walletconnect://',
      );
      return;
    }

    setState(() => _isLoadingNwc = true);

    try {
      final service = ref.read(nwcLightningServiceProvider);
      await service.saveConnectionUri(uri);

      // Test the connection
      final nodeInfo = await service.getNodeInfo();

      if (mounted) {
        setState(() {
          _nwcNodeInfo = 'Balance: ${nodeInfo.sendBalanceMsats ~/ 1000} sats';
          _isLoadingNwc = false;
        });

        ref.read(toastMessageProvider.notifier).showSuccess(
          'NWC connected successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingNwc = false;
          _nwcNodeInfo = null;
        });

        ref.read(toastMessageProvider.notifier).showError(
          'Failed to connect: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _testNwcConnection() async {
    setState(() => _isLoadingNwc = true);

    try {
      final service = ref.read(nwcLightningServiceProvider);
      final nodeInfo = await service.getNodeInfo();

      if (mounted) {
        setState(() {
          _nwcNodeInfo = 'Balance: ${nodeInfo.sendBalanceMsats ~/ 1000} sats';
          _isLoadingNwc = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingNwc = false;
          _nwcNodeInfo = null;
        });
      }
    }
  }

  Future<void> _saveStrikeApiKey() async {
    final apiKey = _strikeApiKeyController.text.trim();
    if (apiKey.isEmpty) {
      ref.read(toastMessageProvider.notifier).showError(
        'wallet.strike.apiKeyEmpty'.tr(),
      );
      return;
    }

    setState(() => _isLoadingStrike = true);

    try {
      final service = ref.read(strikeLightningServiceProvider);
      await service.saveApiKey(apiKey);

      // Test the connection
      final nodeInfo = await service.getNodeInfo();

      if (mounted) {
        setState(() {
          _strikeNodeInfo = 'Balance: ${nodeInfo.sendBalanceMsats ~/ 1000} sats';
          _isLoadingStrike = false;
        });

        ref.read(toastMessageProvider.notifier).showSuccess(
          'wallet.strike.connected'.tr(),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStrike = false;
          _strikeNodeInfo = null;
        });

        ref.read(toastMessageProvider.notifier).showError(
          'wallet.strike.connectionFailed'.tr(),
        );
      }
    }
  }

  Future<void> _testStrikeConnection() async {
    setState(() => _isLoadingStrike = true);

    try {
      final service = ref.read(strikeLightningServiceProvider);
      final nodeInfo = await service.getNodeInfo();

      if (mounted) {
        setState(() {
          _strikeNodeInfo = 'Balance: ${nodeInfo.sendBalanceMsats ~/ 1000} sats';
          _isLoadingStrike = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStrike = false;
          _strikeNodeInfo = null;
        });
      }
    }
  }

  Future<void> _deleteStrikeApiKey() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Strike API Key'),
        content: const Text('Are you sure you want to remove your Strike API key?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final service = ref.read(strikeLightningServiceProvider);
      await service.deleteApiKey();

      if (mounted) {
        setState(() {
          _strikeApiKeyController.clear();
          _strikeNodeInfo = null;
        });

        ref.read(toastMessageProvider.notifier).showSuccess(
          'Strike API key removed',
        );
      }
    } catch (e) {
      if (mounted) {
        ref.read(toastMessageProvider.notifier).showError(
          'Failed to remove Strike API key',
        );
      }
    }
  }

  Future<void> _deleteNwcUri() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove NWC Connection'),
        content: const Text('Are you sure you want to remove your NWC connection?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final service = ref.read(nwcLightningServiceProvider);
      await service.deleteConnectionUri();

      if (mounted) {
        setState(() {
          _connectionSecretController.clear();
          _nwcNodeInfo = null;
        });

        ref.read(toastMessageProvider.notifier).showSuccess(
          'NWC connection removed',
        );
      }
    } catch (e) {
      if (mounted) {
        ref.read(toastMessageProvider.notifier).showError(
          'Failed to remove NWC connection',
        );
      }
    }
  }

  @override
  void dispose() {
    _connectionSecretController.dispose();
    _strikeApiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.neutral,
      appBar: WnAppBar(title: Text('ui.wallet'.tr())),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Gap(24.h),
                        Text(
                          'wallet.connectionDescription'.tr(),
                          style: TextStyle(
                            fontSize: 18.sp,
                            color: context.colors.secondaryForeground,
                          ),
                        ),
                        Gap(24.h),
                        Text(
                          'wallet.connectionString'.tr(),
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: context.colors.secondaryForeground,
                          ),
                        ),
                        Gap(8.h),
                        Row(
                          children: [
                            Expanded(
                              child: WnTextField(
                                textController: _connectionSecretController,
                                hintText: 'nostr+walletconnect://...',
                                padding: EdgeInsets.zero,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                ),
                              ),
                            ),
                            Gap(8.w),
                            WnIconButton(
                              iconPath: AssetsPaths.icCopy,
                              onTap: () {
                                ClipboardUtils.copyWithToast(
                                  ref: ref,
                                  textToCopy: _connectionSecretController.text,
                                  successMessage: 'wallet.connectionStringCopied'.tr(),
                                );
                              },
                            ),
                            Gap(8.w),
                            WnIconButton(
                              iconPath: AssetsPaths.icScan,
                              onTap: () {
                                // QR code scanner functionality
                              },
                            ),
                          ],
                        ),
                        Gap(16.h),
                        Row(
                          children: [
                            Expanded(
                              child: WnFilledButton(
                                onPressed: _isLoadingNwc ? null : _saveNwcUri,
                                label: 'Connect',
                                loading: _isLoadingNwc,
                              ),
                            ),
                            if (_nwcNodeInfo != null) ...[
                              Gap(8.w),
                              Expanded(
                                child: WnFilledButton(
                                  onPressed: _isLoadingNwc ? null : _testNwcConnection,
                                  label: 'Test',
                                  visualState: WnButtonVisualState.secondary,
                                ),
                              ),
                              Gap(8.w),
                              Expanded(
                                child: WnFilledButton(
                                  onPressed: _isLoadingNwc ? null : _deleteNwcUri,
                                  label: 'Remove',
                                  visualState: WnButtonVisualState.destructive,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (_nwcNodeInfo != null) ...[
                          Gap(12.h),
                          Container(
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(
                              color: context.colors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(
                                color: context.colors.success,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: context.colors.success,
                                  size: 20.sp,
                                ),
                                Gap(8.w),
                                Expanded(
                                  child: Text(
                                    _nwcNodeInfo!,
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: context.colors.success,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        Gap(52.h),
                        // Strike Lightning Payment Section
                        Text(
                          'wallet.strike.title'.tr(),
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            color: context.colors.primaryForeground,
                          ),
                        ),
                        Gap(16.h),
                        Text(
                          'wallet.strike.description'.tr(),
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: context.colors.secondaryForeground,
                          ),
                        ),
                        Gap(16.h),
                        Text(
                          'wallet.strike.apiKey'.tr(),
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: context.colors.secondaryForeground,
                          ),
                        ),
                        Gap(8.h),
                        WnTextField(
                          textController: _strikeApiKeyController,
                          hintText: 'sk_...',
                          padding: EdgeInsets.zero,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                          ),
                          obscureText: true,
                        ),
                        Gap(16.h),
                        Row(
                          children: [
                            Expanded(
                              child: WnFilledButton(
                                onPressed: _isLoadingStrike ? null : _saveStrikeApiKey,
                                label: 'wallet.strike.connect'.tr(),
                                loading: _isLoadingStrike,
                              ),
                            ),
                            if (_strikeNodeInfo != null) ...[
                              Gap(8.w),
                              Expanded(
                                child: WnFilledButton(
                                  onPressed: _isLoadingStrike ? null : _testStrikeConnection,
                                  label: 'wallet.strike.test'.tr(),
                                  visualState: WnButtonVisualState.secondary,
                                ),
                              ),
                              Gap(8.w),
                              Expanded(
                                child: WnFilledButton(
                                  onPressed: _isLoadingStrike ? null : _deleteStrikeApiKey,
                                  label: 'Remove',
                                  visualState: WnButtonVisualState.destructive,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (_strikeNodeInfo != null) ...[
                          Gap(12.h),
                          Container(
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(
                              color: context.colors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(
                                color: context.colors.success,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: context.colors.success,
                                  size: 20.sp,
                                ),
                                Gap(8.w),
                                Expanded(
                                  child: Text(
                                    _strikeNodeInfo!,
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: context.colors.success,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        Gap(52.h),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: InfoBox(
                      colorTheme: context.colors.secondaryForeground,
                      title: 'wallet.informationQuestion'.tr(),
                      description: 'wallet.informationAnswer'.tr(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
