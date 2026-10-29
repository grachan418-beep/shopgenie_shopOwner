import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../services/cart_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartService(),
      builder: (context, _) {
        final cart = CartService();
        final items = cart.items;

        return Scaffold(
          appBar: AppBar(
            title: Text('Cart (${items.length})'),
            actions: [
              if (items.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: 'Clear Cart',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Clear Cart'),
                        content: const Text('Are you sure you want to remove all items from the cart?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
                            onPressed: () {
                              cart.clear();
                              Navigator.pop(ctx);
                            },
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
          bottomNavigationBar: items.isNotEmpty
              ? SafeArea(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: AppTheme.borderLight)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${items.length} ${items.length == 1 ? 'item' : 'items'} in bill',
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                            ),
                            Row(
                              children: [
                                const Text('Total: ', style: TextStyle(fontSize: 14, color: AppTheme.textMuted)),
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
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, '/checkout'),
                          icon: const Icon(Icons.payment),
                          label: Text('Proceed to Checkout (₹${cart.totalAmount.toStringAsFixed(2)})'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
          body: items.isEmpty
              ? EmptyStateView(
                  icon: Icons.remove_shopping_cart_outlined,
                  title: 'Your Cart is Empty',
                  message: 'Add products using the vision scanner or manual selection.',
                  actionLabel: 'Scan Products',
                  onAction: () => Navigator.pushReplacementNamed(context, '/scan'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _CartItemCard(item: item);
                  },
                ),
        );
      },
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem item;

  const _CartItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final cart = CartService();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: item.isLoose
                        ? AppTheme.accentAmber.withOpacity(0.12)
                        : AppTheme.primaryGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.isLoose ? Icons.scale_outlined : Icons.inventory_2_outlined,
                    color: item.isLoose ? AppTheme.accentAmber : AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${item.unitPrice.toStringAsFixed(2)} / ${item.product.sellingType}',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      SellingTypeBadge(
                        sellingType: item.product.sellingType,
                        isLoose: item.isLoose,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${item.subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGreenDark,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppTheme.dangerRed, size: 20),
                      onPressed: () => cart.removeItem(item.product.id),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 16, color: AppTheme.borderLight),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Qty: ${item.formattedQuantity}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                if (item.isLoose) ...[
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/weight_entry', arguments: item.product);
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(100, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: const Text('Change Weight', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.remove, size: 16),
                        onPressed: () => cart.decrementQuantity(item.product.id),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '${item.quantity.toInt()}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.add, size: 16),
                        onPressed: () => cart.incrementQuantity(item.product.id),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
