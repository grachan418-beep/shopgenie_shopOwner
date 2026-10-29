import 'package:flutter/material.dart';

import '../models/cart_item.dart';
import '../services/cart_service.dart';
import '../services/checkout_service.dart';
import '../theme/app_theme.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  String selectedMethod = '';
  bool _isSaving = false;
  String? _errorMessage;

  final CartService _cart = CartService();

  @override
  void initState() {
    super.initState();
    _cart.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openManualBilling() async {
    setState(() {
      selectedMethod = 'manual';
      _errorMessage = null;
    });

    await Navigator.pushNamed(context, '/manual_selection');

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openCameraBilling() async {
    setState(() {
      selectedMethod = 'camera';
      _errorMessage = null;
    });

    await Navigator.pushNamed(context, '/scan');
    if (mounted) setState(() {});
  }

  Future<void> _confirmAndSaveBill() async {
    final items = List<CartItem>.from(_cart.items);

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add at least one product to the bill.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final result = await CheckoutService().checkoutCart(
        items,
        onProgress: (current, total) {
          if (!mounted) return;

          setState(() {
            _errorMessage = 'Saving item $current of $total...';
          });
        },
      );

      if (!mounted) return;

      if (result.success && result.invoice != null) {
        _cart.clear();

        setState(() {
          _isSaving = false;
          _errorMessage = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bill saved successfully. Stock has been updated.',
            ),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );

        Navigator.pushNamed(
          context,
          '/invoice',
          arguments: result.invoice,
        );
      } else {
        setState(() {
          _isSaving = false;
          _errorMessage = result.errorMessage ?? 'Unable to save the bill.';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
        _errorMessage = 'Unable to save bill: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _cart.items;
    final total = _cart.totalAmount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create Customer Bill',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Add products using any method.',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Add Products',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _BillingMethodCard(
                    icon: Icons.camera_alt_outlined,
                    title: 'Phone Camera Billing',
                    subtitle: 'Capture products with your phone camera',
                    selected: selectedMethod == 'camera',
                    onTap: _openCameraBilling,
                  ),
                  const SizedBox(height: 10),
                  _BillingMethodCard(
                    icon: Icons.edit_outlined,
                    title: 'Manual Billing',
                    subtitle: 'Search and select products from stock',
                    selected: selectedMethod == 'manual',
                    onTap: _openManualBilling,
                  ),
                  const SizedBox(height: 22),
                  if (_errorMessage != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerRed.withValues(
                          alpha: 0.08,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.dangerRed.withValues(
                            alpha: 0.25,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppTheme.dangerRed,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: AppTheme.dangerRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Text(
                    'Current Bill',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCurrentBill(items),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              16,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: 0.08,
                  ),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    Text(
                      '₹${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _confirmAndSaveBill,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.check_circle_outline,
                          ),
                    label: Text(
                      _isSaving ? 'Saving Bill...' : 'Confirm & Save Bill',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentBill(List<CartItem> items) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.grey.shade100,
        ),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 10),
            const Text(
              'No products added yet',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Choose Phone Camera or Manual to add products.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: List.generate(
        items.length,
        (index) {
          final item = items[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    child: Icon(
                      item.isLoose
                          ? Icons.scale_outlined
                          : Icons.inventory_2_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.formattedQuantity} × '
                          '₹${item.unitPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${item.subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppTheme.dangerRed,
                    ),
                    onPressed: _isSaving
                        ? null
                        : () {
                            _cart.removeItem(
                              item.product.id,
                            );
                          },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BillingMethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _BillingMethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: selected ? 3 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                child: Icon(
                  icon,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
