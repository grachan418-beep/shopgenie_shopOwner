import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/product_service.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  String selectedMethod = '';
  String selectedUnit = 'Piece';

  bool isLoose = false;
  bool isSaving = false;

  XFile? _capturedProductImage;

  final productNameController = TextEditingController();
  final categoryController = TextEditingController();
  final quantityController = TextEditingController();
  final costPriceController = TextEditingController();
  final sellingPriceController = TextEditingController();

  @override
  void dispose() {
    productNameController.dispose();
    categoryController.dispose();
    quantityController.dispose();
    costPriceController.dispose();
    sellingPriceController.dispose();
    super.dispose();
  }

  void selectMethod(String method) {
    setState(() {
      selectedMethod = method;
    });
  }

  Future<void> _captureProductImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (!mounted || image == null) return;

      setState(() {
        _capturedProductImage = image;
        selectedMethod = 'camera';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Product photo captured. Enter the product details below.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to capture photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> addToStock() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final quantity = double.tryParse(quantityController.text.trim()) ?? 0;

    final costPrice = double.tryParse(costPriceController.text.trim()) ?? 0;

    final sellingPrice =
        double.tryParse(sellingPriceController.text.trim()) ?? 0;

    // Match the existing Django backend's UNIT and KG values.
    final sellingType = selectedUnit == 'Kg' ? 'KG' : 'UNIT';

    setState(() {
      isSaving = true;
    });

    try {
      final product = await ProductService().registerProduct(
        name: productNameController.text.trim(),
        category: categoryController.text.trim(),
        sellingType: sellingType,
        costPrice: costPrice,
        pricePerUnit: sellingPrice,
        quantity: quantity,
        isLoose: isLoose,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${product.name} added to stock successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, product);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Product'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Product to Stock',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add a product using your phone camera or manual entry.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Choose Input Method',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              _InputMethodCard(
                icon: Icons.camera_alt_outlined,
                title: 'Capture with Phone Camera',
                subtitle: 'Take a photo of the product',
                selected: selectedMethod == 'camera',
                onTap: _captureProductImage,
              ),
              const SizedBox(height: 12),
              _InputMethodCard(
                icon: Icons.edit_outlined,
                title: 'Add Manually',
                subtitle: 'Enter product details yourself',
                selected: selectedMethod == 'manual',
                onTap: () => selectMethod('manual'),
              ),
              const SizedBox(height: 28),
              if (selectedMethod == 'camera') ...[
                _buildCameraSection(),
                const SizedBox(height: 24),
                _buildProductForm(),
              ],
              if (selectedMethod == 'manual') _buildProductForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Product Photo',
          subtitle:
              'Capture a clear photo of the product using your phone camera.',
        ),
        const SizedBox(height: 16),
        if (_capturedProductImage != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(_capturedProductImage!.path),
              height: 220,
              width: double.infinity,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 220,
                  width: double.infinity,
                  alignment: Alignment.center,
                  color: Colors.grey.shade100,
                  child: const Text('Unable to display this photo.'),
                );
              },
            ),
          )
        else
          Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.grey.shade100,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt_outlined, size: 52),
                SizedBox(height: 12),
                Text('No product photo captured'),
              ],
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _captureProductImage,
            icon: const Icon(Icons.camera_alt_outlined),
            label: Text(
              _capturedProductImage == null
                  ? 'Take Product Photo'
                  : 'Retake Photo',
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Note: The photo is displayed here. Product recognition and '
          'uploading the image to the backend are not connected by this '
          'screen yet.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildProductForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Product Details',
          subtitle: 'Enter the details before adding the product to stock.',
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: productNameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Product Name',
            hintText: 'Example: Rice',
            prefixIcon: Icon(Icons.inventory_2_outlined),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Enter product name';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: categoryController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Category',
            hintText: 'Example: Grocery',
            prefixIcon: Icon(Icons.category_outlined),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Enter category';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: selectedUnit,
          decoration: const InputDecoration(
            labelText: 'Unit',
            prefixIcon: Icon(Icons.scale_outlined),
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: 'Piece',
              child: Text('Piece'),
            ),
            DropdownMenuItem(
              value: 'Packet',
              child: Text('Packet'),
            ),
            DropdownMenuItem(
              value: 'Kg',
              child: Text('Kilogram (kg)'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                selectedUnit = value;
              });
            }
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: quantityController,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          decoration: InputDecoration(
            labelText: 'Stock Quantity',
            hintText: selectedUnit == 'Kg' ? 'Example: 20' : 'Example: 100',
            prefixIcon: const Icon(Icons.inventory_outlined),
            suffixText: selectedUnit,
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            final number = double.tryParse(value ?? '');

            if (number == null || number < 0) {
              return 'Enter a valid quantity';
            }

            if (selectedUnit != 'Kg' && number % 1 != 0) {
              return 'Quantity must be a whole number';
            }

            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: costPriceController,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          decoration: InputDecoration(
            labelText: 'Cost Price',
            hintText: 'Example: 42',
            prefixIcon: const Icon(Icons.currency_rupee),
            suffixText: '/ $selectedUnit',
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            final number = double.tryParse(value ?? '');

            if (number == null || number < 0) {
              return 'Enter a valid cost price';
            }

            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: sellingPriceController,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          decoration: InputDecoration(
            labelText: 'Selling Price',
            hintText: 'Example: 50',
            prefixIcon: const Icon(Icons.sell_outlined),
            suffixText: '/ $selectedUnit',
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            final number = double.tryParse(value ?? '');

            if (number == null || number <= 0) {
              return 'Enter a valid selling price';
            }

            return null;
          },
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Loose Product',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Enable for loose commodities such as rice or sugar.',
          ),
          value: isLoose,
          onChanged: (value) {
            setState(() {
              isLoose = value;
            });
          },
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: isSaving ? null : addToStock,
            icon: isSaving
                ? const SizedBox(
                    width: 21,
                    height: 21,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.add_box_outlined),
            label: Text(
              isSaving ? 'Saving to Stock...' : 'Add to Stock',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _InputMethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _InputMethodCard({
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
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 27,
                child: Icon(icon, size: 27),
              ),
              const SizedBox(width: 15),
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
                    const SizedBox(height: 5),
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

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
