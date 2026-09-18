import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/security/emergency_code_hasher.dart';
import '../../shared/providers.dart';
import '../../trusted_contacts/domain/trusted_contact.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});
  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _primaryName = TextEditingController();
  final _primaryPhone = TextEditingController();
  bool _showCode = false;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _primaryName.dispose();
    _primaryPhone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = ref.read(stringsProvider);
    setState(() { _busy = true; _error = null; });
    try {
      if (_phone.text.trim().isEmpty || _primaryPhone.text.trim().isEmpty) {
        throw Exception(s.isAr
            ? 'أدخل رقم هاتفك والرقم الأساسي الموثوق.'
            : 'Enter your phone number and the primary trusted number.');
      }
      if (!EmergencyCodeHasher.isValidFormat(_code.text.trim())) {
        throw Exception(s.errCodeInvalid);
      }
      await [
        Permission.sms,
        Permission.location,
        Permission.locationAlways,
        Permission.phone,
        Permission.notification,
      ].request();
      final settings = ref.read(settingsRepositoryProvider);
      await settings.savePhone(_phone.text);
      await settings.saveEmergencyCode(_code.text.trim());
      await ref.read(contactsRepositoryProvider).add(
            _primaryName.text,
            _primaryPhone.text,
            TrustedContactRole.primary,
          );
      await settings.captureSimBaseline();
      await ref.read(locationCaptureProvider).capture();
      if (mounted) await _offerDeviceAdmin();
      ref.invalidate(setupCompleteProvider);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Invites the user to activate anti-uninstall protection right after
  /// setup — this is the moment they're most engaged with security, and the
  /// single most impactful step against a casual thief. Declining here is
  /// fine; the same action is always available later from Settings.
  Future<void> _offerDeviceAdmin() async {
    final s = ref.read(stringsProvider);
    final activate = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.admin_panel_settings, size: 32),
        title: Text(s.settingsDeviceAdmin),
        content: Text(s.deviceAdminDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.onboardSkip),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.activateDeviceAdmin),
          ),
        ],
      ),
    );
    if (activate == true && mounted) {
      try {
        await ref
            .read(nativeBridgeProvider)
            .requestDeviceAdminActivation()
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // Non-fatal: the user can still activate it later from Settings —
        // don't block setup completion on this optional step.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 20),
            // Logo
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.phone_android,
                    size: 52, color: cs.onPrimaryContainer),
              ),
            ),
            const SizedBox(height: 16),
            Text(s.appName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold)),
            Text(s.tagline,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.outline)),
            const SizedBox(height: 32),

            // Device phone
            Text(s.isAr ? 'رقم هذا الجهاز' : 'This device number',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: cs.outline)),
            const SizedBox(height: 6),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: s.contactPhoneHint,
                prefixIcon: const Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 16),

            // Emergency code
            Text(s.settingsEmergencyCode,
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: cs.outline)),
            const SizedBox(height: 6),
            TextField(
              controller: _code,
              obscureText: !_showCode,
              decoration: InputDecoration(
                hintText: s.codeHint,
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_showCode
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () => setState(() => _showCode = !_showCode),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Primary contact
            Text(s.isAr ? 'جهة الاتصال الأساسية' : 'Primary trusted contact',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: cs.outline)),
            const SizedBox(height: 6),
            TextField(
              controller: _primaryName,
              decoration: InputDecoration(
                labelText: s.contactName,
                prefixIcon: const Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _primaryPhone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: s.contactPhone,
                hintText: s.contactPhoneHint,
                prefixIcon: const Icon(Icons.phone),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(_error!,
                    style: TextStyle(color: cs.onErrorContainer)),
              ),
            ],

            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.security),
              label: Text(s.isAr
                  ? 'حفظ وتفعيل الحماية'
                  : 'Save & Activate Protection'),
            ),
          ],
        ),
      ),
    );
  }
}
