import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:whitenoise/services/strike_lightning_service.dart';
import 'package:whitenoise/ui/core/themes/assets.dart';
import 'package:whitenoise/ui/core/themes/src/extensions.dart';
import 'package:whitenoise/ui/core/ui/info_box.dart';
import 'package:whitenoise/ui/core/ui/wn_app_bar.dart';
import 'package:whitenoise/ui/core/ui/wn_button.dart';
import 'package:whitenoise/ui/core/ui/wn_icon_button.dart';
import 'package:whitenoise/ui/core/ui/wn_text_field.dart';
import 'package:whitenoise/ui/core/ui/wn_toast.dart';
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

  @override
  void initState() {
    super.initState();
    _loadStrikeApiKey();
  }

  Future<void> _loadStrikeApiKey() async {
    final service = ref.read(strikeLightningServiceProvider);
    final apiKey = await service.getApiKey();
    if (apiKey != null && mounted) {
      setState(() {
        _strikeApiKeyController.text = apiKey;
      });
    }
  }

  Future<void> _saveStrikeApiKey() async {
    final apiKey = _strikeApiKeyController.text.trim();
    if (apiKey.isEmpty) {
      WnToast.showError(
        ref: ref,
        message: 'wallet.strike.apiKeyEmpty'.tr(),
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
        
        WnToast.showSuccess(
          ref: ref,
          message: 'wallet.strike.connected'.tr(),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStrike = false;
          _strikeNodeInfo = null;
        });
        
        WnToast.showError(
          ref: ref,
          message: 'wallet.strike.connectionFailed'.tr(),
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
        
        WnToast.showSuccess(
          ref: ref,
          message: 'wallet.strike.connectionSuccess'.tr(),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStrike = false;
          _strikeNodeInfo = null;
        });
        
        WnToast.showError(
          ref: ref,
          message: 'wallet.strike.connectionFailed'.tr(),
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
                        Gap(52.h),
                        // Strike Lightning Payment Section
                        Text(
                          'wallet.strike.title'.tr(),
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            color: context.colors.foreground,
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
                              child: WnButton(
                                onPressed: _isLoadingStrike ? null : _saveStrikeApiKey,
                                text: 'wallet.strike.connect'.tr(),
                                isLoading: _isLoadingStrike,
                              ),
                            ),
                            if (_strikeNodeInfo != null) ...[
                              Gap(8.w),
                              Expanded(
                                child: WnButton(
                                  onPressed: _isLoadingStrike ? null : _testStrikeConnection,
                                  text: 'wallet.strike.test'.tr(),
                                  variant: WnButtonVariant.secondary,
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
                              color: context.colors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(
                                color: context.colors.success,
                                width: 1,
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
