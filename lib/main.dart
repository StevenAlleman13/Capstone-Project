// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:async';

import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/login_page.dart';
import 'screens/welcome_page.dart';
import 'screens/signup_page.dart';
import 'screens/reset_password_page.dart';
import 'screens/dashboard_page.dart' as dash;
import 'screens/health_page.dart' show HealthPage, HealthPageState;
import 'screens/fitness_page.dart' show FitnessPage, FitnessPageState;
import 'screens/events_page.dart' show EventsPage, EventsPageState;
import 'screens/settings_page.dart' as settings;
import 'screens/quick_add.dart' as quick_add;
import 'package:hive_flutter/hive_flutter.dart';

const Color _neonGreen = Color(0xFF00FF66);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Hive.initFlutter();
  await Hive.deleteBoxFromDisk('events');
  await Hive.openBox('events');
  await Hive.openBox('tasks');
  await Hive.openBox('selected_apps');

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseAnonKey == null) {
    throw Exception('Missing Supabase env variables');
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
          title: 'Namer App',
          theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.black,
          colorScheme: ColorScheme.dark(
            primary: Colors.black,
            onPrimary: _neonGreen,
            secondary: _neonGreen,
            onSecondary: Colors.black,
            surface: Colors.black,
            onSurface: _neonGreen,
            error: Colors.red,
            onError: Colors.white,
          ),
          textTheme: TextTheme(
            titleLarge: TextStyle(
              color: Colors.white,
              shadows: [],
              fontSize: 20,
            ),
            displayMedium: TextStyle(
              color: _neonGreen,
              shadows: [Shadow(color: _neonGreen, blurRadius: 16.0)],
              fontSize: 24,
            ),
            bodyMedium: TextStyle(
              color: _neonGreen,
              shadows: [Shadow(color: _neonGreen, blurRadius: 8.0)],
            ),
          ),
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: _neonGreen,
          ),
          iconTheme: IconThemeData(color: _neonGreen),
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.black,
            foregroundColor: _neonGreen,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            color: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[900],
              foregroundColor: _neonGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
          ),
        ),
        home: const AuthGate(),
        routes: {
          '/login': (context) => const LoginPage(),
          '/signup': (context) => const SignUpPage(),
          '/home': (context) => const MyHomePage(),
          '/settings': (context) => const settings.SettingsPage(),
          '/reset-password': (context) {
            final email = ModalRoute.of(context)!.settings.arguments as String;
            return ResetPasswordPage(email: email);          },
        },
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  StreamSubscription<AuthState>? _authSub;
  bool? _hasSession;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrapAuthState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null && mounted) {
        setState(() => _hasSession = true);
      }
    }
  }

  Future<void> _bootstrapAuthState() async {
    final auth = Supabase.instance.client.auth;

    _authSub = auth.onAuthStateChange.listen((event) {
      if (!mounted) return;
      setState(() {
        _hasSession = event.session != null;
      });
    });

    var session = auth.currentSession;
    if (session == null) {
      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (session == null && DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 100));
        session = auth.currentSession;
      }
    }

    if (!mounted) return;
    setState(() {
      _hasSession = session != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasSession == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.shrink(),
      );
    }

    if (_hasSession == true) {
      return const MyHomePage();
    }

    return const WelcomePage();
  }
}

class MyAppState extends ChangeNotifier {
  var current = WordPair.random();

  void getNext() {
    current = WordPair.random();
    notifyListeners();
  }

  final Set<WordPair> favorites = <WordPair>{};

  void toggleFavorite([WordPair? pair]) {
    pair = pair ?? current;
    if (favorites.contains(pair)) {
      favorites.remove(pair);
    } else {
      favorites.add(pair);
    }
    notifyListeners();
  }

  void removeFavorite(WordPair pair) {
    favorites.remove(pair);
    notifyListeners();
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;
  final GlobalKey<EventsPageState> eventsPageKey = GlobalKey<EventsPageState>();
  final GlobalKey<FitnessPageState> fitnessPageKey =
      GlobalKey<FitnessPageState>();
  final GlobalKey<HealthPageState> healthPageKey = GlobalKey<HealthPageState>();

  @override
  Widget build(BuildContext context) {
    var colorScheme = Theme.of(context).colorScheme;
    final pageTitles = ['Dashboard', 'Journal', '', 'Health', 'Fitness'];
    final pageTitle = (selectedIndex >= 0 && selectedIndex < pageTitles.length)
        ? pageTitles[selectedIndex]
        : '';

    var mainArea = ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: IndexedStack(
        index: selectedIndex,
        children: [
          const dash.DashboardPage(),
          EventsPage(
            key: eventsPageKey,
            onViewModeChanged: () {
              setState(() {});
            },
          ),
          const SizedBox.shrink(), // index 2 — plus button, not a real tab
          HealthPage(key: healthPageKey),
          FitnessPage(key: fitnessPageKey),
        ],
      ),
    );

    // Hide AppBar on Dashboard (0), Events (1), and Plus (2)
    return Scaffold(
      appBar: (selectedIndex == 0 || selectedIndex == 1 || selectedIndex == 2)
          ? null
          : AppBar(
              backgroundColor: Colors.black,
              elevation: 0,
              centerTitle: false,
              title: Text(
                pageTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 450) {
            return Column(
              children: [
                Expanded(child: mainArea),
                SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selectedIndex == 1)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            border: Border(
                              top: BorderSide(
                                color: _neonGreen.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 16,
                          ),
                          child: Center(
                            child: OutlinedButton(
                              onPressed: () {
                                eventsPageKey.currentState?.jumpToToday();
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: _neonGreen, width: 1.5),
                                foregroundColor: _neonGreen,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text(
                                'Today',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Container(
                        color: Colors.grey[800],
                        padding: const EdgeInsets.only(top: 6, bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _NavBarIcon(
                              icon: Icons.dashboard,
                              label: 'Dashboard',
                              isSelected: selectedIndex == 0,
                              onTap: () => setState(() => selectedIndex = 0),
                            ),
                            const SizedBox(width: 12),
                            _NavBarIcon(
                              icon: Icons.menu_book,
                              label: 'Journal',
                              isSelected: selectedIndex == 1,
                              onTap: () {
                                setState(() => selectedIndex = 1);
                                eventsPageKey.currentState?.collapseAll();
                              },
                            ),
                            const SizedBox(width: 12),
                            // ── Plus button ──
                            GestureDetector(
                              onTap: () => quick_add
                                  .showQuickAddSheet(
                                    context,
                                    onNavigate: (index) =>
                                        setState(() => selectedIndex = index),
                                  )
                                  .then((_) {
                                    eventsPageKey.currentState?.refresh();
                                    fitnessPageKey.currentState?.refresh();
                                    healthPageKey.currentState?.refresh();
                                  }),
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _neonGreen,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _neonGreen.withOpacity(0.4),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.smart_toy,
                                  color: Colors.black,
                                  size: 30,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _NavBarIcon(
                              icon: Icons.health_and_safety,
                              label: 'Health',
                              isSelected: selectedIndex == 3,
                              onTap: () => setState(() => selectedIndex = 3),
                            ),
                            const SizedBox(width: 12),
                            _NavBarIcon(
                              icon: Icons.fitness_center,
                              label: 'Fitness',
                              isSelected: selectedIndex == 4,
                              onTap: () => setState(() => selectedIndex = 4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          } else {
            return Row(
              children: [
                SafeArea(
                  child: NavigationRail(
                    extended: constraints.maxWidth >= 600,
                    backgroundColor: Colors.grey[800],
                    selectedIconTheme: IconThemeData(color: _neonGreen),
                    unselectedIconTheme: IconThemeData(color: Colors.grey[500]),
                    selectedLabelTextStyle: TextStyle(color: _neonGreen),
                    unselectedLabelTextStyle: TextStyle(
                      color: Colors.grey[500],
                    ),
                    destinations: [
                      NavigationRailDestination(
                        icon: Icon(Icons.dashboard),
                        label: Text('Dashboard'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.menu_book),
                        label: Text('Journal'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.add_circle, color: _neonGreen),
                        label: Text(''),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.health_and_safety),
                        label: Text('Health'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.fitness_center),
                        label: Text('Fitness'),
                      ),
                    ],
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (value) {
                      setState(() {
                        selectedIndex = value;
                      });
                      if (value == 1) {
                        eventsPageKey.currentState?.collapseAll();
                      }
                    },
                  ),
                ),
                Expanded(child: mainArea),
              ],
            );
          }
        },
      ),
    );
  }
}

class GeneratorPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox.shrink();
  }
}

class BigCard extends StatelessWidget {
  const BigCard({super.key, required this.pair});

  final WordPair pair;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var style = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );

    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: AnimatedSize(
          duration: Duration(milliseconds: 200),
          child: MergeSemantics(
            child: Wrap(
              children: [
                Text(
                  pair.first,
                  style: style.copyWith(fontWeight: FontWeight.w200),
                ),
                Text(
                  pair.second,
                  style: style.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FavoritesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var appState = context.watch<MyAppState>();

    if (appState.favorites.isEmpty) {
      return Center(child: Text('No favorites yet.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(30),
          child: Text('You have ${appState.favorites.length} favorites:'),
        ),
        Expanded(
          child: GridView(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              childAspectRatio: 400 / 80,
            ),
            children: [
              for (var pair in appState.favorites)
                ListTile(
                  leading: IconButton(
                    icon: Icon(Icons.delete_outline, semanticLabel: 'Delete'),
                    color: theme.colorScheme.primary,
                    onPressed: () {
                      appState.removeFavorite(pair);
                    },
                  ),
                  title: Text(
                    pair.asLowerCase,
                    semanticsLabel: pair.asPascalCase,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CUSTOM NAV BAR ICON
// ─────────────────────────────────────────────────────────────────────────────

class _NavBarIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarIcon({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? _neonGreen : Colors.grey[500]!;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 11, shadows: const []),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
