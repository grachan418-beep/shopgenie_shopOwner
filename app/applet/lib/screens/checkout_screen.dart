import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../services/cart_service.dart';
import '../services/checkout_service.dart';
import '../theme/app_theme.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isProcessing = false;
  String _paymentMode = 'CASH'; // 'CASH' or 'UPI'
  String? _statusMessage;
  String? _errorMessage;

  Future<void> _processCheckout() async {
    final cart = CartService();
    final items = List<CartItem>.from(cart.items);

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty.')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _statusMessage = 'Submitting order to backend billing engine...';
    });

    final result = await CheckoutService().checkoutCart(
      items,
      onProgress: (current, total) {
        setState(() {
          _statusMessage = 'Billing item $current of $total...';
        });
      },
    );

    if (!mounted) return;

    if (result.success && result.invoice != null) {
      // Clear cart on successful atomic checkout
      cart.clear();
      // Replace with invoice screen
      Navigator.pushReplacementNamed(
        context,
        '/invoice',
        arguments: result.invoice,
      );
    } else {
      setState(() {
        _isProcessing = false;
        _errorMessage = result.errorMessage ?? 'Checkout failed. Please check stock levels and retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartService();
    final items = cart.items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Checkout'),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppTheme.borderLight)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isProcessing) ...[
                const LinearProgressIndicator(color: AppTheme.primaryGreen),
                const SizedBox(height: 12),
                Text(
                  _statusMessage ?? 'Processing checkout...',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
              ],
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _processCheckout,
                icon: const Icon(Icons.check_circle_outline),
                label: Text('Confirm & Create Invoice • ₹${cart.totalAmount.toStringAsFixed(2)}'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.dangerRed.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.dangerRed.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.dangerRed, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Billing Conflict',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.dangerRed),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: AppTheme.dangerRed, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Payment Mode Selection
            const Text(
              'Payment Mode',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _paymentMode = 'CASH'),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _paymentMode == 'CASH' ? AppTheme.primaryGreen.withOpacity(0.1) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _paymentMode == 'CASH' ? AppTheme.primaryGreen : AppTheme.borderLight,
                          width: _paymentMode == 'CASH' ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.payments_outlined,
                            color: _paymentMode == 'CASH' ? AppTheme.primaryGreen : AppTheme.textMuted,
                          ),
                          const SizedBox(width: 10),
                          const Text('Cash in Hand', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _paymentMode = 'UPI'),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _paymentMode == 'UPI' ? AppTheme.accentAmber.withOpacity(0.1) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _paymentMode == 'UPI' ? AppTheme.accentAmber : AppTheme.borderLight,
                          width: _paymentMode == 'UPI' ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.qr_code_2_outlined,
                            color: _paymentMode == 'UPI' ? AppTheme.accentAmber : AppTheme.textMuted,
                          ),
                          const SizedBox(width: 10),
                          const Text('UPI / QR Scan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Order Breakdown Card
            const Text(
              'Order Summary',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Column(
                children: [
                  ...items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                Text(
                                  '${item.formattedQuantity} @ ₹${item.unitPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₹${item.subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 24, color: AppTheme.borderLight),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Payable',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                      ),
                      Text(
                        '₹${cart.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Backend Notice Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FBF8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline, size: 20, color: AppTheme.primaryGreen),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Stock deduction and invoice generation are processed atomically by the backend Django engine.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
