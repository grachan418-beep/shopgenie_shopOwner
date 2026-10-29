import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/scan_result.dart';
import '../services/vision_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

/// Captures a product using the phone's built-in camera and sends the image
/// to the existing vision-match endpoint as base64. No ESP32-CAM is required.
class ScanningScreen extends StatefulWidget {
  const ScanningScreen({super.key});

  @override
  State<ScanningScreen> createState() => _ScanningScreenState();
}

class _ScanningScreenState extends State<ScanningScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  double _threshold = 0.78;
  bool _isScanning = false;
  String? _errorMessage;
  XFile? _capturedImage;

  Future<void> _captureAndIdentify() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (!mounted || image == null) return;

      setState(() {
        _capturedImage = image;
        _isScanning = true;
      });

      final bytes = await image.readAsBytes();
      final imageBase64 = base64Encode(bytes);
      final ScanResult result = await VisionService().matchFromBase64(
        imageBase64: imageBase64,
        threshold: _threshold,
      );

      if (!mounted) return;
      setState(() => _isScanning = false);
      Navigator.pushNamed(context, '/scan_results', arguments: result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _errorMessage = 'Could not identify this photo. $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phone Camera Scanner'),
        actions: [
          CartBadgeButton(
            onPressed: () => Navigator.pushNamed(context, '/cart'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            height: 280,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF1E2321),
              borderRadius: BorderRadius.circular(20),
            ),
            child: _capturedImage == null
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined,
                          size: 64, color: Colors.white70),
                      SizedBox(height: 12),
                      Text(
                        'Capture a product with your phone',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Place one item in good light and keep its label visible.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  )
                : Image.file(
                    // XFile.path is a local file path from the camera capture.
                    File(_capturedImage!.path),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.image_not_supported_outlined,
                          color: Colors.white70, size: 48),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          if (_isScanning) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 10),
            const Text(
              'Sending photo for product matching…',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.dangerRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.dangerRed.withOpacity(0.3),
                ),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: AppTheme.dangerRed),
              ),
            ),
            const SizedBox(height: 16),
          ],
          ElevatedButton.icon(
            onPressed: _isScanning ? null : _captureAndIdentify,
            icon: Icon(_capturedImage == null
                ? Icons.camera_alt_outlined
                : Icons.camera_enhance_outlined),
            label: Text(_isScanning
                ? 'Identifying Product…'
                : _capturedImage == null
                    ? 'Open Camera & Identify'
                    : 'Retake Photo & Identify'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isScanning
                ? null
                : () => Navigator.pushNamed(context, '/manual_selection'),
            icon: const Icon(Icons.touch_app_outlined),
            label: const Text('Select Product Manually'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recognition Settings',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Similarity threshold'),
                      Text(
                        '${(_threshold * 100).round()}%',
                        style: const TextStyle(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _threshold,
                    min: 0.50,
                    max: 0.95,
                    divisions: 45,
                    activeColor: AppTheme.primaryGreen,
                    label: '${(_threshold * 100).round()}%',
                    onChanged: _isScanning
                        ? null
                        : (value) => setState(() => _threshold = value),
                  ),
                  const Text(
                    'A higher threshold requires a closer visual match. If recognition fails, use manual selection.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

