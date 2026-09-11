import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/archive/previous_tasting_screen.dart';
import '../../features/archive/product_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/onboarding_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/groups/create_group_screen.dart';
import '../../features/groups/group_screen.dart';
import '../../features/home/home_shell.dart';
import '../../features/live/guess_sheet_screen.dart';
import '../../features/live/join_screen.dart';
import '../../features/live/live_screen.dart';
import '../../features/live/lobby_screen.dart';
import '../../features/live/results_screen.dart';
import '../../features/live/reveal_screen.dart';
import '../../features/live/summary_screen.dart';
import '../../features/profile/storage_screen.dart';
import '../../features/profile/taste_profile_screen.dart';
import '../../features/tastings/create_tasting_screen.dart';
import '../../features/tastings/edit_item_screen.dart';
import '../../features/tastings/program_screen.dart';
import '../providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Rebuilding the router on every auth change would drop the navigation
  // stack, so the redirect reads the session instead and this listenable only
  // nudges it when the session actually appears or disappears.
  final auth = ValueNotifier(0);
  ref.listen(authStateProvider, (_, _) => auth.value++);
  ref.onDispose(auth.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (context, state) {
      final signedIn = ref.read(authServiceProvider).currentUser != null;
      final path = state.matchedLocation;
      final isAuthRoute = path == '/login' || path == '/signup';

      if (!signedIn && !isAuthRoute) return '/login';
      // '/signup' only exists where there are accounts to create; locally the
      // sign-in screen already does that job.
      if (signedIn && isAuthRoute) return '/';
      if (path == '/signup' && !ref.read(authServiceProvider).supportsPasswords) {
        return '/login';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/guide',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // The four-tab home. ?tab= lets other screens jump straight to a tab.
      GoRoute(
        path: '/',
        builder: (context, state) => HomeShell(
          initialTab: int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0,
        ),
      ),

      GoRoute(
        path: '/join',
        builder: (context, state) =>
            JoinScreen(prefilledCode: state.uri.queryParameters['code']),
      ),

      GoRoute(
        path: '/groups/new',
        builder: (context, state) => const CreateGroupScreen(),
      ),
      GoRoute(
        path: '/groups/:groupId',
        builder: (context, state) =>
            GroupScreen(groupId: state.pathParameters['groupId']!),
      ),

      GoRoute(
        path: '/tastings/new',
        builder: (context, state) =>
            CreateTastingScreen(groupId: state.uri.queryParameters['group']),
      ),
      GoRoute(
        path: '/tastings/:tastingId/program',
        builder: (context, state) =>
            ProgramScreen(tastingId: state.pathParameters['tastingId']!),
      ),
      GoRoute(
        path: '/tastings/:tastingId/items/:itemId',
        builder: (context, state) => EditItemScreen(
          tastingId: state.pathParameters['tastingId']!,
          itemId: state.pathParameters['itemId']!,
        ),
      ),
      GoRoute(
        path: '/tastings/:tastingId/lobby',
        builder: (context, state) =>
            LobbyScreen(tastingId: state.pathParameters['tastingId']!),
      ),
      GoRoute(
        path: '/tastings/:tastingId/live',
        builder: (context, state) =>
            LiveScreen(tastingId: state.pathParameters['tastingId']!),
      ),
      GoRoute(
        path: '/tastings/:tastingId/sheet',
        builder: (context, state) => GuessSheetScreen(
          tastingId: state.pathParameters['tastingId']!,
          itemId: state.uri.queryParameters['item']!,
        ),
      ),
      GoRoute(
        path: '/tastings/:tastingId/reveal',
        builder: (context, state) =>
            RevealScreen(tastingId: state.pathParameters['tastingId']!),
      ),
      GoRoute(
        path: '/tastings/:tastingId/results',
        builder: (context, state) =>
            ResultsScreen(tastingId: state.pathParameters['tastingId']!),
      ),
      GoRoute(
        path: '/tastings/:tastingId/summary',
        builder: (context, state) =>
            SummaryScreen(tastingId: state.pathParameters['tastingId']!),
      ),
      GoRoute(
        path: '/tastings/:tastingId/archive',
        builder: (context, state) => PreviousTastingScreen(
            tastingId: state.pathParameters['tastingId']!),
      ),

      GoRoute(
        path: '/items/:itemId',
        builder: (context, state) =>
            ProductScreen(itemId: state.pathParameters['itemId']!),
      ),

      GoRoute(
        path: '/taste',
        builder: (context, state) => const TasteProfileScreen(),
      ),
      GoRoute(
        path: '/storage',
        builder: (context, state) => const StorageScreen(),
      ),
    ],
  );
});
