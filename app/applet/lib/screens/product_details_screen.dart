import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/product_service.dart';
import '../theme/app_theme.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;

  const ProductDetailsScreen({
    super.key,
    required this.product,
  });

  @override
  State<ProductDetailsScreen> createState() =>
      _ProductDetailsScreenState();
}

class _ProductDetailsScreenState
    extends State<ProductDetailsScreen> {
  late Product _product;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text(
          'Are you sure you want to remove '
              '"${_product.name}" from your catalog?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      await ProductService().deleteProduct(_product.id);

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isDeleting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete product: $e'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }
  }

  Future<void> _editProduct() async {
    final updated = await Navigator.pushNamed(
      context,
      '/edit_product',
      arguments: _product,
    );

    if (updated is Product && mounted) {
      setState(() {
        _product = updated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profitPerUnit =
        _product.pricePerUnit - _product.costPrice;

    final margin = _product.pricePerUnit > 0
        ? ((profitPerUnit / _product.pricePerUnit) * 100)
        .toStringAsFixed(1)
        : '0.0';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Product',
            onPressed: _editProduct,
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: AppTheme.dangerRed,
            ),
            tooltip: 'Delete Product',
            onPressed: _isDeleting ? null : _confirmDelete,
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PRODUCT HEADER
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius:
                        BorderRadius.circular(14),
                        color: _product.isLoose
                            ? AppTheme.accentAmber
                            .withOpacity(0.12)
                            : AppTheme.primaryGreen
                            .withOpacity(0.10),
                      ),
                      child: Icon(
                        _product.isLoose
                            ? Icons.scale_outlined
                            : Icons.inventory_2_outlined,
                        size: 34,
                        color: _product.isLoose
                            ? AppTheme.accentAmber
                            : AppTheme.primaryGreen,
                      ),
                    ),

                    const SizedBox(width: 16),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            _product.name,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            _product.category,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),

                          const SizedBox(height: 10),

                          Row(
                            children: [
                              _InfoBadge(
                                label: _product.isLoose
                                    ? 'Loose'
                                    : 'Packaged',
                              ),
                              const SizedBox(width: 8),
                              _InfoBadge(
                                label: _product.sellingType,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // STOCK
            const Text(
              'Stock Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _DetailRow(
                      title: 'Current Stock',
                      value: _product.formattedQuantity,
                    ),

                    const Divider(height: 24),

                    _DetailRow(
                      title: 'Selling Unit',
                      value: _product.sellingType,
                    ),

                    const Divider(height: 24),

                    _DetailRow(
                      title: 'Product Type',
                      value: _product.isLoose
                          ? 'Loose Product'
                          : 'Packaged Product',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // PRICING
            const Text(
              'Pricing',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _DetailRow(
                      title: 'Cost Price',
                      value:
                      '₹${_product.costPrice.toStringAsFixed(2)} / ${_product.sellingType}',
                    ),

                    const Divider(height: 24),

                    _DetailRow(
                      title: 'Selling Price',
                      value:
                      '₹${_product.pricePerUnit.toStringAsFixed(2)} / ${_product.sellingType}',
                      highlight: true,
                    ),

                    const Divider(height: 24),

                    _DetailRow(
                      title: 'Profit',
                      value:
                      '₹${profitPerUnit.toStringAsFixed(2)} / ${_product.sellingType}',
                      valueColor: Colors.green,
                    ),

                    const Divider(height: 24),

                    _DetailRow(
                      title: 'Profit Margin',
                      value: '$margin%',
                      valueColor: Colors.green,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // VISION SETUP
            const Text(
              'Phone Camera & Vision',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _DetailRow(
                      title: 'Phone Camera Recognition',
                      value: _product.featureVector != null
                          ? 'Ready'
                          : 'Not enrolled',
                      valueColor:
                      _product.featureVector != null
                          ? Colors.green
                          : Colors.grey,
                    ),

                    const Divider(height: 24),

                    _DetailRow(
                      title: 'MobileNetV3',
                      value: _product.featureVector != null
                          ? 'Embedding available'
                          : 'Embedding not available',
                    ),

                    const Divider(height: 24),

                    _DetailRow(
                      title: 'Recognition Type',
                      value: _product.isLoose
                          ? 'Loose product identification'
                          : 'Packaged product identification',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // EDIT BUTTON
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _editProduct,
                icon: const Icon(Icons.edit_outlined),
                label: const Text(
                  'Edit Product',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // DELETE BUTTON
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed:
                _isDeleting ? null : _confirmDelete,
                icon: const Icon(
                  Icons.delete_outline,
                ),
                label: const Text(
                  'Delete Product',
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String title;
  final String value;
  final bool highlight;
  final Color? valueColor;

  const _DetailRow({
    required this.title,
    required this.value,
    this.highlight = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
      MainAxisAlignment.spaceBetween,
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: highlight
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          ),
        ),

        const SizedBox(width: 16),

        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor ??
                  (highlight
                      ? AppTheme.primaryGreen
                      : Colors.black87),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String label;

  const _InfoBadge({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.grey.shade100,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}