// main.dart
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:kebun_sawit/mvc_dao/dao_audit_log.dart';
import 'package:kebun_sawit/mvc_dao/dao_kesehatan.dart';
import 'package:kebun_sawit/mvc_dao/dao_observasi_tambahan.dart';
import 'package:kebun_sawit/mvc_dao/dao_reposisi.dart';
import 'package:kebun_sawit/mvc_dao/dao_spr_log.dart';
import 'package:kebun_sawit/mvc_dao/dao_sop.dart';
import 'package:kebun_sawit/mvc_dao/dao_task_execution.dart';
import 'package:kebun_sawit/mvc_libs/active_block_store.dart';
import 'package:kebun_sawit/mvc_libs/connection_utils.dart';
import 'package:kebun_sawit/screens/scr_menu.dart';
import 'package:kebun_sawit/screens/scr_option_acts.dart';
import 'package:kebun_sawit/screens/sync_download_screen.dart';
import 'plantdb/db_helper.dart';
import 'screens/scr_assignment_content.dart';
import 'screens/scr_assignment_list.dart';
import 'screens/scr_execution_form.dart';
import 'screens/scr_initial_sync.dart';
import 'screens/scr_login.dart';
import 'screens/scr_plant_health.dart';
import 'screens/scr_plant_reposition.dart';
import 'screens/scr_sync_action.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DBHelper().inisiasiDB();
  await ActiveBlockStore.ensureLoaded();
  runApp(const SRPlantation());
}

class SRPlantation extends StatelessWidget {
  const SRPlantation({super.key});

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final AppRouteObserver routeObserver = AppRouteObserver();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [routeObserver],
      title: 'Aplikasi Perkebunan',
      theme: ThemeData(
        primarySwatch: Colors.green, // Tema utama hijau
        fontFamily: 'Roboto',
      ),
      builder: (context, child) {
        return GlobalConnectivitySyncNotifier(
          navigatorKey: navigatorKey,
          routeObserver: routeObserver,
          child: child ?? const SizedBox.shrink(),
        );
      },

      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(), // Halaman awal : Login
        '/initSync': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map?;
          final username = args?['username'] as String?;
          final blok = args?['blok'] as String?;
          final selectedBlok = args?['selectedBlok'] as String?;
          return InitialSyncPage(
            username: username.toString(),
            blok: blok.toString(),
            selectedBlok: selectedBlok,
          );
        },
        '/assignments': (context) => const AssignmentListScreen(),
        '/kesehatan': (context) => const PlantHealthScreen(),
        '/reposisi': (context) => const PlantRepositionScreen(),
        //'/sqlite': (context) => const SqliteTestScreen(),
        '/syncPage': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final autoStartSync = args is Map ? (args['autoStartSync'] == true) : false;
          return SyncPage(autoStartSync: autoStartSync);
        },
        '/goDetail': (context) => const AssignmentContent(),
        '/isiTugas': (context) => const AssignmentExecutionFormScreen(),
        '/menu': (context) => const MenuScreen(),
        '/optAct': (context) => const OptionActScreen(),
        '/downloadPage': (context) => const SyncDownloadScreen(),
      },
    );
  }
}

class AppRouteObserver extends NavigatorObserver {
  String? currentRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentRoute = route.settings.name;
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentRoute = previousRoute?.settings.name;
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    currentRoute = newRoute?.settings.name;
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

class GlobalConnectivitySyncNotifier extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  final AppRouteObserver routeObserver;

  const GlobalConnectivitySyncNotifier({
    super.key,
    required this.child,
    required this.navigatorKey,
    required this.routeObserver,
  });

  @override
  State<GlobalConnectivitySyncNotifier> createState() => _GlobalConnectivitySyncNotifierState();
}

class _GlobalConnectivitySyncNotifierState extends State<GlobalConnectivitySyncNotifier> {
  StreamSubscription<dynamic>? _subscription;
  bool _wasInternetAvailable = true;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    _startWatcher();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _startWatcher() async {
    _wasInternetAvailable = await ConnectionUtils.checkConnection();

    _subscription = Connectivity().onConnectivityChanged.listen((_) async {
      final nowConnected = await ConnectionUtils.checkConnection();
      if (!mounted) return;

      if (!_wasInternetAvailable && nowConnected) {
        await _handleInternetRestored();
      }

      _wasInternetAvailable = nowConnected;
    });
  }

  Future<bool> _hasPendingSyncData() async {
    final tugas = (await TaskExecutionDao().getAllTaskExecByFlag()).isNotEmpty;
    final kesehatan = (await KesehatanDao().getAllZeroKesehatan()).isNotEmpty;
    final reposisi = (await ReposisiDao().getAllZeroReposisi()).isNotEmpty;
    final observasi = (await ObservasiTambahanDao().getAllZeroObservasi()).isNotEmpty;
    final spr = (await SPRLogDao().getAllZeroSPRLog()).isNotEmpty;
    final audit = (await AuditLogDao().getAllZeroAuditLog()).isNotEmpty;
    final sopcheck = (await SopDao().countUnsyncedChecks()) > 0;
    return tugas || kesehatan || reposisi || observasi || spr || audit || sopcheck;
  }

  Future<void> _handleInternetRestored() async {
    if (_dialogOpen) return;
    if (widget.routeObserver.currentRoute == '/syncPage') return;

    final hasPending = await _hasPendingSyncData();
    if (!hasPending) return;

    if (!mounted) return;

    final navigator = widget.navigatorKey.currentState;
    final navContext = widget.navigatorKey.currentContext;
    if (navigator == null || navContext == null) return;
    if (!navContext.mounted) return;

    _dialogOpen = true;

    await showDialog<void>(
      context: navContext,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Koneksi Internet'),
        content: const Text('koneksi internet tersedia, silakan lakukan sync segera..'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              navigator.pushNamed('/syncPage', arguments: {'autoStartSync': true});
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    _dialogOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ValueListenableBuilder<String?>(
          valueListenable: ActiveBlockStore.notifier,
          builder: (context, blockValue, _) {
            final blok = (blockValue ?? '').trim();
            final route = widget.routeObserver.currentRoute;
            if (blok.isEmpty || route == '/' || route == '/initSync') {
              return const SizedBox.shrink();
            }

            return Positioned(
              top: 10,
              right: 10,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF114B3A).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFF8FCE00).withValues(alpha: 0.8)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.grid_view_rounded, color: Color(0xFFB7F542), size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Blok Aktif: $blok',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
