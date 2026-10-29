import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/cart_service.dart';
import '../theme/app_theme.dart';

class WeightEntryScreen extends StatefulWidget {
  final Product product;

  const WeightEntryScreen({super.key, required this.product});

  @override
  State<WeightEntryScreen> createState() => _WeightEntryScreenState();
}

class _WeightEntryScreenState extends State<WeightEntryScreen> {
  final _weightController = TextEditingController(text: '1.000');
  double _currentWeight = 1.000;

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  void _setWeight(double val) {
    setState(() {
      _currentWeight = double.parse(val.toStringAsFixed(3));
      _weightController.text = _currentWeight.toStringAsFixed(3);
    });
  }

  void _adjustWeight(double delta) {
    final next = (_currentWeight + delta).clamp(0.050, 500.0);
    _setWeight(next);
  }

  void _onTextChanged(String val) {
    final parsed = double.tryParse(val);
    if (parsed != null && parsed > 0) {
      setState(() {
        _currentWeight = double.parse(parsed.toStringAsFixed(3));
      });
    }
  }

  void _confirmAddToCart() {
    if (_currentWeight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a weight greater than 0 kg.')),
      );
      return;
    }

    CartService().addProduct(widget.product, quantity: _currentWeight);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final subtotal = _currentWeight * product.pricePerUnit;
    final isStockLow = _currentWeight > product.quantity;

    return Scaffold(
      appBar: AppBar(
        title: Text('Enter Weight: ${product.name}'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _confirmAddToCart,
            icon: const Icon(Icons.add_shopping_cart),
            label: Text('Add to Cart • ₹${subtotal.toStringAsFixed(2)}'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppTheme.primaryGreen,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Commodity Header Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.accentAmber.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.scale, color: AppTheme.accentAmber, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${product.pricePerUnit.toStringAsFixed(2)} / kg  •  Stock: ${product.formattedQuantity}',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Weight Display & Input Field
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFA5D6A7)),
              ),
              child: Column(
                children: [
                  const Text(
                    'Item Weight',
                    style: TextStyle(fontSize: 13, color: AppTheme.primaryGreenDark, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.remove),
                        onPressed: () => _adjustWeight(-0.100),
                        style: IconButton.styleFrom(backgroundColor: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: _weightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            suffixText: 'kg',
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: _onTextChanged,
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.add),
                        onPressed: () => _adjustWeight(0.100),
                        style: IconButton.styleFrom(backgroundColor: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentWeight < 1.0
                        ? '${(_currentWeight * 1000).toInt()} Grams'
                        : '${_currentWeight.toStringAsFixed(3)} Kilograms',
                    style: const TextStyle(color: AppTheme.primaryGreenDark, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (isStockLow) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.dangerRed.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.dangerRed.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.dangerRed, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Requested weight exceeds available inventory (${product.formattedQuantity})',
                        style: const TextStyle(color: AppTheme.dangerRed, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Quick Preset Weight Chips
            const Text(
              'Quick Weight Presets',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _presetButton('100 g', 0.100),
                _presetButton('250 g', 0.250),
                _presetButton('500 g', 0.500),
                _presetButton('1 kg', 1.000),
                _presetButton('2 kg', 2.000),
                _presetButton('5 kg', 5.000),
              ],
            ),
            const SizedBox(height: 24),

            // Live Calculated Total Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Line Total', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                      Text('Calculated at unit rate', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    ],
                  ),
                  Text(
                    '₹${subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
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

  Widget _presetButton(String label, double weightVal) {
    final isSelected = (_currentWeight - weightVal).abs() < 0.001;
    return OutlinedButton(
      onPressed: () => _setWeight(weightVal),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(80, 44),
        backgroundColor: isSelected ? AppTheme.primaryGreen : Colors.white,
        foregroundColor: isSelected ? Colors.white : AppTheme.textDark,
        side: BorderSide(
          color: isSelected ? AppTheme.primaryGreen : AppTheme.borderLight,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
