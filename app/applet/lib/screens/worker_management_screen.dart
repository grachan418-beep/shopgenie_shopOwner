import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/worker.dart';
import '../services/api_cache_listener.dart';
import '../services/api_service.dart';
import '../services/worker_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

const Map<String, String> _permissionLabels = {
  'view_products': 'View products and stock',
  'manage_inventory': 'Add and manage inventory',
  'create_bills': 'Create bills',
  'view_invoices': 'View invoices',
};

class WorkerManagementScreen extends StatefulWidget {
  const WorkerManagementScreen({super.key});

  @override
  State<WorkerManagementScreen> createState() => _WorkerManagementScreenState();
}

class _WorkerManagementScreenState extends State<WorkerManagementScreen>
    with ApiCacheListener<WorkerManagementScreen> {
  final WorkerService _service = WorkerService();
  List<Worker> _workers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    startListeningForCachedData();
    _loadWorkers();
  }

  @override
  void dispose() {
    stopListeningForCachedData();
    super.dispose();
  }

  @override
  bool shouldReloadForCachedUrl(Uri url) =>
      url.path == '/api/workers/' ||
      RegExp(r'^/api/workers/\d+/$').hasMatch(url.path);

  @override
  Future<void> reloadFromCache() => _loadWorkers();

  Future<void> _loadWorkers() async {
    setState(() {
      _isLoading = _workers.isEmpty;
      _errorMessage = null;
    });
    try {
      final workers = await _service.getWorkers();
      if (!mounted) return;
      setState(() {
        _workers = workers;
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

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showAccessCode(CreatedWorker created,
      {required String title}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Share this one-time code with ${created.worker.name}. It will not be shown again.'),
            const SizedBox(height: 16),
            SelectableText(
              created.code,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: created.code));
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Access code copied')),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy'),
          ),
          TextButton.icon(
            onPressed: () => Share.share(
              'ShopGenie shopkeeper login\nName: ${created.worker.name}\nAccess code: ${created.code}',
              subject: 'ShopGenie access code',
            ),
            icon: const Icon(Icons.share_outlined),
            label: const Text('Share'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _showWorkerForm({Worker? worker}) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: worker?.name ?? '');
    final phoneController = TextEditingController(text: worker?.phone ?? '');
    final permissions = <String, bool>{
      for (final key in _permissionLabels.keys)
        key: worker?.permissions[key] ?? (key == 'view_products'),
    };
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(worker == null ? 'Add Shopkeeper' : 'Edit Shopkeeper'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter a shopkeeper name'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration:
                          const InputDecoration(labelText: 'Phone (optional)'),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Permissions',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    ..._permissionLabels.entries.map(
                      (entry) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(entry.value,
                            style: const TextStyle(fontSize: 14)),
                        value: permissions[entry.key],
                        onChanged: (value) => setDialogState(
                          () => permissions[entry.key] = value ?? false,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                        if (worker == null) {
                          final created = await _service.createWorker(
                            name: nameController.text,
                            phone: phoneController.text,
                            permissions: permissions,
                          );
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          await _showAccessCode(created,
                              title: 'Shopkeeper Created');
                        } else {
                          await _service.updateWorker(
                            worker.id,
                            name: nameController.text,
                            phone: phoneController.text,
                            permissions: permissions,
                          );
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          _showMessage('Shopkeeper updated');
                        }
                        await _loadWorkers();
                      } on ApiException catch (error) {
                        setDialogState(() => saving = false);
                        _showMessage(error.message);
                      } catch (error) {
                        setDialogState(() => saving = false);
                        _showMessage('Could not save shopkeeper: $error');
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(worker == null ? 'Create' : 'Save'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    phoneController.dispose();
  }

  Future<void> _setActive(Worker worker, bool isActive) async {
    try {
      await _service.updateWorker(worker.id, isActive: isActive);
      await _loadWorkers();
    } catch (error) {
      _showMessage('Could not update shopkeeper: $error');
    }
  }

  Future<void> _regenerateCode(Worker worker) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Replace access code?'),
        content: const Text(
          'The current code and all existing sessions will stop working immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Replace code'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final created = await _service.regenerateCode(worker.id);
      await _loadWorkers();
      if (mounted) await _showAccessCode(created, title: 'New Access Code');
    } catch (error) {
      _showMessage('Could not replace the access code: $error');
    }
  }

  Future<void> _deleteWorker(Worker worker) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete shopkeeper?'),
        content: Text('Remove ${worker.name} and revoke their access?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteWorker(worker.id);
      await _loadWorkers();
    } catch (error) {
      _showMessage('Could not delete shopkeeper: $error');
    }
  }

  String _lastLogin(Worker worker) {
    final lastLogin = worker.lastLoginAt;
    if (lastLogin == null) return 'Never signed in';
    return 'Last login: ${lastLogin.toLocal().toString().substring(0, 16)}';
  }

  Widget _workerCard(Worker worker) {
    final enabledPermissions = worker.permissions.entries
        .where(
            (entry) => entry.value && _permissionLabels.containsKey(entry.key))
        .map((entry) => _permissionLabels[entry.key]!)
        .toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      AppTheme.primaryGreen.withValues(alpha: 0.12),
                  child: Text(
                    worker.name.isEmpty ? '?' : worker.name[0].toUpperCase(),
                    style: const TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(worker.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      if (worker.phone.isNotEmpty) Text(worker.phone),
                      Text(_lastLogin(worker),
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                Switch(
                  value: worker.isActive,
                  onChanged: (value) => _setActive(worker, value),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: enabledPermissions
                    .map(
                      (label) => Chip(
                        label:
                            Text(label, style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ),
            const Divider(),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showWorkerForm(worker: worker),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: () => _regenerateCode(worker),
                  icon: const Icon(Icons.autorenew, size: 18),
                  label: const Text('New code'),
                ),
                TextButton.icon(
                  onPressed: () => _deleteWorker(worker),
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: AppTheme.dangerRed),
                  label: const Text('Delete',
                      style: TextStyle(color: AppTheme.dangerRed)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _workers.where((worker) => worker.isActive).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker Management'),
        actions: [
          IconButton(
            tooltip: 'Refresh workers',
            onPressed: _isLoading ? null : _loadWorkers,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : () => _showWorkerForm(),
        backgroundColor: AppTheme.primaryGreen,
        icon: const Icon(Icons.add, color: Colors.white),
        label:
            const Text('Add Shopkeeper', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const LoadingStateView(message: 'Loading shopkeepers...')
          : _errorMessage != null && _workers.isEmpty
              ? ErrorStateView(message: _errorMessage!, onRetry: _loadWorkers)
              : _workers.isEmpty
                  ? const EmptyStateView(
                      title: 'No shopkeepers yet',
                      message:
                          'Add a shopkeeper to create a one-time sign-in code.',
                      icon: Icons.badge_outlined,
                    )
                  : RefreshIndicator(
                      onRefresh: _loadWorkers,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.primaryGreen.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppTheme.primaryGreen
                                      .withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.badge_outlined,
                                    color: AppTheme.primaryGreen, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '${_workers.length} shopkeepers • $activeCount active',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ..._workers.map(_workerCard),
                        ],
                      ),
                    ),
    );
  }
}
