import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/product_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final ProductService _productService = ProductService();

  List<Product> _products = [];
  List<Product> _filteredProducts = [];

  bool _isLoading = true;
  String? _errorMessage;

  final TextEditingController _searchController =
  TextEditingController();

  @override
  void initState() {
    super.initState();

    _loadProducts();

    _searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterProducts);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final products = await _productService.getProducts();

      if (!mounted) return;

      setState(() {
        _products = products;
        _filteredProducts = products;
        _isLoading = false;
      });

      _filterProducts();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _filterProducts() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _filteredProducts = List<Product>.from(_products);
      } else {
        _filteredProducts = _products.where((product) {
          return product.name.toLowerCase().contains(query) ||
              product.category.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  bool _isLowStock(Product product) {
    return product.quantity <= 5;
  }

  Future<void> _addProduct() async {
    final result = await Navigator.pushNamed(
      context,
      '/add_product',
    );

    if (result != null) {
      await _loadProducts();
    }
  }

  Future<void> _openProduct(Product product) async {
    await Navigator.pushNamed(
      context,
      '/product_detail',
      arguments: product,
    );

    await _loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    final lowStockCount =
        _products.where(_isLowStock).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadProducts,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const Text(
                'Current Stock',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'View the products currently available in your shop.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 20),

              // STOCK SUMMARY
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Products',
                      value: '${_products.length}',
                      icon:
                      Icons.inventory_2_outlined,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _SummaryCard(
                      title: 'Low Stock',
                      value: '$lowStockCount',
                      icon:
                      Icons.warning_amber_outlined,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              const Text(
                'Stock Items',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              // SEARCH
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search products',
                  prefixIcon:
                  const Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: _loadProducts,
                    icon: const Icon(
                      Icons.refresh,
                    ),
                    tooltip: 'Refresh stock',
                  ),
                  border:
                  const OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              if (_isLoading)
                const Padding(
                  padding:
                  EdgeInsets.symmetric(
                    vertical: 40,
                  ),
                  child: Center(
                    child:
                    CircularProgressIndicator(),
                  ),
                )
              else if (_errorMessage != null)
                _buildErrorState()
              else if (_filteredProducts.isEmpty)
                  _buildEmptyState()
                else
                  ..._filteredProducts.map(
                        (product) => Padding(
                      padding:
                      const EdgeInsets.only(
                        bottom: 10,
                      ),
                      child: _StockCard(
                        product: product,
                        isLowStock:
                        _isLowStock(product),
                        onTap: () =>
                            _openProduct(product),
                      ),
                    ),
                  ),

              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _addProduct,
                  icon: const Icon(
                    Icons.add_box_outlined,
                  ),
                  label: const Text(
                    'Add Product to Stock',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
            ),

            const SizedBox(height: 12),

            const Text(
              'Could not load inventory',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              _errorMessage ??
                  'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _loadProducts,
              icon:
              const Icon(Icons.refresh),
              label:
              const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 52,
            ),

            const SizedBox(height: 12),

            const Text(
              'No stock items found',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              _searchController.text
                  .trim()
                  .isEmpty
                  ? 'Add your first product to stock.'
                  : 'No product matches your search.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding:
        const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 23,
              child: Icon(icon),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color:
                      Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight:
                      FontWeight.bold,
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

class _StockCard extends StatelessWidget {
  final Product product;
  final bool isLowStock;
  final VoidCallback onTap;

  const _StockCard({
    required this.product,
    required this.isLowStock,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(16),
        child: Padding(
          padding:
          const EdgeInsets.all(16),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 25,
                child: Icon(
                  Icons.inventory_2_outlined,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style:
                      const TextStyle(
                        fontSize: 16,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      product.category,
                      style: TextStyle(
                        color:
                        Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Quantity: ${product.formattedQuantity}',
                      style:
                      const TextStyle(
                        fontWeight:
                        FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      'Selling: ₹${product.pricePerUnit.toStringAsFixed(2)}',
                      style: TextStyle(
                        color:
                        Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),

                    if (product.isLoose) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Loose Product',
                        style: TextStyle(
                          color:
                          Colors.green.shade700,
                          fontSize: 12,
                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              Column(
                children: [
                  Icon(
                    isLowStock
                        ? Icons
                        .warning_amber_outlined
                        : Icons
                        .check_circle_outline,
                    color: isLowStock
                        ? Colors.orange
                        : Colors.green,
                  ),

                  const SizedBox(height: 4),

                  Text(
                    isLowStock
                        ? 'Low Stock'
                        : 'In Stock',
                    style: TextStyle(
                      fontSize: 11,
                      color: isLowStock
                          ? Colors.orange
                          : Colors.green,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}