import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/app_bootstrap.dart';
import '../../data/services/api_service.dart';
import '../../data/services/auth_service.dart';
import 'discover_screen.dart';
import 'library_screen.dart';
import 'login_screen.dart';
import 'more_screen.dart';
import 'notifications_screen.dart';
import 'write_screen.dart';

/// App shell.
///
/// **Read access without login:** Discover (and public story pages) work with no
/// account. Library / Write / Notifications / personal profile require sign-in.
/// Guest sign-in still available for light personalization.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  final ApiService _apiService = ApiService();
  late final AuthService _authService = AuthService(apiService: _apiService);
  int _selectedIndex = 1; // Discover by default for read-only visitors
  AppBootstrap? _bootstrap;
  bool _loading = true;
  String _contentVersion = '';
  Timer? _syncTimer;
  AuthSession? _session;
  bool _showLoginOverlay = false;

  bool get _isAuthenticated => _session != null;

  @override
  void initState() {
    super.initState();
    _bootstrapApp();
    _syncTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pollContentVersion(),
    );
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrapApp() async {
    AuthSession? session;
    String? blockMessage;
    try {
      session = await _authService.restoreSession();
    } on AuthBlockedException catch (e) {
      session = null;
      blockMessage = e.message;
    } catch (_) {
      session = null;
    }
    if (!mounted) return;
    setState(() {
      _session = session;
      if (session == null) {
        _showLoginOverlay = true;
      }
    });
    await _loadBootstrap();
    if (!mounted) return;
    if (blockMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(blockMessage),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _loadBootstrap() async {
    if (mounted) setState(() => _loading = true);
    try {
      final bootstrap = await _apiService.fetchBootstrap();
      final version = await _apiService.fetchContentVersion();
      if (!mounted) return;
      setState(() {
        _bootstrap = bootstrap;
        _contentVersion = version;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pollContentVersion() async {
    if (_loading || _bootstrap == null) return;
    final latestVersion = await _apiService.fetchContentVersion();
    if (!mounted || latestVersion.isEmpty || latestVersion == _contentVersion) {
      return;
    }
    await _loadBootstrap();
  }

  Future<void> _continueLogin(
    String method, {
    String? email,
    String? password,
    String? mode,
    String? displayName,
  }) async {
    try {
      final AuthSession session;
      if (method == 'google') {
        session = await _authService.signInWithGoogle();
      } else if (method == 'email') {
        session = await _authService.signInWithEmail(
          email ?? '',
          password: password ?? '',
          mode: mode ?? 'login',
          displayName: displayName,
        );
      } else {
        session = await _authService.signInAsGuest();
      }
      if (!mounted) return;
      setState(() {
        _session = session;
        _showLoginOverlay = false;
      });
      await _loadBootstrap();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            session.isGoogle
                ? 'Signed in as ${session.displayName}'
                : session.isGuest
                    ? 'Continuing as guest (device-limited session)'
                    : 'Signed in with ${session.email}',
          ),
        ),
      );
    } on AuthBlockedException catch (e) {
      if (!mounted) return;
      setState(() {
        _session = null;
        _showLoginOverlay = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: msg.toLowerCase().contains('banned') ||
                  msg.toLowerCase().contains('suspended')
              ? Colors.red.shade700
              : null,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    if (!mounted) return;
    setState(() {
      _session = null;
      _selectedIndex = 1;
    });
    await _loadBootstrap();
  }

  void _requireAuth({int? afterLoginIndex}) {
    setState(() {
      _showLoginOverlay = true;
      if (afterLoginIndex != null) _selectedIndex = afterLoginIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _bootstrap == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Explicit login overlay (when user taps a gated tab)
    if (_showLoginOverlay && !_isAuthenticated) {
      return LoginScreen(
        onContinue: _continueLogin,
        onSkipAsReader: () {
          setState(() {
            _showLoginOverlay = false;
            _selectedIndex = 1; // Discover only
          });
          if (_bootstrap == null) _loadBootstrap();
        },
      );
    }

    if (_bootstrap == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Unable to load stories. Check connection.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadBootstrap,
                child: const Text('Retry'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _requireAuth(),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ),
      );
    }

    final pages = <Widget>[
      // Library — requires auth
      _isAuthenticated
          ? LibraryScreen(
              data: _bootstrap!,
              apiService: _apiService,
              onOpenDiscover: () => setState(() => _selectedIndex = 1),
            )
          : _AuthGate(
              title: 'Your Library',
              message:
                  'Sign in to see Current Reads, History, and Reading Lists. You can still browse Discover without an account.',
              onSignIn: () => _requireAuth(afterLoginIndex: 0),
              onBrowse: () => setState(() => _selectedIndex = 1),
            ),
      DiscoverScreen(data: _bootstrap!, apiService: _apiService),
      // Write — requires auth
      _isAuthenticated
          ? WriteScreen(data: _bootstrap!, apiService: _apiService)
          : _AuthGate(
              title: 'Write',
              message: 'Sign in to create and manage your stories.',
              onSignIn: () => _requireAuth(afterLoginIndex: 2),
              onBrowse: () => setState(() => _selectedIndex = 1),
            ),
      _isAuthenticated
          ? NotificationsScreen(
              data: _bootstrap!,
              apiService: _apiService,
              onOpenDiscover: () => setState(() => _selectedIndex = 1),
            )
          : _AuthGate(
              title: 'Notifications',
              message: 'Sign in to receive updates about stories you follow.',
              onSignIn: () => _requireAuth(afterLoginIndex: 3),
              onBrowse: () => setState(() => _selectedIndex = 1),
            ),
      _isAuthenticated
          ? MoreScreen(
              data: _bootstrap!,
              apiService: _apiService,
              onSignOut: _signOut,
              session: _session!,
            )
          : _AuthGate(
              title: 'Account',
              message: 'Sign in for profile, settings, and saved progress.',
              onSignIn: () => _requireAuth(afterLoginIndex: 4),
              onBrowse: () => setState(() => _selectedIndex = 1),
            ),
    ];

    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (child, animation) {
            final slide = Tween<Offset>(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(animation);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slide, child: child),
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(_selectedIndex),
            child: pages[_selectedIndex],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 76,
        backgroundColor: Colors.white,
        indicatorColor: Colors.transparent,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (value) {
          // Allow Discover always; other tabs prompt sign-in when logged out
          if (!_isAuthenticated && value != 1) {
            _requireAuth(afterLoginIndex: value);
            return;
          }
          setState(() => _selectedIndex = value);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_outlined),
            selectedIcon: Icon(Icons.edit),
            label: 'Write',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_rounded),
            selectedIcon: Icon(Icons.menu),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate({
    required this.title,
    required this.message,
    required this.onSignIn,
    required this.onBrowse,
  });

  final String title;
  final String message;
  final VoidCallback onSignIn;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onSignIn,
              child: const Text('Sign in'),
            ),
            TextButton(
              onPressed: onBrowse,
              child: const Text('Continue reading on Discover'),
            ),
          ],
        ),
      ),
    );
  }
}
