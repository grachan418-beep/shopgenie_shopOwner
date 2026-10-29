import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/product_service.dart';
import '../theme/app_theme.dart';

class EditProductScreen extends StatefulWidget {
  final Product product;

  const EditProductScreen({
    super.key,
    required this.product,
  });

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _categoryController;
  late TextEditingController _costPriceController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _quantityController;

  late String _sellingType;
  late bool _isLoose;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _nameController =
        TextEditingController(text: widget.product.name);

    _categoryController =
        TextEditingController(text: widget.product.category);

    _costPriceController = TextEditingController(
      text: widget.product.costPrice.toStringAsFixed(2),
    );

    _sellingPriceController = TextEditingController(
      text: widget.product.pricePerUnit.toStringAsFixed(2),
    );

    _quantityController = TextEditingController(
      text: widget.product.isUnit
          ? widget.product.quantity.toInt().toString()
          : widget.product.quantity.toStringAsFixed(3),
    );

    _sellingType = widget.product.sellingType;
    _isLoose = widget.product.isLoose;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    final cost =
        double.tryParse(_costPriceController.text.trim()) ?? 0.0;

    final price =
        double.tryParse(_sellingPriceController.text.trim()) ?? 0.0;

    final qty =
        double.tryParse(_quantityController.text.trim()) ?? 0.0;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final updated = await ProductService().updateProduct(
        widget.product.id,
        name: _nameController.text.trim(),
        category: _categoryController.text.trim(),
        sellingType: _sellingType,
        costPrice: cost,
        pricePerUnit: price,
        quantity: qty,
        isLoose: _isLoose,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product updated successfully!'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );

      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profit =
        (double.tryParse(_sellingPriceController.text) ?? 0) -
            (double.tryParse(_costPriceController.text) ?? 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Product'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Edit Product Information',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Update the product details and stock information.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 20),

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerRed.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.dangerRed.withOpacity(0.3),
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
                const SizedBox(height: 16),
              ],

              // Basic information
              const Text(
                'Basic Information',
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
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Product Name',
                          hintText: 'Example: Rice',
                          prefixIcon:
                          Icon(Icons.inventory_2_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Enter product name';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _categoryController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          hintText: 'Example: Grocery',
                          prefixIcon:
                          Icon(Icons.category_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Enter category';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Product type
              const Text(
                'Product Type',
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
                      Row(
                        children: [
                          Icon(
                            _isLoose
                                ? Icons.scale_outlined
                                : Icons.inventory_2_outlined,
                            size: 30,
                            color: _isLoose
                                ? AppTheme.accentAmber
                                : AppTheme.primaryGreen,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isLoose
                                      ? 'Loose Product'
                                      : 'Packaged Product',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isLoose
                                      ? 'Sold by weight or volume'
                                      : 'Sold as individual packaged items',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Loose commodity',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: const Text(
                          'Enable for products such as rice, sugar or loose oil.',
                        ),
                        value: _isLoose,
                        onChanged: (value) {
                          setState(() {
                            _isLoose = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Pricing
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
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _sellingPriceController,
                              keyboardType:
                              const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Selling Price',
                                prefixText: '₹ ',
                                suffixText: '/ $_sellingType',
                                border:
                                const OutlineInputBorder(),
                              ),
                              onChanged: (_) {
                                setState(() {});
                              },
                              validator: (value) {
                                final number =
                                double.tryParse(value ?? '');

                                if (number == null || number <= 0) {
                                  return 'Enter valid price';
                                }

                                return null;
                              },
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: TextFormField(
                              controller: _costPriceController,
                              keyboardType:
                              const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Cost Price',
                                prefixText: '₹ ',
                                suffixText: '/ $_sellingType',
                                border:
                                const OutlineInputBorder(),
                              ),
                              onChanged: (_) {
                                setState(() {});
                              },
                              validator: (value) {
                                final number =
                                double.tryParse(value ?? '');

                                if (number == null || number < 0) {
                                  return 'Enter valid cost';
                                }

                                return null;
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.trending_up,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Current profit: ₹${profit.toStringAsFixed(2)} / $_sellingType',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Stock
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
                  child: TextFormField(
                    controller: _quantityController,
                    keyboardType:
                    const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Current Stock',
                      hintText: 'Enter available quantity',
                      prefixIcon:
                      const Icon(Icons.warehouse_outlined),
                      suffixText: _sellingType,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final number =
                      double.tryParse(value ?? '');

                      if (number == null || number < 0) {
                        return 'Stock cannot be negative';
                      }

                      if (_sellingType == 'UNIT' &&
                          number % 1 != 0) {
                        return 'UNIT quantity must be a whole number';
                      }

                      return null;
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Vision status
              const Text(
                'Phone Camera Recognition',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                      widget.product.featureVector != null
                          ? Icons.check_circle_outline
                          : Icons.camera_alt_outlined,
                    ),
                  ),
                  title: const Text(
                    'Product Recognition',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    widget.product.featureVector != null
                        ? 'MobileNetV3 embedding is available'
                        : 'Vision embedding is not enrolled yet',
                  ),
                  trailing: Text(
                    widget.product.featureVector != null
                        ? 'Ready'
                        : 'Not enrolled',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color:
                      widget.product.featureVector != null
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed:
                  _isLoading ? null : _handleUpdate,
                  icon: _isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isLoading
                        ? 'Saving Changes...'
                        : 'Save Changes',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}