import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../licensing/license_controller.dart';
import '../licensing/license_status.dart';

class LicenseScreen extends StatefulWidget {
  const LicenseScreen({required this.controller, super.key});

  final LicenseController controller;

  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  final TextEditingController _licenseController = TextEditingController();
  final TextEditingController _businessNameController =
      TextEditingController();
  bool _editingLicense = false;

  @override
  void initState() {
    super.initState();
    final savedName = widget.controller.license?.businessName.trim() ?? '';
    if (savedName.isNotEmpty) _businessNameController.text = savedName;
  }

  @override
  void dispose() {
    _licenseController.dispose();
    _businessNameController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final activated = await widget.controller.activate(
      licenseKey: _licenseController.text,
      businessName: _businessNameController.text,
    );
    if (!mounted || !activated) return;
    _licenseController.clear();
    setState(() => _editingLicense = false);
  }

  Future<void> _startTrial() async {
    await widget.controller.startTrial(
      businessName: _businessNameController.text,
    );
  }

  Future<void> _deactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate this device?'),
        content: const Text(
          'This releases the licence from this computer. Existing business records remain unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final deactivated = await widget.controller.deactivate();
    if (!mounted || !deactivated) return;
    setState(() => _editingLicense = true);
  }

  Future<void> _openSupport() async {
    final uri = Uri.parse('https://www.airmonlink.com/contact');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the support page.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final status = widget.controller.status;
        final loading = widget.controller.isLoading;
        final showActivationForm = !status.isPaidLicense || _editingLicense;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.workspace_premium,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Commercial licence control',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _subtitle(status),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (loading) const LinearProgressIndicator(),
                      const SizedBox(height: 12),
                      _StatusPanel(status: status),
                      if (widget.controller.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        _ErrorMessage(
                          message: widget.controller.errorMessage!,
                        ),
                      ],
                      if (status.isPaidLicense && !_editingLicense) ...[
                        const SizedBox(height: 20),
                        _LicenceDetails(
                          status: status,
                          customer: widget.controller.license?.customer ?? '',
                          businessName:
                              widget.controller.license?.businessName ?? '',
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            OutlinedButton.icon(
                              onPressed: loading
                                  ? null
                                  : () {
                                      final savedName = widget
                                              .controller
                                              .license
                                              ?.businessName
                                              .trim() ??
                                          '';
                                      if (_businessNameController
                                              .text
                                              .trim()
                                              .isEmpty &&
                                          savedName.isNotEmpty) {
                                        _businessNameController.text =
                                            savedName;
                                      }
                                      setState(() => _editingLicense = true);
                                    },
                              icon: const Icon(Icons.swap_horiz_outlined),
                              label: const Text('Change licence'),
                            ),
                            OutlinedButton.icon(
                              onPressed: loading ? null : _deactivate,
                              icon: const Icon(Icons.link_off_outlined),
                              label: const Text('Deactivate licence'),
                            ),
                            OutlinedButton.icon(
                              onPressed: loading
                                  ? null
                                  : widget.controller.refresh,
                              icon: const Icon(Icons.refresh_outlined),
                              label: const Text('Validate now'),
                            ),
                          ],
                        ),
                      ],
                      if (showActivationForm) ...[
                        const SizedBox(height: 20),
                        _ActivationForm(
                          businessNameController: _businessNameController,
                          licenseController: _licenseController,
                          loading: loading,
                          showCancel: status.isPaidLicense,
                          onActivate: _activate,
                          onCancel: () => setState(
                            () {
                              _editingLicense = false;
                              _licenseController.clear();
                            },
                          ),
                        ),
                        if (status.canStartTrial) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: loading ? null : _startTrial,
                            icon: const Icon(Icons.timer_outlined),
                            label: const Text('Start one-time 14-day trial'),
                          ),
                        ],
                      ],
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: loading ? null : _openSupport,
                        icon: const Icon(Icons.support_agent_outlined),
                        label: const Text('Contact support'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _subtitle(LicenseStatus status) {
    if (status.isPaidLicense) {
      return 'Your paid licence is active. Licence details are shown below.';
    }
    if (status.state == LicenseState.trial) {
      return 'Your one-time trial is active. Enter a paid key whenever you are ready to upgrade.';
    }
    if (status.state == LicenseState.expired && status.plan == 'trial') {
      return 'The one-time trial has ended. Activate a paid licence to continue using restricted features.';
    }
    return 'Activate a paid licence or begin the one-time 14-day trial.';
  }
}

class _ActivationForm extends StatelessWidget {
  const _ActivationForm({
    required this.businessNameController,
    required this.licenseController,
    required this.loading,
    required this.showCancel,
    required this.onActivate,
    required this.onCancel,
  });

  final TextEditingController businessNameController;
  final TextEditingController licenseController;
  final bool loading;
  final bool showCancel;
  final VoidCallback onActivate;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          showCancel ? 'Replace the current licence' : 'Activate a licence',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: businessNameController,
          enabled: !loading,
          decoration: const InputDecoration(
            labelText: 'Business or organisation name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: licenseController,
          enabled: !loading,
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Licence key',
            hintText: 'ABM-XXXXX-XXXXX-XXXXX-XXXXX',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: loading ? null : onActivate,
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text('Activate licence'),
            ),
            if (showCancel)
              TextButton(onPressed: loading ? null : onCancel, child: const Text('Cancel')),
          ],
        ),
      ],
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.status});

  final LicenseStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status.state) {
      LicenseState.active => Colors.green,
      LicenseState.gracePeriod => Colors.orange,
      LicenseState.trial => Colors.blue,
      LicenseState.activationRequired => Colors.blueGrey,
      LicenseState.expired => Colors.red,
      LicenseState.suspended => Colors.orange,
      LicenseState.revoked => Colors.red,
      LicenseState.deactivated => Colors.blueGrey,
      LicenseState.invalid => Colors.red,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, color: color, size: 12),
              const SizedBox(width: 8),
              Text(
                status.displayLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(status.message),
          if (status.plan != 'none') ...[
            const SizedBox(height: 8),
            Text('Plan: ${_title(status.plan)}'),
          ],
          if (status.expiresAt != null) ...[
            const SizedBox(height: 4),
            Text('Valid until: ${_date(status.expiresAt!)}'),
          ],
          if (status.isRestricted) ...[
            const SizedBox(height: 8),
            Text(
              'Restricted mode is active. Existing records remain available.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _LicenceDetails extends StatelessWidget {
  const _LicenceDetails({
    required this.status,
    required this.customer,
    required this.businessName,
  });

  final LicenseStatus status;
  final String customer;
  final String businessName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE5F2)),
      ),
      child: Wrap(
        spacing: 32,
        runSpacing: 12,
        children: [
          _Detail(label: 'Plan', value: _title(status.plan)),
          if (businessName.trim().isNotEmpty)
            _Detail(label: 'Business', value: businessName),
          if (customer.trim().isNotEmpty)
            _Detail(label: 'Customer', value: customer),
          if (status.expiresAt != null)
            _Detail(label: 'Valid until', value: _date(status.expiresAt!)),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    );
  }
}

String _date(DateTime value) {
  final local = value.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _title(String value) {
  if (value.isEmpty) return value;
  return value
      .split(RegExp(r'[_\s-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
