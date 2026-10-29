import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/scan_result.dart';
import '../services/cart_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class ScanResultsScreen extends StatefulWidget {
  final ScanResult scanResult;

  const ScanResultsScreen({super.key, required this.scanResult});

  @override
  State<ScanResultsScreen> createState() => _ScanResultsScreenState();
}

class _ScanResultsScreenState extends State<ScanResultsScreen> {
  int _unitQuantity = 1;

  void _addMatchedProductToCart(Product product) {
    if (product.isKg) {
      Navigator.pushNamed(context, '/weight_entry', arguments: product).then((added) {
        if (added == true && mounted) {
          Navigator.pop(context);
        }
      });
    } else {
      CartService().addProduct(product, quantity: _unitQuantity.toDouble());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $_unitQuantity unit(s) of ${product.name} to cart'),
          backgroundColor: AppTheme.primaryGreen,
          action: SnackBarAction(
            label: 'CART',
            textColor: Colors.white,
            onPressed: () => Navigator.pushReplacementNamed(context, '/cart'),
          ),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.scanResult;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vision Recognition Result'),
        actions: [
          CartBadgeButton(
            onPressed: () => Navigator.pushNamed(context, '/cart'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (result.isProductMatch && result.toProduct() != null) ...[
              _buildProductMatchView(result.toProduct()!, result),
            ] else if (result.isLooseCandidates) ...[
              _buildLooseCandidatesView(result),
            ] else ...[
              _buildNoMatchView(result),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProductMatchView(Product product, ScanResult result) {
    final confidence = result.confidencePercentage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success Header Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFA5D6A7)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Branded Product Identified',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'MobileNetV3 Match Confidence: $confidence%',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF2E7D32)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Product Details Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              ),
              const SizedBox(height: 4),
              Text(
                product.category,
                style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Selling Price', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      Text(
                        '₹${product.pricePerUnit.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                  SellingTypeBadge(sellingType: product.sellingType, isLoose: product.isLoose),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppTheme.borderLight),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Available Stock:', style: TextStyle(color: AppTheme.textMuted)),
                  Text(
                    product.formattedQuantity,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (product.isUnit) ...[
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Quantity to Bill:', style: TextStyle(fontWeight: FontWeight.w600)),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.borderLight),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 18),
                            onPressed: _unitQuantity > 1 ? () => setState(() => _unitQuantity--) : null,
                          ),
                          Text(
                            '$_unitQuantity',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 18),
                            onPressed: () => setState(() => _unitQuantity++),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        ElevatedButton.icon(
          onPressed: () => _addMatchedProductToCart(product),
          icon: const Icon(Icons.add_shopping_cart),
          label: Text(product.isKg ? 'Enter Weight & Add to Cart' : 'Add to Cart (₹${(product.pricePerUnit * _unitQuantity).toStringAsFixed(2)})'),
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Scan Another Item'),
        ),
      ],
    );
  }

  Widget _buildLooseCandidatesView(ScanResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Plain-bag Alert Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFCC80)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppTheme.accentAmber,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.scale_outlined, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Plain-Bag / Loose Item Detected',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFE65100)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.message ?? 'Please select the matching loose candidate below and enter weight.',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFBF360C)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'Loose Inventory Candidates',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
        ),
        const SizedBox(height: 12),

        if (result.candidates.isEmpty)
          EmptyStateView(
            icon: Icons.inventory_2_outlined,
            title: 'No Loose Products Found',
            message: 'No products with selling type "KG" or loose tag are registered in your catalog.',
            actionLabel: 'Manual Selection',
            onAction: () => Navigator.pushReplacementNamed(context, '/manual_selection'),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: result.candidates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = result.candidates[index];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accentAmber.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.scale, color: AppTheme.accentAmber),
                  ),
                  title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '₹${item.pricePerUnit.toStringAsFixed(2)} / kg  •  Stock: ${item.formattedQuantity}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  trailing: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/weight_entry', arguments: item).then((added) {
                        if (added == true && mounted) {
                          Navigator.pop(context);
                        }
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(100, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('Enter Weight'),
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: () => Navigator.pushReplacementNamed(context, '/manual_selection'),
          child: const Text('Browse All Catalog Items'),
        ),
      ],
    );
  }

  Widget _buildNoMatchView(ScanResult result) {
    return Column(
      children: [
        EmptyStateView(
          icon: Icons.search_off_outlined,
          title: 'No Matching Product',
          message: result.message ?? 'The visual scanner could not identify this product above the similarity threshold.',
          actionLabel: 'Manual Selection',
          onAction: () => Navigator.pushReplacementNamed(context, '/manual_selection'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Try Scanning Again'),
        ),
      ],
    );
  }
}
