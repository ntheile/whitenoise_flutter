import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:whitenoise/config/providers/toast_message_provider.dart';
import 'package:whitenoise/services/nwc_lightning_service.dart';
import 'package:whitenoise/services/strike_lightning_service.dart';
import 'package:whitenoise/ui/core/themes/src/extensions.dart';
import 'package:whitenoise/ui/core/ui/wn_button.dart';
import 'package:whitenoise/ui/core/ui/wn_text_form_field.dart';

class LightningPaymentRequestDialog extends ConsumerStatefulWidget {
  final Function(String invoice, int amountSats, String? description, String paymentHash) onRequestCreated;

  const LightningPaymentRequestDialog({
    super.key,
    required this.onRequestCreated,
  });

  @override
  ConsumerState<LightningPaymentRequestDialog> createState() =>
      _LightningPaymentRequestDialogState();
}

class _LightningPaymentRequestDialogState
    extends ConsumerState<LightningPaymentRequestDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isLoading = false;
  String _walletType = 'nwc'; // 'nwc' or 'strike'

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createInvoice() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ref.read(toastMessageProvider.notifier).showError('Please enter amount');
      return;
    }

    final amountSats = int.tryParse(amountText);
    if (amountSats == null || amountSats <= 0) {
      ref.read(toastMessageProvider.notifier).showError('Please enter valid amount');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String invoice;
      String paymentHash;
      
      if (_walletType == 'nwc') {
        final nwcService = ref.read(nwcLightningServiceProvider);
        final transaction = await nwcService.createInvoice(
          amountMsats: amountSats * 1000,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          expiry: 3600, // 1 hour
        );
        invoice = transaction.invoice;
        paymentHash = transaction.paymentHash;
      } else {
        final strikeService = ref.read(strikeLightningServiceProvider);
        final transaction = await strikeService.createInvoice(
          amountSats: amountSats,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          expirySeconds: 3600,
        );
        invoice = transaction.invoice;
        paymentHash = transaction.paymentHash;
      }

      if (mounted) {
        widget.onRequestCreated(
          invoice,
          amountSats,
          _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          paymentHash,
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ref.read(toastMessageProvider.notifier).showError(
          'Failed to create invoice: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkWalletAvailability() async {
    final nwcService = ref.read(nwcLightningServiceProvider);
    final strikeService = ref.read(strikeLightningServiceProvider);

    final nwcUri = await nwcService.getConnectionUri();
    final strikeKey = await strikeService.getApiKey();

    if (nwcUri != null && nwcUri.isNotEmpty) {
      setState(() => _walletType = 'nwc');
    } else if (strikeKey != null && strikeKey.isNotEmpty) {
      setState(() => _walletType = 'strike');
    } else {
      if (mounted) {
        ref.read(toastMessageProvider.notifier).showError(
          'Please configure a Lightning wallet in Settings > Wallet',
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkWalletAvailability();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.colors.neutral,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bolt,
                  color: const Color(0xFFFFD700),
                  size: 24.sp,
                ),
                Gap(8.w),
                Text(
                  'Request Payment',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: context.colors.primaryForeground,
                  ),
                ),
              ],
            ),
            Gap(24.h),
            Text(
              'Amount (sats)',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: context.colors.secondaryForeground,
              ),
            ),
            Gap(8.h),
            WnTextFormField(
              controller: _amountController,
              hintText: '1000',
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
            ),
            Gap(16.h),
            Text(
              'Description (optional)',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: context.colors.secondaryForeground,
              ),
            ),
            Gap(8.h),
            WnTextFormField(
              controller: _descriptionController,
              hintText: 'Coffee payment',
              maxLines: 2,
            ),
            Gap(24.h),
            Row(
              children: [
                Expanded(
                  child: WnFilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    label: 'Cancel',
                    visualState: WnButtonVisualState.secondary,
                  ),
                ),
                Gap(12.w),
                Expanded(
                  child: WnFilledButton(
                    onPressed: _isLoading ? null : _createInvoice,
                    label: 'Create Request',
                    loading: _isLoading,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
