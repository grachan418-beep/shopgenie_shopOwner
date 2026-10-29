import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/product.dart';
import '../services/product_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class WorkerInventoryScreen extends StatefulWidget {
  const WorkerInventoryScreen({super.key});

  @override
  State<WorkerInventoryScreen> createState() => _WorkerInventoryScreenState();
}

class _WorkerInventoryScreenState extends State<WorkerInventoryScreen> {
  final ProductService _productsService = ProductService();
  List<Product> _products = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final products = await _productsService.getProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _editStock(Product product) async {
    final controller = TextEditingController(
      text: product.quantity.toString(),
    );
    final formKey = GlobalKey<FormState>();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Update ${product.name} stock'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  TextInputType.numberWithOptions(decimal: product.isKg),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: InputDecoration(
                labelText: 'Quantity',
                suffixText: product.isKg ? 'kg' : 'units',
              ),
              validator: (value) {
                final quantity = double.tryParse(value ?? '');
                if (quantity == null || quantity < 0) {
                  return 'Enter a valid non-negative quantity';
                }
                if (product.isUnit && quantity % 1 != 0) {
                  return 'Unit stock must be a whole number';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);
                      try {
                        await _productsService.updateStockQuantity(
                          product.id,
                          double.parse(controller.text),
                        );
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        await _loadProducts();
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() => saving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Could not update stock: $error')),
                        );
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Stock')),
      body: _isLoading
          ? const LoadingStateView(message: 'Loading shop stock...')
          : _errorMessage != null
              ? ErrorStateView(message: _errorMessage!, onRetry: _loadProducts)
              : _products.isEmpty
                  ? const EmptyStateView(
                      title: 'No products to manage',
                      message: 'Products added by the owner will appear here.',
                      icon: Icons.inventory_2_outlined,
                    )
                  : RefreshIndicator(
                      onRefresh: _loadProducts,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: _products
                            .map(
                              (product) => Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  title: Text(product.name),
                                  subtitle: Text(
                                    '${product.category} • ${product.formattedQuantity}',
                                  ),
                                  trailing: IconButton(
                                    tooltip: 'Update stock quantity',
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      color: AppTheme.primaryGreen,
                                    ),
                                    onPressed: () => _editStock(product),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
    );
  }
}
