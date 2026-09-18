import 'dart:async';

import 'package:find_my_phone/src/features/location/domain/known_location.dart';
import 'package:find_my_phone/src/features/shared/repositories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/security/emergency_code_hasher.dart';
import '../../../core/sms/emergency_command.dart';
import '../../shared/providers.dart';
import '../../trusted_contacts/domain/trusted_contact.dart';

// ── Extensions ────────────────────────────────────────────────────────────────
extension on BuildContext {
  AppStrings get s => ProviderScope.containerOf(this).read(stringsProvider);
}

// ── Root ──────────────────────────────────────────────────────────────────────
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  var _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _drainPendingLogs());
  }

  Future<void> _drainPendingLogs() async {
    try {
      final bridge = ref.read(nativeBridgeProvider);
      final logs = await bridge.getPendingNativeLogs();
      if (logs.isEmpty) return;
      final logRepo = ref.read(auditLogRepositoryProvider);
      for (final log in logs) {
        await logRepo.add(log.type, log.message);
      }
      await bridge.clearPendingNativeLogs();
      ref.invalidate(logsProvider);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final pages = [
      const _DashboardPage(),
      const _ContactsPage(),
      const _LogsPage(),
      const _SettingsPage(),
    ];

    return Scaffold(
      key: ref.watch(scaffoldKeyProvider),
      drawer: _AppDrawer(),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (v) => setState(() => _index = v),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.location_on_outlined),
            selectedIcon: const Icon(Icons.location_on),
            label: s.navDashboard,
          ),
          NavigationDestination(
            icon: const Icon(Icons.contacts_outlined),
            selectedIcon: const Icon(Icons.contacts),
            label: s.navContacts,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history),
            label: s.navLogs,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: s.navSettings,
          ),
        ],
      ),
    );
  }
}

// ── App Drawer ────────────────────────────────────────────────────────────────
class _AppDrawer extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Drawer(
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.primary.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.phone_android,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  s.appName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  s.tagline,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _DrawerItem(
                  icon: Icons.info_outline,
                  label: s.drawerAbout,
                  onTap: () {
                    Navigator.pop(context);
                    _showAbout(context, s);
                  },
                ),
                _DrawerItem(
                  icon: Icons.help_outline,
                  label: s.drawerHelp,
                  onTap: () {
                    Navigator.pop(context);
                    _showHelp(context, s);
                  },
                ),
                _DrawerItem(
                  icon: Icons.email_outlined,
                  label: s.drawerContact,
                  onTap: () {
                    Navigator.pop(context);
                    launchUrl(
                      Uri.parse(
                        'mailto:support@aqdev.app?subject=${Uri.encodeComponent(s.appName)}',
                      ),
                    );
                  },
                ),
                _DrawerItem(
                  icon: Icons.share_outlined,
                  label: s.drawerShare,
                  onTap: () {
                    Navigator.pop(context);
                    SharePlus.instance.share(
                      ShareParams(
                        text: s.isAr
                            ? 'جرّب تطبيق "اعثر على هاتفي" للحماية عبر SMS:\nhttps://abdulquddus-dev.github.io/project/find-my-phone/'
                            : 'Try "Find My Phone" — SMS-based protection:\nhttps://abdulquddus-dev.github.io/project/find-my-phone/',
                        subject: s.appName,
                      ),
                    );
                  },
                ),
                _DrawerItem(
                  icon: Icons.apps_outlined,
                  label: s.drawerOurApps,
                  onTap: () {
                    Navigator.pop(context);
                    launchUrl(Uri.parse('https://abdulquddus-dev.github.io/'));
                  },
                ),

                const Divider(indent: 16, endIndent: 16),

                // Language
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.language, size: 22),
                      const SizedBox(width: 16),
                      Text(
                        s.drawerLanguage,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'ar',
                            label: Text(s.languageArabic),
                          ),
                          ButtonSegment(
                            value: 'en',
                            label: Text(s.languageEnglish),
                          ),
                        ],
                        selected: {s.locale},
                        onSelectionChanged: (v) {
                          ref.read(localeProvider.notifier).state = Locale(
                            v.first,
                          );
                        },
                        style: ButtonStyle(
                          textStyle: WidgetStateProperty.all(
                            const TextStyle(fontSize: 11),
                          ),
                          padding: WidgetStateProperty.all(
                            const EdgeInsets.symmetric(horizontal: 6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Dark mode
                SwitchListTile(
                  secondary: Icon(
                    isDark
                        ? Icons.nights_stay_outlined
                        : Icons.wb_sunny_outlined,
                  ),
                  title: Text(s.drawerDarkMode),
                  value:
                      themeMode == ThemeMode.dark ||
                      (themeMode == ThemeMode.system && isDark),
                  onChanged: (v) {
                    ref.read(themeModeProvider.notifier).state = v
                        ? ThemeMode.dark
                        : ThemeMode.light;
                  },
                ),
              ],
            ),
          ),

          // Version footer
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${s.version} 1.1.0 — AQ Dev',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.outline),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context, AppStrings s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(s.aboutTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.aboutDesc),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => launchUrl(
                Uri.parse('https://abdulquddus-dev.github.io/project/find-my-phone/'),
              ),
              child: Text(
                s.isAr ? 'صفحة التطبيق' : 'App page',
                style: const TextStyle(
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.close),
          ),
        ],
      ),
    );
  }

  /// Bilingual command label, e.g. "LOCATE / موقع [code]" (both keywords work).
  String _cmdLabel(EmergencyCommandType type, AppStrings s) {
    final (en, ar) = EmergencyCommandParser.keywordsFor(type);
    final code = s.isAr ? '[رمز]' : '[code]';
    return '$en / $ar $code';
  }

  void _showHelp(BuildContext context, AppStrings s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(s.drawerHelp),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HelpRow(_cmdLabel(EmergencyCommandType.locate, s), s.cmdLocate),
              _HelpRow(
                _cmdLabel(EmergencyCommandType.silentLocate, s),
                s.cmdSilent,
              ),
              _HelpRow(_cmdLabel(EmergencyCommandType.alarm, s), s.cmdAlarm),
              _HelpRow(_cmdLabel(EmergencyCommandType.info, s), s.cmdInfo),
              _HelpRow(_cmdLabel(EmergencyCommandType.lock, s), s.cmdLock),
              _HelpRow(_cmdLabel(EmergencyCommandType.resetCode, s), s.cmdReset),
              _HelpRow(_cmdLabel(EmergencyCommandType.liveTrack, s), s.cmdLiveTrack),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.close),
          ),
        ],
      ),
    );
  }
}

class _HelpRow extends StatelessWidget {
  const _HelpRow(this.command, this.desc);
  final String command;
  final String desc;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              command,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(label),
      onTap: onTap,
      dense: true,
    );
  }
}

// ── Dashboard ─────────────────────────────────────────────────────────────────
class _DashboardPage extends ConsumerStatefulWidget {
  const _DashboardPage();
  @override
  ConsumerState<_DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<_DashboardPage> {
  bool _updatingLocation = false;
  bool _stoppingAlarm = false;
  bool _showMap = false;
  final MapController _mapCtrl = MapController();
  ll.LatLng? _liveMarker;
  StreamSubscription<dynamic>? _positionSub;

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _refreshLocation() async {
    setState(() => _updatingLocation = true);
    try {
      final captureService = ref.read(locationCaptureProvider);
      final location = await captureService.capture();
      ref.invalidate(lastLocationProvider);
      ref.invalidate(logsProvider);
      if (location != null) {
        if (_showMap) {
          final latlng = ll.LatLng(location.latitude, location.longitude);
          setState(() => _liveMarker = null);
          try {
            _mapCtrl.move(latlng, 16);
          } catch (_) {
            // Map may not be mounted yet — safe to ignore.
          }
        }
      } else if (mounted) {
        // Previously this silently did nothing on total failure — now shows
        // the precise reason (permission/service/provider exception) so a
        // device-specific failure can actually be diagnosed from the log
        // instead of just looking like an unresponsive button.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${context.s.locationFailed}\n${captureService.lastFailureReason ?? ""}',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.s.locationFailed}\n$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingLocation = false);
    }
  }

  void _startLiveTracking({bool useLocationManager = false}) {
    _positionSub?.cancel();
    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.high,
            // Wider filter + a minimum interval between updates means the
            // GPS chip can idle between fixes instead of staying continuously
            // active — live tracking still updates smoothly, just not at the
            // maximum possible rate a stolen-phone recovery doesn't need.
            distanceFilter: 25,
            intervalDuration: const Duration(seconds: 8),
            // FusedLocationProviderClient is significantly more
            // battery-efficient than raw GPS polling — but some devices
            // (especially budget/regional-market ones) have broken or
            // missing Google Play Services, where this would silently never
            // produce a single update. onError below detects that and
            // restarts the stream on the raw LocationManager instead.
            forceLocationManager: useLocationManager,
          ),
        ).listen(
          (pos) async {
            if (!mounted) return;
            final latlng = ll.LatLng(pos.latitude, pos.longitude);
            try {
              _mapCtrl.move(latlng, _mapCtrl.camera.zoom);
            } catch (_) {}
            setState(() => _liveMarker = latlng);
            // Save each position update to DB & native
            await ref
                .read(locationRepositoryProvider)
                .save(
                  KnownLocation(
                    latitude: pos.latitude,
                    longitude: pos.longitude,
                    source: LocationSource.gps,
                    createdAt: DateTime.now(),
                  ),
                );
          },
          onError: (Object _) {
            if (!mounted) return;
            if (!useLocationManager) {
              // Fused provider failed — retry once via the raw LocationManager.
              _startLiveTracking(useLocationManager: true);
            } else {
              setState(() => _positionSub = null);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.s.locationFailed)),
              );
            }
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final location = ref.watch(lastLocationProvider);
    final battery = ref.watch(batterySummaryProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.appName),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => ref.read(scaffoldKeyProvider).currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: _stoppingAlarm
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.alarm_off),
            tooltip: s.stopAlarm,
            onPressed: _stoppingAlarm
                ? null
                : () async {
                    setState(() => _stoppingAlarm = true);
                    try {
                      await ref
                          .read(nativeBridgeProvider)
                          .stopAlarm()
                          .timeout(const Duration(seconds: 5));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(s.stopAlarm)),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              s.isAr
                                  ? 'تعذّر إيقاف الإنذار: $e'
                                  : 'Could not stop the alarm: $e',
                            ),
                            backgroundColor: Theme.of(context).colorScheme.error,
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _stoppingAlarm = false);
                    }
                  },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshLocation,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            const _LiveTrackingBanner(),
            // ── Location card ─────────────────────────────────────────────
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CardHeader(
                    icon: Icons.location_on,
                    title: s.lastKnownLocation,
                  ),
                  const SizedBox(height: 10),
                  location.when(
                    data: (loc) {
                      if (loc == null) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            s.noLocationYet,
                            style: TextStyle(color: cs.outline),
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.gps_fixed,
                                size: 14,
                                color: cs.primary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${loc.latitude.toStringAsFixed(6)}, ${loc.longitude.toStringAsFixed(6)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${s.source}: ${_sourceLabel(loc.source, s)}  ·  ${DateFormat('dd/MM/yyyy HH:mm').format(loc.createdAt)}',
                            style: TextStyle(fontSize: 12, color: cs.outline),
                          ),
                          const SizedBox(height: 10),
                          // Map toggle — free OpenStreetMap tiles via flutter_map,
                          // no API key or billing account required.
                          if (_showMap)
                            SizedBox(
                              height: 220,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: FlutterMap(
                                  mapController: _mapCtrl,
                                  options: MapOptions(
                                    initialCenter: ll.LatLng(
                                      loc.latitude,
                                      loc.longitude,
                                    ),
                                    initialZoom: 16,
                                    interactionOptions: const InteractionOptions(
                                      flags: InteractiveFlag.all &
                                          ~InteractiveFlag.rotate,
                                    ),
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName:
                                          'com.findmyphone.find_my_phone',
                                      maxNativeZoom: 19,
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          point: _liveMarker ??
                                              ll.LatLng(
                                                loc.latitude,
                                                loc.longitude,
                                              ),
                                          width: 40,
                                          height: 40,
                                          child: Icon(
                                            Icons.location_on,
                                            color: _liveMarker != null
                                                ? Colors.blue
                                                : cs.primary,
                                            size: 40,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const RichAttributionWidget(
                                      attributions: [
                                        TextSourceAttribution(
                                          '© OpenStreetMap contributors',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: () =>
                                    setState(() => _showMap = !_showMap),
                                icon: Icon(
                                  _showMap ? Icons.map : Icons.map_outlined,
                                  size: 16,
                                ),
                                label: Text(_showMap ? s.close : s.openMap),
                              ),
                              if (_showMap)
                                OutlinedButton.icon(
                                  onPressed: () {
                                    if (_positionSub != null) {
                                      _positionSub?.cancel();
                                      _positionSub = null;
                                      setState(() {});
                                    } else {
                                      _startLiveTracking();
                                      setState(() {});
                                    }
                                  },
                                  icon: Icon(
                                    _positionSub != null
                                        ? Icons.location_searching
                                        : Icons.location_disabled,
                                    size: 16,
                                  ),
                                  label: Text(
                                    _positionSub != null
                                        ? s.liveTracking
                                        : s.liveTracking,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _positionSub != null
                                        ? Colors.green
                                        : cs.outline,
                                  ),
                                ),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    launchUrl(Uri.parse(loc.mapsUrl)),
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text('Google Maps'),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) =>
                        Text('خطأ: $e', style: TextStyle(color: cs.error)),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _updatingLocation ? null : _refreshLocation,
                    icon: _updatingLocation
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.my_location, size: 18),
                    label: Text(
                      _updatingLocation ? s.locationUpdating : s.updateLocation,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Battery card ──────────────────────────────────────────────
            _Card(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Icon(
                    Icons.battery_charging_full,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                title: Text(s.battery),
                trailing: battery.when(
                  data: (v) => Text(
                    v,
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  loading: () => const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, _) => const Text('—'),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── SMS Commands guide ─────────────────────────────────────────
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CardHeader(icon: Icons.sms, title: s.smsCommands),
                  const SizedBox(height: 10),
                  ...[
                    (EmergencyCommandType.locate, s.cmdLocate),
                    (EmergencyCommandType.silentLocate, s.cmdSilent),
                    (EmergencyCommandType.alarm, s.cmdAlarm),
                    (EmergencyCommandType.info, s.cmdInfo),
                    (EmergencyCommandType.lock, s.cmdLock),
                    (EmergencyCommandType.resetCode, s.cmdReset),
                    (EmergencyCommandType.liveTrack, s.cmdLiveTrack),
                  ].map((cmd) {
                    final (en, ar) = EmergencyCommandParser.keywordsFor(cmd.$1);
                    final label = s.isAr ? '$en / $ar' : en;
                    return _CmdRow(label, cmd.$2, cs);
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sourceLabel(LocationSource src, AppStrings s) => switch (src) {
    LocationSource.gps => s.sourceGps,
    LocationSource.approximate => s.sourceApprox,
    LocationSource.lastKnown => s.sourceLast,
  };
}

class _CmdRow extends StatelessWidget {
  const _CmdRow(this.cmd, this.desc, this.cs);
  final String cmd;
  final String desc;
  final ColorScheme cs;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              cmd,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(desc, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

// ── Contacts ──────────────────────────────────────────────────────────────────
class _ContactsPage extends ConsumerStatefulWidget {
  const _ContactsPage();
  @override
  ConsumerState<_ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends ConsumerState<_ContactsPage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  var _role = TrustedContactRole.additional;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final s = ref.read(stringsProvider);
    try {
      await ref
          .read(contactsRepositoryProvider)
          .add(_name.text, _phone.text, _role);
      _name.clear();
      _phone.clear();
      ref.invalidate(contactsProvider);
      ref.invalidate(setupCompleteProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.add)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final contacts = ref.watch(contactsProvider);
    final limit = ref.watch(contactsLimitProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => ref.read(scaffoldKeyProvider).currentState?.openDrawer(),
        ),
        title: Text(s.trustedContacts),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Role legend
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardHeader(icon: Icons.badge, title: s.contactRole),
                const SizedBox(height: 8),
                ...TrustedContactRole.values.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(_roleIcon(r), size: 16, color: _roleColor(r, cs)),
                        const SizedBox(width: 8),
                        Text(
                          '${_roleLabel(r, s)}: ',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _roleDesc(r, s),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Add form
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CardHeader(icon: Icons.person_add, title: s.addContact),
                const SizedBox(height: 12),
                TextField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: s.contactName,
                    prefixIcon: const Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: s.contactPhone,
                    hintText: s.contactPhoneHint,
                    prefixIcon: const Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<TrustedContactRole>(
                  initialValue: _role,
                  decoration: InputDecoration(
                    labelText: s.contactRole,
                    prefixIcon: const Icon(Icons.badge),
                  ),
                  items: TrustedContactRole.values
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(_roleLabel(r, s)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(
                    () => _role = v ?? TrustedContactRole.additional,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(s.add),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // List
          contacts.when(
            data: (items) {
              if (items.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      s.noContacts,
                      style: TextStyle(color: cs.outline),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  limit.whenOrNull(
                        data: (max) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '${items.length} ${s.ofMax} $max',
                            style: TextStyle(color: cs.outline, fontSize: 12),
                          ),
                        ),
                      ) ??
                      const SizedBox.shrink(),
                  ...items.map(
                    (c) => _Card(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: _roleColor(
                            c.role,
                            cs,
                          ).withValues(alpha: 0.15),
                          child: Icon(
                            _roleIcon(c.role),
                            color: _roleColor(c.role, cs),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          c.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${c.phone}  ·  ${_roleLabel(c.role, s)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, color: cs.error),
                          onPressed: () async {
                            final ok = await _confirmDelete(context, c.name, s);
                            if (!ok) return;
                            try {
                              await ref
                                  .read(contactsRepositoryProvider)
                                  .delete(c.id);
                              ref.invalidate(contactsProvider);
                              ref.invalidate(setupCompleteProvider);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      e.toString().replaceFirst('Exception: ', ''),
                                    ),
                                    backgroundColor:
                                        Theme.of(context).colorScheme.error,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('خطأ: $e'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(
    BuildContext context,
    String name,
    AppStrings s,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(s.deleteContact),
            content: Text('${s.deleteConfirm} "$name"؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(s.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(s.delete),
              ),
            ],
          ),
        ) ??
        false;
  }
}

// ── Logs ──────────────────────────────────────────────────────────────────────
class _LogsPage extends ConsumerWidget {
  const _LogsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final logs = ref.watch(logsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => ref.read(scaffoldKeyProvider).currentState?.openDrawer(),
        ),
        title: Text(s.securityLog),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(logsProvider),
          ),
        ],
      ),
      body: logs.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(s.noLogs, style: TextStyle(color: cs.outline)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
            itemBuilder: (_, i) {
              final log = items[i];
              final color = _logColor(log.type, cs);
              return ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(_logIcon(log.type), size: 16, color: color),
                ),
                title: Text(log.message, style: const TextStyle(fontSize: 13)),
                subtitle: Text(
                  '${log.type}  ·  ${DateFormat('dd/MM HH:mm:ss').format(log.createdAt)}',
                  style: TextStyle(fontSize: 11, color: cs.outline),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
      ),
    );
  }

  IconData _logIcon(String type) => switch (type) {
    'sms_accepted' => Icons.check_circle,
    'sms_rejected' => Icons.cancel,
    'sms_ignored' => Icons.do_not_disturb,
    'alarm' => Icons.alarm,
    'locate' || 'silentlocate' => Icons.location_on,
    'info' => Icons.info,
    'sim_change' => Icons.sim_card_alert,
    'boot' => Icons.power_settings_new,
    'location' => Icons.gps_fixed,
    _ => Icons.history,
  };

  Color _logColor(String type, ColorScheme cs) {
    if (type.contains('error') || type.contains('rejected')) return cs.error;
    if (type == 'sms_accepted' || type == 'locate' || type == 'alarm') {
      return cs.primary;
    }
    if (type == 'sim_change') return Colors.orange;
    return cs.outline;
  }
}

// ── Settings ──────────────────────────────────────────────────────────────────
class _SettingsPage extends ConsumerWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => ref.read(scaffoldKeyProvider).currentState?.openDrawer(),
        ),
        title: Text(s.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: const [
          _CodeSection(),
          SizedBox(height: 10),
          _AppLockSection(),
          SizedBox(height: 10),
          _FeaturesSection(),
          SizedBox(height: 10),
          _SimGuardSection(),
          SizedBox(height: 10),
          _DeviceAdminSection(),
          SizedBox(height: 10),
          _BatterySection(),
          SizedBox(height: 10),
          _AutoStartSection(),
          SizedBox(height: 10),
          _PermissionsSection(),
          SizedBox(height: 10),
          _TestSection(),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Settings sections (collapsible) ──────────────────────────────────────────

class _CodeSection extends ConsumerStatefulWidget {
  const _CodeSection();
  @override
  ConsumerState<_CodeSection> createState() => _CodeSectionState();
}

class _CodeSectionState extends ConsumerState<_CodeSection> {
  final _cur = TextEditingController();
  final _new = TextEditingController();
  final _cnf = TextEditingController();
  bool _show = false;
  bool _busy = false;
  String? _err;
  String? _ok;

  @override
  void dispose() {
    _cur.dispose();
    _new.dispose();
    _cnf.dispose();
    super.dispose();
  }

  String _strength(String code) {
    if (code.length < 6) return 'short';
    int score = 0;
    if (RegExp(r'[a-z]').hasMatch(code)) score++;
    if (RegExp(r'[A-Z]').hasMatch(code)) score++;
    if (RegExp(r'[0-9]').hasMatch(code)) score++;
    if (code.length >= 10) score++;
    return ['weak', 'fair', 'fair', 'good', 'strong'][score.clamp(0, 4)];
  }

  Color _strengthColor(String s, ColorScheme cs) => switch (_strength(s)) {
    'short' || 'weak' => cs.error,
    'fair' => Colors.orange,
    'good' => Colors.amber.shade700,
    _ => Colors.green,
  };

  String _strengthLabel(String code, AppStrings s) => switch (_strength(code)) {
    'short' => s.strengthTooShort,
    'weak' => s.strengthWeak,
    'fair' => s.strengthFair,
    'good' => s.strengthGood,
    _ => s.strengthStrong,
  };

  Future<void> _change() async {
    final s = ref.read(stringsProvider);
    setState(() {
      _busy = true;
      _err = null;
      _ok = null;
    });
    try {
      if (_new.text != _cnf.text) throw Exception(s.errCodeMismatch);
      if (!EmergencyCodeHasher.isValidFormat(_new.text.trim())) {
        throw Exception(s.errCodeInvalid);
      }
      final settings = ref.read(settingsRepositoryProvider);
      final salt = await settings.read('code_salt') ?? '';
      final hash = await settings.read('code_hash') ?? '';
      if (salt.isNotEmpty && hash.isNotEmpty) {
        if (!EmergencyCodeHasher.verify(_cur.text.trim(), salt, hash)) {
          throw Exception(s.errCodeWrong);
        }
      }
      await settings.saveEmergencyCode(_new.text.trim());
      _cur.clear();
      _new.clear();
      _cnf.clear();
      setState(() => _ok = s.codeChanged);
    } catch (e) {
      setState(() => _err = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final cs = Theme.of(context).colorScheme;
    final newVal = _new.text;

    return _ExpandSection(
      icon: Icons.lock,
      title: s.settingsEmergencyCode,
      subtitle: s.settingsEmergencyCodeDesc,
      children: [
        TextField(
          controller: _cur,
          obscureText: !_show,
          decoration: InputDecoration(
            labelText: s.currentCode,
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _show = !_show),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _new,
          obscureText: !_show,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: s.newCode,
            prefixIcon: const Icon(Icons.lock_reset),
            helperText: s.codeHint,
          ),
        ),
        if (newVal.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const SizedBox(width: 14),
              SizedBox(
                width: 80,
                height: 6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (newVal.length / 12).clamp(0.0, 1.0),
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(
                      _strengthColor(newVal, cs),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${s.codeStrength}: ${_strengthLabel(newVal, s)}',
                style: TextStyle(
                  fontSize: 12,
                  color: _strengthColor(newVal, cs),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: _cnf,
          obscureText: !_show,
          decoration: InputDecoration(
            labelText: s.confirmCode,
            prefixIcon: const Icon(Icons.lock_clock),
          ),
        ),
        if (_err != null) ...[
          const SizedBox(height: 8),
          Text(_err!, style: TextStyle(color: cs.error, fontSize: 13)),
        ],
        if (_ok != null) ...[
          const SizedBox(height: 8),
          Text(_ok!, style: const TextStyle(color: Colors.green, fontSize: 13)),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ? null : _change,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check, size: 18),
          label: Text(s.changeCode),
        ),
      ],
    );
  }
}

class _FeaturesSection extends ConsumerWidget {
  const _FeaturesSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final alarm = ref.watch(alarmEnabledProvider);
    final alertAll = ref.watch(alertAllContactsProvider);

    return _ExpandSection(
      icon: Icons.tune,
      title: s.settingsFeatures,
      children: [
        alarm.when(
          data: (v) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.alarm),
            title: Text(s.alarmSound),
            subtitle: Text(s.alarmSoundDesc),
            value: v,
            onChanged: (val) async {
              await ref.read(settingsRepositoryProvider).setAlarmEnabled(val);
              ref.invalidate(alarmEnabledProvider);
            },
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
        ),
        const Divider(),
        alertAll.when(
          data: (v) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.group),
            title: Text(s.alertAllSim),
            subtitle: Text(s.alertAllSimDesc),
            value: v,
            onChanged: (val) async {
              await ref
                  .read(settingsRepositoryProvider)
                  .setAlertAllContactsOnSimChange(val);
              ref.invalidate(alertAllContactsProvider);
            },
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
        ),
      ],
    );
  }
}

class _SimGuardSection extends ConsumerWidget {
  const _SimGuardSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final simGuard = ref.watch(simGuardEnabledProvider);
    final cs = Theme.of(context).colorScheme;

    return _ExpandSection(
      icon: Icons.sim_card_alert,
      title: s.settingsSimGuard,
      subtitle: s.simGuardDesc,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.tertiaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            s.simGuardLimit,
            style: TextStyle(fontSize: 12, color: cs.onTertiaryContainer),
          ),
        ),
        const SizedBox(height: 8),
        simGuard.when(
          data: (v) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.security),
            title: Text(s.enableSimGuard),
            value: v,
            onChanged: (val) async {
              await ref
                  .read(settingsRepositoryProvider)
                  .setSimGuardEnabled(val);
              ref.invalidate(simGuardEnabledProvider);
            },
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: () async {
            try {
              await ref.read(settingsRepositoryProvider).captureSimBaseline();
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(s.simBaselineUpdated)));
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceFirst('Exception: ', '')),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            }
          },
          icon: const Icon(Icons.sim_card, size: 18),
          label: Text(s.updateSimBaseline),
        ),
      ],
    );
  }
}

class _AppLockSection extends ConsumerStatefulWidget {
  const _AppLockSection();
  @override
  ConsumerState<_AppLockSection> createState() => _AppLockSectionState();
}

class _AppLockSectionState extends ConsumerState<_AppLockSection> {
  bool _busy = false;

  Future<void> _toggle(bool value) async {
    setState(() => _busy = true);
    try {
      await ref.read(settingsRepositoryProvider).setAppLockEnabled(value);
      ref.invalidate(appLockEnabledProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setCustomPin() async {
    final s = ref.read(stringsProvider);
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(s.appLockSetCustomPin),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: s.appLockNewCode),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(s.appLockSave),
          ),
        ],
      ),
    );
    if (pin == null || pin.isEmpty || !mounted) return;
    try {
      await ref.read(settingsRepositoryProvider).setAppLockPin(pin);
      ref.invalidate(hasCustomAppLockPinProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.appLockPinSaved)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _useEmergencyCodeInstead() async {
    await ref.read(settingsRepositoryProvider).clearAppLockPin();
    ref.invalidate(hasCustomAppLockPinProvider);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final enabled = ref.watch(appLockEnabledProvider);
    final hasCustomPin = ref.watch(hasCustomAppLockPinProvider);

    return _ExpandSection(
      icon: Icons.lock_person,
      title: s.settingsAppLock,
      subtitle: s.appLockDesc,
      children: [
        enabled.when(
          data: (isEnabled) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.shield_moon),
                title: Text(s.appLockEnable),
                value: isEnabled,
                onChanged: _busy ? null : _toggle,
              ),
              if (isEnabled) ...[
                const Divider(),
                hasCustomPin.when(
                  data: (custom) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          custom
                              ? s.appLockUsingCustomPin
                              : s.appLockUsingEmergencyCode,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _setCustomPin,
                        icon: const Icon(Icons.pin, size: 18),
                        label: Text(custom
                            ? s.appLockChangeCustomPin
                            : s.appLockSetCustomPin),
                      ),
                      if (custom) ...[
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: _useEmergencyCodeInstead,
                          child: Text(s.appLockUseEmergencyCodeInstead),
                        ),
                      ],
                    ],
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('$e'),
                ),
              ],
            ],
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
        ),
      ],
    );
  }
}

class _AutoStartSection extends ConsumerWidget {
  const _AutoStartSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return _ExpandSection(
      icon: Icons.bolt,
      title: s.settingsAutoStart,
      subtitle: s.autoStartDesc,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: () async {
                try {
                  await ref.read(nativeBridgeProvider).openAutoStartSettings();
                } catch (_) {
                  // Best-effort — nothing meaningful to show the user if
                  // even the fallback app-details screen couldn't open.
                }
              },
              icon: const Icon(Icons.settings_suggest, size: 18),
              label: Text(s.openAutoStartSettings),
            ),
            const SizedBox(height: 8),
            Text(
              s.autoStartNote,
              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }
}

class _DeviceAdminSection extends ConsumerStatefulWidget {
  const _DeviceAdminSection();
  @override
  ConsumerState<_DeviceAdminSection> createState() => _DeviceAdminSectionState();
}

class _DeviceAdminSectionState extends ConsumerState<_DeviceAdminSection>
    with WidgetsBindingObserver {
  bool _activating = false;

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
    // The system "Activate device admin?" screen is a separate Activity —
    // there's no direct callback into this widget when it closes, so we
    // re-check status every time the app comes back to the foreground.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(deviceAdminActiveProvider);
    }
  }

  Future<void> _activate() async {
    setState(() => _activating = true);
    try {
      await ref
          .read(nativeBridgeProvider)
          .requestDeviceAdminActivation()
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      if (mounted) {
        final s = ref.read(stringsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${s.deviceAdminActivationFailed} ($e)'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _activating = false);
      // The system screen may already be closed by the time control returns
      // here on some OEMs; invalidate immediately in addition to the
      // lifecycle-resume check above so the status is never stale.
      ref.invalidate(deviceAdminActiveProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final active = ref.watch(deviceAdminActiveProvider);
    final cs = Theme.of(context).colorScheme;

    return _ExpandSection(
      icon: Icons.admin_panel_settings,
      title: s.settingsDeviceAdmin,
      subtitle: s.deviceAdminDesc,
      children: [
        active.when(
          data: (isActive) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor:
                      isActive ? Colors.green.shade100 : cs.errorContainer,
                  child: Icon(
                    isActive ? Icons.check_circle : Icons.warning_amber,
                    color: isActive ? Colors.green.shade700 : cs.error,
                    size: 20,
                  ),
                ),
                title: Text(s.settingsDeviceAdmin),
                subtitle: Text(
                  isActive ? s.deviceAdminEnabled : s.deviceAdminDisabled,
                ),
              ),
              if (!isActive)
                FilledButton.icon(
                  onPressed: _activating ? null : _activate,
                  icon: _activating
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.shield, size: 18),
                  label: Text(s.activateDeviceAdmin),
                ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  s.deviceAdminLimitNote,
                  style: TextStyle(fontSize: 12, color: cs.onTertiaryContainer),
                ),
              ),
            ],
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
        ),
      ],
    );
  }
}

class _BatterySection extends ConsumerStatefulWidget {
  const _BatterySection();
  @override
  ConsumerState<_BatterySection> createState() => _BatterySectionState();
}

class _BatterySectionState extends ConsumerState<_BatterySection> {
  bool _requesting = false;

  Future<void> _requestIgnore() async {
    setState(() => _requesting = true);
    try {
      await ref
          .read(nativeBridgeProvider)
          .requestIgnoreBatteryOptimizations()
          .timeout(const Duration(seconds: 5));
      ref.invalidate(batteryOptIgnoredProvider);
    } catch (e) {
      if (mounted) {
        final s = ref.read(stringsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.isAr ? 'تعذّر فتح إعدادات البطارية: $e' : 'Could not open battery settings: $e',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final ignored = ref.watch(batteryOptIgnoredProvider);
    final cs = Theme.of(context).colorScheme;

    return _ExpandSection(
      icon: Icons.battery_alert,
      title: s.settingsBattery,
      subtitle: s.batteryOptDesc,
      children: [
        ignored.when(
          data: (isIgnored) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: isIgnored
                      ? Colors.green.shade100
                      : cs.errorContainer,
                  child: Icon(
                    isIgnored ? Icons.check_circle : Icons.warning_amber,
                    color: isIgnored ? Colors.green.shade700 : cs.error,
                    size: 20,
                  ),
                ),
                title: Text(s.settingsBattery),
                subtitle: Text(
                  isIgnored ? s.batteryOptEnabled : s.batteryOptDisabled,
                ),
              ),
              if (!isIgnored) ...[
                FilledButton.icon(
                  onPressed: _requesting ? null : _requestIgnore,
                  icon: _requesting
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.battery_charging_full, size: 18),
                  label: Text(s.openBatterySettings),
                ),
              ],
            ],
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
        ),
      ],
    );
  }
}

class _PermissionsSection extends ConsumerWidget {
  const _PermissionsSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final perms = ref.watch(permissionsProvider);
    final battIgnored = ref.watch(batteryOptIgnoredProvider);
    final cs = Theme.of(context).colorScheme;

    return _ExpandSection(
      icon: Icons.verified_user,
      title: s.settingsPermissions,
      children: [
        perms.when(
          data: (map) => Column(
            children: [
              _PermRow(s.permSmsLabel, s.permSmsDesc, map['sms']!, cs),
              _PermRow(
                s.permLocationLabel,
                s.permLocationDesc,
                map['location']!,
                cs,
              ),
              _PermRow(
                s.permBgLocationLabel,
                s.permBgLocationDesc,
                map['backgroundLocation']!,
                cs,
              ),
              _PermRow(s.permPhoneLabel, s.permPhoneDesc, map['phone']!, cs),
              _PermRow(
                s.permNotifLabel,
                s.permNotifDesc,
                map['notifications']!,
                cs,
              ),
              _PermRow(
                s.permVibrateLabel,
                s.permVibrateDesc,
                map['vibrate']!,
                cs,
              ),
              battIgnored.when(
                data: (v) => _PermRow(
                  s.permBatteryLabel,
                  s.permBatteryDesc,
                  v ? PermissionStatus.granted : PermissionStatus.denied,
                  cs,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () async {
            try {
              // SMS/phone/notification can be requested together safely.
              await [
                Permission.sms,
                Permission.phone,
                Permission.notification,
              ].request();

              // Background location MUST be requested separately, only after
              // foreground location is granted — Android silently ignores or
              // mishandles it when bundled into the same batch request as
              // foreground location. This was the actual cause of the button
              // feeling like it did nothing for background location.
              final locationStatus = await Permission.location.request();
              if (locationStatus.isGranted) {
                await Permission.locationAlways.request();
              }
            } finally {
              ref.invalidate(permissionsProvider);
              ref.invalidate(batteryOptIgnoredProvider);
              if (context.mounted) {
                final allGranted = await ref.read(permissionsProvider.future).then(
                      (map) => map.values.every((v) => v == PermissionStatus.granted),
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        allGranted ? s.allPermissionsGranted : s.somePermissionsMissing,
                      ),
                    ),
                  );
                }
              }
            }
          },
          icon: const Icon(Icons.lock_open, size: 18),
          label: Text(s.requestAllPermissions),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => openAppSettings(),
          icon: const Icon(Icons.settings, size: 18),
          label: Text(s.openAppSettings),
        ),
      ],
    );
  }
}

class _PermRow extends StatelessWidget {
  const _PermRow(this.label, this.desc, this.status, this.cs);
  final String label, desc;
  final PermissionStatus status;
  final ColorScheme cs;

  Color get _color => status == PermissionStatus.granted
      ? Colors.green.shade700
      : status == PermissionStatus.permanentlyDenied
      ? Colors.red.shade700
      : Colors.orange;

  String get _badge => status == PermissionStatus.granted
      ? '✓'
      : status == PermissionStatus.permanentlyDenied
      ? '✗✗'
      : '✗';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 3, left: 6, right: 6),
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(_badge, style: TextStyle(color: _color, fontSize: 12)),
                  ],
                ),
                Text(desc, style: TextStyle(fontSize: 11, color: cs.outline)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TestSection extends ConsumerStatefulWidget {
  const _TestSection();
  @override
  ConsumerState<_TestSection> createState() => _TestSectionState();
}

class _TestSectionState extends ConsumerState<_TestSection> {
  bool _testingLoc = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);

    return _ExpandSection(
      icon: Icons.science,
      title: s.settingsTest,
      children: [
        _TestTile(
          icon: Icons.gps_fixed,
          title: s.testLocation,
          desc: s.testLocationDesc,
          loading: _testingLoc,
          label: s.testNow,
          onTap: () async {
            setState(() => _testingLoc = true);
            try {
              final captureService = ref.read(locationCaptureProvider);
              final location = await captureService.capture();
              ref.invalidate(lastLocationProvider);
              if (context.mounted) {
                if (location != null) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(s.locationUpdated)));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${s.locationFailed}\n${captureService.lastFailureReason ?? ""}',
                      ),
                      backgroundColor: Theme.of(context).colorScheme.error,
                      duration: const Duration(seconds: 6),
                    ),
                  );
                }
              }
            } finally {
              if (mounted) setState(() => _testingLoc = false);
            }
          },
        ),
        const SizedBox(height: 8),
        _TestTile(
          icon: Icons.alarm,
          title: s.testAlarm,
          desc: s.cmdAlarm,
          loading: false,
          label: s.testNow,
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(s.testAlarm),
                content: Text(
                  s.isAr
                      ? 'سيبدأ إنذار صوتي واهتزاز حقيقي الآن لاختباره. لإيقافه، استخدم زر إيقاف الإنذار في الشاشة الرئيسية.\n\nيمكنك أيضًا اختباره عن بُعد بإرسال:\nALARM [رمزك]  أو  انذار [رمزك]'
                      : 'A real siren and vibration will start now to test it. To stop it, use the Stop Alarm button on the dashboard.\n\nYou can also test it remotely by sending:\nALARM [yourcode]',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(s.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(s.testAlarm),
                  ),
                ],
              ),
            );
            if (confirmed != true || !context.mounted) return;
            try {
              await ref.read(nativeBridgeProvider).triggerAlarm();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      s.isAr
                          ? 'تم تشغيل الإنذار — أوقفه من الشاشة الرئيسية.'
                          : 'Alarm started — stop it from the dashboard.',
                    ),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$e'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            }
          },
        ),
        const SizedBox(height: 8),
        _TestTile(
          icon: Icons.lock_clock,
          title: s.testLock,
          desc: s.cmdLock,
          loading: false,
          label: s.testNow,
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(s.testLockConfirmTitle),
                content: Text(s.testLockConfirmDesc),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(s.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(s.testLock),
                  ),
                ],
              ),
            );
            if (confirmed != true || !context.mounted) return;
            try {
              await ref.read(nativeBridgeProvider).lockDeviceNow();
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(s.testLockRequiresAdmin),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            }
          },
        ),
      ],
    );
  }
}

class _TestTile extends StatelessWidget {
  const _TestTile({
    required this.icon,
    required this.title,
    required this.desc,
    required this.loading,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String title, desc, label;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, size: 22),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          subtitle: Text(
            desc,
            style: const TextStyle(fontSize: 11),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        FilledButton.tonal(
          onPressed: loading ? null : onTap,
          child: loading
              ? const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(label, style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}

// ── Reusable ─────────────────────────────────────────────────────────────────

class _ExpandSection extends StatefulWidget {
  const _ExpandSection({
    required this.icon,
    required this.title,
    required this.children,
    this.subtitle,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  State<_ExpandSection> createState() => _ExpandSectionState();
}

class _ExpandSectionState extends State<_ExpandSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: cs.primaryContainer,
                    child: Icon(
                      widget.icon,
                      color: cs.onPrimaryContainer,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (widget.subtitle != null)
                          Text(
                            widget.subtitle!,
                            style: TextStyle(fontSize: 11, color: cs.outline),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    color: cs.outline,
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.children,
              ),
            ),
        ],
      ),
    );
  }
}

/// Shown at the top of the dashboard whenever live tracking (activated
/// remotely via the LIVETRACK/تتبع_مباشر SMS command) is currently active.
/// This is the ONLY place tracking can be stopped — by design, it cannot be
/// stopped via SMS, so a thief holding a stolen phone can't turn it back off.
class _LiveTrackingBanner extends ConsumerStatefulWidget {
  const _LiveTrackingBanner();
  @override
  ConsumerState<_LiveTrackingBanner> createState() => _LiveTrackingBannerState();
}

class _LiveTrackingBannerState extends ConsumerState<_LiveTrackingBanner> {
  bool _stopping = false;

  Future<void> _stop() async {
    final s = ref.read(stringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(s.stopLiveTrackingConfirmTitle),
        content: Text(s.stopLiveTrackingConfirmDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.stopLiveTracking),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _stopping = true);
    try {
      await ref.read(nativeBridgeProvider).stopLiveTracking();
      ref.invalidate(liveTrackingActiveProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.liveTrackingStopped)));
      }
    } finally {
      if (mounted) setState(() => _stopping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final active = ref.watch(liveTrackingActiveProvider);
    final cs = Theme.of(context).colorScheme;

    return active.when(
      data: (isActive) {
        if (!isActive) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            margin: EdgeInsets.zero,
            color: cs.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.gps_fixed, color: cs.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.liveTrackingActiveTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: cs.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.liveTrackingActiveDesc,
                    style: TextStyle(fontSize: 12, color: cs.onErrorContainer),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _stopping ? null : _stop,
                    style: FilledButton.styleFrom(backgroundColor: cs.error),
                    icon: _stopping
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.stop_circle, size: 18),
                    label: Text(s.stopLiveTracking),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(padding: const EdgeInsets.all(14), child: child),
  );
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}

// ── Role helpers ──────────────────────────────────────────────────────────────
String _roleLabel(TrustedContactRole r, AppStrings s) => switch (r) {
  TrustedContactRole.primary => s.rolePrimary,
  TrustedContactRole.secondary => s.roleSecondary,
  TrustedContactRole.backup => s.roleBackup,
  TrustedContactRole.additional => s.roleAdditional,
};

String _roleDesc(TrustedContactRole r, AppStrings s) => switch (r) {
  TrustedContactRole.primary => s.rolePrimaryDesc,
  TrustedContactRole.secondary => s.roleSecondaryDesc,
  TrustedContactRole.backup => s.roleBackupDesc,
  TrustedContactRole.additional => s.roleAdditionalDesc,
};

IconData _roleIcon(TrustedContactRole r) => switch (r) {
  TrustedContactRole.primary => Icons.star,
  TrustedContactRole.secondary => Icons.star_half,
  TrustedContactRole.backup => Icons.bookmark,
  TrustedContactRole.additional => Icons.person,
};

Color _roleColor(TrustedContactRole r, ColorScheme cs) => switch (r) {
  TrustedContactRole.primary => cs.primary,
  TrustedContactRole.secondary => cs.secondary,
  TrustedContactRole.backup => cs.tertiary,
  TrustedContactRole.additional => cs.outline,
};
