import 'dart:async';
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

class LightningPaymentWidget extends ConsumerStatefulWidget {
  final String invoice;
  final int amountSats;
  final String? description;
  final bool isMe;
  final String? paymentHash;

  const LightningPaymentWidget({
    super.key,
    required this.invoice,
    required this.amountSats,
    this.description,
    required this.isMe,
    this.paymentHash,
  });

  @override
  ConsumerState<LightningPaymentWidget> createState() =>
      _LightningPaymentWidgetState();
}

class _LightningPaymentWidgetState
    extends ConsumerState<LightningPaymentWidget> {
  bool _isLoading = false;
  bool _isCheckingStatus = false;
  bool _isPaid = false;
  Timer? _pollTimer;
  int _pollAttempts = 0;
  static const int _maxPollAttempts = 60; // 5 minutes (60 * 5 seconds)

  @override
  void initState() {
    super.initState();
    // Start polling if this is our payment request
    if (widget.isMe && widget.paymentHash != null) {
      _startPolling();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      _pollAttempts++;

      if (_pollAttempts > _maxPollAttempts) {
        timer.cancel();
        return;
      }

      await _checkInvoiceStatus();
    });
  }

  Future<void> _checkInvoiceStatus() async {
    if (_isPaid || widget.paymentHash == null) return;

    try {
      // Try NWC first, fallback to Strike
      final nwcService = ref.read(nwcLightningServiceProvider);
      final strikeService = ref.read(strikeLightningServiceProvider);

      final nwcUri = await nwcService.getConnectionUri();
      final strikeKey = await strikeService.getApiKey();

      if (nwcUri != null && nwcUri.isNotEmpty) {
        final transaction = await nwcService.lookupInvoice(widget.paymentHash!);
        // Check if invoice is settled (settledAt > 0)
        if (transaction.settledAt > 0) {
          _markAsPaid();
        }
      } else if (strikeKey != null && strikeKey.isNotEmpty) {
        final transaction = await strikeService.lookupInvoice(widget.paymentHash!);
        // Check if invoice is settled (settledAt > 0)
        if (transaction.settledAt > 0) {
          _markAsPaid();
        }
      }
    } catch (e) {
      // Silently fail - invoice might not be found yet
      // Only log in debug mode
      debugPrint('Error checking invoice status: $e');
    }
  }

  void _markAsPaid() {
    if (mounted && !_isPaid) {
      setState(() => _isPaid = true);
      _pollTimer?.cancel();
      
      // Show celebratory success notification
      ref.read(toastMessageProvider.notifier).showSuccess(
        '⚡ Payment Received! ${widget.amountSats} sats ⚡',
      );
      
      // Optional: Play haptic feedback if available
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _payInvoice() async {
    setState(() => _isLoading = true);

    try {
      // Try NWC first, fallback to Strike
      final nwcService = ref.read(nwcLightningServiceProvider);
      final strikeService = ref.read(strikeLightningServiceProvider);

      final nwcUri = await nwcService.getConnectionUri();
      final strikeKey = await strikeService.getApiKey();

      if (nwcUri != null && nwcUri.isNotEmpty) {
        await nwcService.payInvoice(
          invoice: widget.invoice,
          feeLimitPercentage: 1.0, // 1% fee limit
        );
      } else if (strikeKey != null && strikeKey.isNotEmpty) {
        await strikeService.payInvoice(
          invoice: widget.invoice,
          feeLimitPercentage: 1.0,
        );
      } else {
        throw Exception('No Lightning wallet configured');
      }

      if (mounted) {
        setState(() => _isPaid = true);
        ref.read(toastMessageProvider.notifier).showSuccess(
          'Payment sent successfully!',
        );
      }
    } catch (e) {
      if (mounted) {
        ref.read(toastMessageProvider.notifier).showError(
          'Payment failed: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _copyInvoice() {
    Clipboard.setData(ClipboardData(text: widget.invoice));
    ref.read(toastMessageProvider.notifier).showSuccess(
      'Invoice copied to clipboard',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFD700).withValues(alpha: 0.1),
            const Color(0xFFFFA500).withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bolt,
                color: const Color(0xFFFFD700),
                size: 20.sp,
              ),
              Gap(8.w),
              Expanded(
                child: Text(
                  widget.isMe ? 'Payment Request' : 'Payment Request',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: context.colors.primaryForeground,
                  ),
                ),
              ),
              // Refresh button for sender to manually check payment status
              if (widget.isMe && !_isPaid && widget.paymentHash != null)
                GestureDetector(
                  onTap: () async {
                    setState(() => _isCheckingStatus = true);
                    await _checkInvoiceStatus();
                    setState(() => _isCheckingStatus = false);
                  },
                  child: Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(
                      color: context.colors.secondaryForeground.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: _isCheckingStatus
                        ? SizedBox(
                            width: 14.sp,
                            height: 14.sp,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                const Color(0xFFFFD700),
                              ),
                            ),
                          )
                        : Icon(
                            Icons.refresh,
                            size: 16.sp,
                            color: const Color(0xFFFFD700),
                          ),
                  ),
                ),
              if (widget.isMe && !_isPaid && widget.paymentHash != null)
                Gap(8.w),
              if (_isPaid)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        context.colors.success,
                        context.colors.success.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8.r),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.success.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14.sp,
                        color: Colors.white,
                      ),
                      Gap(4.w),
                      Text(
                        'PAID',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          Gap(12.h),
          Row(
            children: [
              Text(
                '${widget.amountSats}',
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFFD700),
                ),
              ),
              Gap(4.w),
              Text(
                'sats',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: context.colors.secondaryForeground,
                ),
              ),
            ],
          ),
          if (widget.description != null && widget.description!.isNotEmpty) ...[
            Gap(8.h),
            Text(
              widget.description!,
              style: TextStyle(
                fontSize: 13.sp,
                color: context.colors.secondaryForeground,
              ),
            ),
          ],
          Gap(12.h),
          if (!widget.isMe && !_isPaid)
            Row(
              children: [
                Expanded(
                  child: WnFilledButton(
                    onPressed: _isLoading ? null : _payInvoice,
                    label: 'Pay',
                    loading: _isLoading,
                    size: WnButtonSize.small,
                  ),
                ),
                Gap(8.w),
                Expanded(
                  child: WnFilledButton(
                    onPressed: _copyInvoice,
                    label: 'Copy Invoice',
                    visualState: WnButtonVisualState.secondary,
                    size: WnButtonSize.small,
                  ),
                ),
              ],
            ),
          if (widget.isMe || _isPaid)
            WnFilledButton(
              onPressed: _copyInvoice,
              label: 'Copy Invoice',
              visualState: WnButtonVisualState.secondary,
              size: WnButtonSize.small,
            ),
        ],
      ),
    );
  }
}
