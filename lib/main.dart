// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:async';

import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/login_page.dart';
import 'screens/dashboard_page.dart' as dash;
import 'screens/health_page.dart' as health;
import 'screens/fitness_page.dart' as fit;
import 'screens/events_page.dart' show EventsPage, EventsPageState;
import 'screens/settings_page.dart' as settings;

import 'package:hive_flutter/hive_flutter.dart';

const Color _neonGreen = Color(0xFF00FF66);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.deleteBoxFromDisk('events');
  await Hive.openBox('events');
  await Hive.openBox('tasks');

  await Supabase.initialize(
    url: 'https://jfzqbatdzuzaukmqifef.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpmenFiYXRkenV6YXVrbXFpZmVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcyODM1NjUsImV4cCI6MjA4Mjg1OTU2NX0.2kuf8GKWCMtZeKXPLgTSrOHUjYfOb7qCpwaIyFX7Ik8',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
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
              color: _neonGreen,
              shadows: [Shadow(color: _neonGreen, blurRadius: 12.0)],
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
          iconTheme: IconThemeData(color: _neonGreen),
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.black,
            foregroundColor: _neonGreen,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            color: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
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
          '/home': (context) => const MyHomePage(),
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

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _authSub;
  bool? _hasSession;

  @override
  void initState() {
    super.initState();
    _bootstrapAuthState();
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
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasSession == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_hasSession == true) {
      return const MyHomePage();
    }

    return const LoginPage();
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

  @override
  Widget build(BuildContext context) {
    var colorScheme = Theme.of(context).colorScheme;

    Widget page;
    switch (selectedIndex) {
      case 0:
        page = const dash.DashboardPage();
      case 1:
        page =
            const health.HealthPage(); // or HealthPageDb if you made the DB wrapper
      case 2:
        page = const fit.FitnessPage();
      case 3:
        page = EventsPage(
          key: eventsPageKey,
          onViewModeChanged: () {
            setState(() {}); // Rebuild to update button bar
          },
        );
      case 4:
        page = const settings.SettingsPage();
      default:
        throw UnimplementedError('no widget for $selectedIndex');
    }

    final pageTitles = ['Dashboard', 'Health', 'Fitness', 'Settings'];
    // If selectedIndex == 3 (Calendar), show blank title
    final pageTitle = (selectedIndex == 3)
        ? ''
        : (selectedIndex >= 0 && selectedIndex < pageTitles.length
              ? pageTitles[selectedIndex]
              : '');

    var mainArea = ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: page,
    );

    return Scaffold(
      appBar: (selectedIndex == 3)
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
                      if (selectedIndex == 3)
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Today button - simple text
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    onPressed: () {
                                      eventsPageKey.currentState?.jumpToToday();
                                    },
                                    child: Text(
                                      'Today',
                                      style: TextStyle(
                                        color: _neonGreen,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Events/Tasks toggle button - centered (hidden in month view)
                              if (selectedIndex == 3) 
                                Builder(
                                  builder: (context) {
                                    final currentTab = eventsPageKey.currentState?.selectedTab ?? 0;
                                    final isMonthView = eventsPageKey.currentState?.showMonthView ?? false;
                                    
                                    if (isMonthView) {
                                      return const SizedBox.shrink();
                                    }
                                    
                                    return GestureDetector(
                                      onTap: () {
                                        eventsPageKey.currentState?.toggleTab();
                                        setState(() {});
                                      },
                                      child: Container(
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[900],
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: _neonGreen.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: currentTab == 0
                                                  ? _neonGreen
                                                  : Colors.transparent,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              'Events',
                                              style: TextStyle(
                                                color: currentTab == 0
                                                    ? Colors.black
                                                    : Colors.grey[400],
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                shadows: [],
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: currentTab == 1
                                                  ? _neonGreen
                                                  : Colors.transparent,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              'Tasks',
                                              style: TextStyle(
                                                color: currentTab == 1
                                                    ? Colors.black
                                                    : Colors.grey[400],
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                shadows: [],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              // Add button - just plus icon
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: IconButton(
                                    onPressed: () {
                                      eventsPageKey.currentState?.addEventOrTask();
                                    },
                                    icon: Icon(
                                      Icons.add_circle,
                                      color: _neonGreen,
                                      size: 32,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Theme(
                        data: ThemeData(
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          splashFactory: NoSplash.splashFactory,
                        ),
                        child: BottomNavigationBar(
                          backgroundColor: Colors.grey[800],
                          type: BottomNavigationBarType.fixed,
                          selectedItemColor: _neonGreen,
                          unselectedItemColor: Colors.grey[500],
                          enableFeedback: false,
                          showSelectedLabels: true,
                          showUnselectedLabels: true,
                          items: [
                          BottomNavigationBarItem(
                            icon: Icon(Icons.dashboard),
                            label: 'Dashboard',
                          ),
                          BottomNavigationBarItem(
                            icon: Icon(Icons.health_and_safety),
                            label: 'Health',
                          ),
                          BottomNavigationBarItem(
                            icon: Icon(Icons.fitness_center),
                            label: 'Fitness',
                          ),
                          BottomNavigationBarItem(
                            icon: Icon(Icons.event),
                            label: 'Calendar',
                          ),
                          BottomNavigationBarItem(
                            icon: Icon(Icons.settings),
                            label: 'Settings',
                          ),
                        ],
                        currentIndex: selectedIndex,
                        onTap: (value) {
                          setState(() {
                            selectedIndex = value;
                          });
                        },
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
                        icon: Icon(Icons.health_and_safety),
                        label: Text('Health'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.fitness_center),
                        label: Text('Fitness'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.event),
                        label: Text('Calendar'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.settings),
                        label: Text('Settings'),
                      ),
                    ],
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (value) {
                      setState(() {
                        selectedIndex = value;
                      });
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
