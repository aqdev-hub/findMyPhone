import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../shared/providers.dart';

// Sampled directly from the reference design's pixels.
const _kTitleColor = Color(0xFF14152B); // near-black, not navy
const _kSubtitleColor = Color(0xFF6B7686); // blue-gray, not neutral gray

/// Onboarding screen shown once before setup — three swipeable pages that
/// introduce the app's protection, SMS-command, and pre-loss-preparation
/// features, matching the provided reference design pixel-for-pixel in
/// structure: illustration → title/subtitle → dot indicator → CTA button.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _green = Color(0xFF018C77);
  static const _purple = Color(0xFF6E58E2);

  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    // Marks onboarding as seen and invalidates onboardingCompleteProvider.
    // FindMyPhoneApp watches that provider and swaps MaterialApp.home to
    // SetupScreen/HomeScreen reactively — same pattern SetupScreen uses to
    // hand off to HomeScreen after setup completes, so no manual push here.
    await markOnboardingComplete(ref);
  }

  void _next() {
    if (_index == 2) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final accent = _index == 1 ? _purple : _green;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip ─────────────────────────────────────────────────────
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: _index < 2
                    ? TextButton(
                        onPressed: _finish,
                        child: Text(
                          s.onboardSkip,
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.4),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : const SizedBox(height: 40),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  _OnboardPage1(s: s),
                  _OnboardPage2(s: s, accent: _purple),
                  _OnboardPage3(s: s, accent: _green),
                ],
              ),
            ),
            // ── Dots ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? accent : const Color(0xFFE1E5EA),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            // ── CTA button ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _index == 2 ? s.onboardStart : s.onboardNext,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared page shell ───────────────────────────────────────────────────────
class _PageShell extends StatelessWidget {
  const _PageShell({required this.image, required this.child});
  final Widget image;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Expanded(flex: 5, child: Center(child: image)),
          const SizedBox(height: 12),
          Expanded(flex: 4, child: child),
        ],
      ),
    );
  }
}

// ── Page 1 — Protect your phone at all times ────────────────────────────────
class _OnboardPage1 extends StatelessWidget {
  const _OnboardPage1({required this.s});
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return _PageShell(
      image: Image.asset(
        'assets/images/onboarding/onboardingone.png',
        fit: BoxFit.contain,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            '${s.onboardTitle1Line1}\n${s.onboardTitle1Line2}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: _kTitleColor,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            s.onboardSubtitle1,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: _kSubtitleColor,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page 2 — Control your phone via SMS ──────────────────────────────────────
class _OnboardPage2 extends StatelessWidget {
  const _OnboardPage2({required this.s, required this.accent});
  final AppStrings s;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 4),
          // Header: icon + line 1, then line 2 below — matches the reference,
          // where the paper-plane icon sits only beside "تحكم بهاتفك" and
          // "عبر رسالة SMS" is its own centered line underneath.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.send_rounded, color: accent, size: 22),
              const SizedBox(width: 8),
              Text(
                s.onboardTitle2Line1,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _kTitleColor,
                ),
              ),
            ],
          ),
          Text(
            s.onboardTitle2Line2,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _kTitleColor,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Center(
              child: Image.asset(
                'assets/images/onboarding/onboardingtwo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            s.onboardSubtitle2,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: _kSubtitleColor,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page 3 — Get ready before you lose your phone ───────────────────────────
class _OnboardPage3 extends StatelessWidget {
  const _OnboardPage3({required this.s, required this.accent});
  final AppStrings s;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Column(
        children: [
          const SizedBox(height: 4),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
              children: [
                TextSpan(
                  text: s.onboardTitle3Line1,
                  style: const TextStyle(color: _kTitleColor),
                ),
                const TextSpan(text: '\n'),
                TextSpan(
                  text: s.onboardTitle3Line2,
                  style: TextStyle(color: accent),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Image.asset(
                'assets/images/onboarding/onboardingthree.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          _OnboardListRow(icon: Icons.person_rounded, text: s.onboardItem1, accent: accent),
          const SizedBox(height: 8),
          _OnboardListRow(icon: Icons.lock_rounded, text: s.onboardItem2, accent: accent),
          const SizedBox(height: 8),
          _OnboardListRow(icon: Icons.sim_card_rounded, text: s.onboardItem3, accent: accent),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, size: 13, color: _kSubtitleColor),
              const SizedBox(width: 5),
              Text(
                s.onboardFooterSecure,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: _kSubtitleColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OnboardListRow extends StatelessWidget {
  const _OnboardListRow({
    required this.icon,
    required this.text,
    required this.accent,
  });
  final IconData icon;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: Color(0xFF33415C)),
          ),
        ),
      ],
    );
  }
}
