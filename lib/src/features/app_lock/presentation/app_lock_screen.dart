import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers.dart';
import '../../shared/repositories.dart';

/// Wraps [child] (normally HomeScreen) behind a PIN gate when app lock is
/// enabled. Re-locks automatically after the app has been backgrounded for
/// more than [relockAfter] — briefly switching apps (e.g. to read an SMS)
/// doesn't force a re-entry, but leaving the phone idle or handing it to
/// someone else does.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  static const _relockAfter = Duration(seconds: 20);

  bool _unlocked = false;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _backgroundedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final since = _backgroundedAt;
      _backgroundedAt = null;
      if (since != null && DateTime.now().difference(since) > _relockAfter) {
        if (mounted) setState(() => _unlocked = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockEnabled = ref.watch(appLockEnabledProvider);

    return lockEnabled.when(
      data: (enabled) {
        if (!enabled || _unlocked) return widget.child;
        return AppLockScreen(
          onUnlocked: () => setState(() => _unlocked = true),
        );
      },
      // Fail open on load error/loading rather than stranding the user on a
      // blank screen — the gate re-evaluates the instant the provider settles.
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (_, _) => widget.child,
    );
  }
}

class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key, required this.onUnlocked});
  final VoidCallback onUnlocked;

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  final _code = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = ref.read(stringsProvider);
    setState(() { _busy = true; _error = null; });
    try {
      final ok = await ref
          .read(settingsRepositoryProvider)
          .verifyAppLock(_code.text.trim());
      if (ok) {
        widget.onUnlocked();
      } else {
        setState(() => _error = s.appLockWrongCode);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_person,
                      size: 48, color: cs.onPrimaryContainer),
                ),
                const SizedBox(height: 20),
                Text(s.settingsAppLock,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(s.appLockSubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.outline)),
                const SizedBox(height: 28),
                TextField(
                  controller: _code,
                  obscureText: _obscure,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  onSubmitted: (_) => _busy ? null : _submit(),
                  decoration: InputDecoration(
                    hintText: s.appLockEnterCode,
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: TextStyle(color: cs.error)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(s.appLockUnlock),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
