import 'package:go_router/go_router.dart';

import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/budgets/budgets_screen.dart';
import 'features/categories/categories_screen.dart';
import 'features/groups/group_detail_screen.dart';
import 'features/home/home_shell.dart';
import 'features/reports/reports_screen.dart';
import 'features/wallets/wallets_screen.dart';

GoRouter buildRouter(AuthProvider auth) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (context, state) {
      final atAuthScreen =
          state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (!auth.isLoggedIn && !atAuthScreen) return '/login';
      if (auth.isLoggedIn && atAuthScreen) return '/';

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeShell()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/wallets', builder: (context, state) => const WalletsScreen()),
      GoRoute(path: '/categories', builder: (context, state) => const CategoriesScreen()),
      GoRoute(path: '/budgets', builder: (context, state) => const BudgetsScreen()),
      GoRoute(path: '/reports', builder: (context, state) => const ReportsScreen()),
      GoRoute(
        path: '/groups/:id',
        builder: (context, state) => GroupDetailScreen(
          groupId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
    ],
  );
}