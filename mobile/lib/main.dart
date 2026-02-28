import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/api_client.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'features/quran/quran_screen.dart';
import 'features/quran/surah_list_screen.dart';
import 'features/recite/recite_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/settings_provider.dart';
import 'shared/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      apiClientProvider.overrideWithValue(ApiClient(prefs: prefs)),
    ],
    child: const MemorizerApp(),
  ));
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, state, shell) => _AppShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/quran', builder: (_, __) => const SurahListScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/recite', builder: (_, __) => const ReciteScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        ]),
      ],
    ),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(
      path: '/read',
      builder: (_, state) {
        final page = int.tryParse(state.uri.queryParameters['page'] ?? '') ?? 1;
        return QuranScreen(initialPage: page, standalone: true);
      },
    ),
  ],
);

class MemorizerApp extends ConsumerWidget {
  const MemorizerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp.router(
      title: 'Quran Memorizer',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: _router,
    );
  }
}

class _AppShell extends ConsumerStatefulWidget {
  const _AppShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  ConsumerState<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<_AppShell> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final notifier = ref.read(authProvider.notifier);
      await notifier.checkAuth();
      if (!mounted) return;
      final status = ref.read(authProvider).status;
      if (status == AuthStatus.unauthenticated) {
        context.go('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (_, next) {
      if (next.status == AuthStatus.unauthenticated) {
        context.go('/login');
      }
    });

    return Scaffold(
      body: widget.shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.shell.currentIndex,
        onDestinationSelected: widget.shell.goBranch,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'Quran'),
          NavigationDestination(icon: Icon(Icons.repeat_rounded), label: 'Recite'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
