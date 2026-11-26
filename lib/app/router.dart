import 'package:go_router/go_router.dart';
import '../core/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/customer/customer_shell.dart';
import '../features/owner/owner_shell.dart';

GoRouter createRouter(AuthState auth) => GoRouter(
  initialLocation: auth.isAuthenticated
      ? (auth.role == UserRole.owner ? '/owner' : '/customer')
      : '/login',
  redirect: (context, state) {
    final onLogin = state.matchedLocation == '/login';
    if (!auth.isAuthenticated && !onLogin) return '/login';
    if (auth.isAuthenticated && auth.role != UserRole.owner && state.matchedLocation == '/owner') return '/customer';
    if (auth.isAuthenticated && onLogin) {
      return auth.role == UserRole.owner ? '/owner' : '/customer';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/customer', builder: (_, __) => const CustomerShell()),
    GoRoute(path: '/owner', builder: (_, __) => const OwnerShell()),
  ],
);
