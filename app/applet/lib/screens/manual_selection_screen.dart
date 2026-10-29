import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/cart_service.dart';
import '../services/product_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class ManualSelectionScreen extends StatefulWidget {
  const ManualSelectionScreen({super.key});

  @override
  State<ManualSelectionScreen> createState() => _ManualSelectionScreenState();
}

class _ManualSelectionScreenState extends State<ManualSelectionScreen> {
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];

  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String _filter = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final products = await ProductService().getProducts();

      if (!mounted) return;

      setState(() {
        _allProducts = products;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<Product> list = List<Product>.from(_allProducts);

    if (_filter == 'KG') {
      list = list.where((p) => p.isKg || p.isLoose).toList();
    } else if (_filter == 'UNIT') {
      list = list.where((p) => p.isUnit).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();

      list = list.where((p) {
        return p.name.toLowerCase().contains(query) ||
            p.category.toLowerCase().contains(query);
      }).toList();
    }

    _filteredProducts = list;
  }

  Future<void> _addProduct(Product product) async {
    if (product.isKg || product.isLoose) {
      final added = await Navigator.pushNamed(
        context,
        '/weight_entry',
        arguments: product,
      );

      if (added == true && mounted) {
        setState(() {});
      }

      return;
    }

    CartService().addProduct(
      product,
      quantity: 1.0,
    );

    if (!mounted) return;

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} added to current bill'),
        backgroundColor: AppTheme.primaryGreen,
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _doneAdding() {
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartService();

    return ListenableBuilder(
      listenable: cart,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Manual Billing'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Products',
                onPressed: _fetchProducts,
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                          _applyFilters();
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: 'Search product name or category...',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _chip('ALL', 'All'),
                          const SizedBox(width: 8),
                          _chip('UNIT', 'Units'),
                          const SizedBox(width: 8),
                          _chip('KG', 'Kg / Loose'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(
                height: 1,
                color: AppTheme.borderLight,
              ),

              Expanded(
                child: _isLoading
                    ? const LoadingStateView(
                  message: 'Loading products...',
                )
                    : _error != null
                    ? ErrorStateView(
                  message: _error!,
                  onRetry: _fetchProducts,
                )
                    : _filteredProducts.isEmpty
                    ? const EmptyStateView(
                  icon: Icons.search_off_outlined,
                  title: 'No Products Found',
                  message:
                  'No products match your search.',
                )
                    : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    120,
                  ),
                  itemCount: _filteredProducts.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final product =
                    _filteredProducts[index];

                    final existing =
                    cart.findByProductId(product.id);

                    return Card(
                      child: ListTile(
                        onTap: () =>
                            _addProduct(product),
                        leading: Container(
                          padding:
                          const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: product.isUnit
                                ? AppTheme.primaryGreen
                                .withOpacity(0.1)
                                : AppTheme.accentAmber
                                .withOpacity(0.1),
                            borderRadius:
                            BorderRadius.circular(9),
                          ),
                          child: Icon(
                            product.isUnit
                                ? Icons
                                .inventory_2_outlined
                                : Icons.scale_outlined,
                            color: product.isUnit
                                ? AppTheme.primaryGreen
                                : AppTheme.accentAmber,
                          ),
                        ),
                        title: Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '₹${product.pricePerUnit.toStringAsFixed(2)} / ${product.sellingType} • ${product.category}',
                        ),
                        trailing: existing != null
                            ? CircleAvatar(
                          radius: 14,
                          child: Text(
                            existing.quantity
                                .toInt()
                                .toString(),
                            style:
                            const TextStyle(
                              fontSize: 12,
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                        )
                            : const Icon(
                          Icons.add_circle_outline,
                          color:
                          AppTheme.primaryGreen,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          bottomNavigationBar: cart.isEmpty
              ? null
              : SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                16,
                12,
                16,
                12,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: AppTheme.borderLight,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${cart.itemCount} product${cart.itemCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${cart.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _doneAdding,
                    icon: const Icon(Icons.check),
                    label: const Text('Done Adding'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      AppTheme.primaryGreen,
                      minimumSize:
                      const Size(150, 48),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String key, String label) {
    final selected = _filter == key;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _filter = key;
          _applyFilters();
        });
      },
      selectedColor:
      AppTheme.primaryGreen.withOpacity(0.15),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight:
        selected ? FontWeight.bold : FontWeight.w500,
        color: selected
            ? AppTheme.primaryGreen
            : AppTheme.textDark,
      ),
      side: BorderSide(
        color: selected
            ? AppTheme.primaryGreen
            : AppTheme.borderLight,
      ),
    );
  }
}