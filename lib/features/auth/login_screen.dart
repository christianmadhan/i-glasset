import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/glas_theme.dart';
import '../../core/widgets/app_mark.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/glas_widgets.dart';
import '../../core/widgets/huce_mark.dart';

/// "Log ind".
///
/// Takes two shapes. Against a server it is the designed email-and-password
/// screen. In the local build there is nothing to authenticate against, so it
/// collapses to the one thing the other phones actually need from you — your
/// name — because a password box with nothing behind it would be theatre.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<void> Function() action, {
    String? goTo = '/',
  }) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted && goTo != null) context.go(goTo);
    } on Object catch (error) {
      setState(() => _error = describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() => _run(() async {
        final auth = ref.read(authServiceProvider);
        if (auth.supportsPasswords) {
          await auth.signIn(
            email: _email.text.trim(),
            password: _password.text,
          );
        } else {
          await auth.signUp(displayName: _name.text);
        }
      });

  /// "Deltag med kode uden konto" — in the room in seconds, with a name you can
  /// fill in later.
  Future<void> _continueAsGuest() => _run(
        () => ref.read(authServiceProvider).signInAsGuest(),
        goTo: '/join',
      );

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Skriv din e-mail først, så sender vi et link.');
      return;
    }
    await _run(
      () => ref.read(authServiceProvider).sendPasswordReset(email),
      goTo: null,
    );
    if (mounted) {
      setState(() => _error = 'Vi har sendt et link til $email.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.glas.onNight;
    final hasPasswords = ref.watch(authServiceProvider).supportsPasswords;

    return NightScreen(
      padding: const EdgeInsets.fromLTRB(22, 40, 22, 30),
      gap: 26,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HuceLockup(),
            const SizedBox(height: 28),
            const AppMark(size: 72, radius: 18),
            const SizedBox(height: 16),
            Text('I Glasset',
                style: GlasType.display(34, color: c.nightInk, height: 1.1)),
            const SizedBox(height: 6),
            SectionLabel('Smag sammen', color: c.nightMuted, tracking: 0.18),
          ],
        ),

        if (hasPasswords)
          Column(
            children: [
              NightField(
                hint: 'E-mail',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textCapitalization: TextCapitalization.none,
              ),
              const SizedBox(height: 10),
              NightField(
                hint: 'Adgangskode',
                controller: _password,
                obscure: true,
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: GlasTap(
                  onTap: _busy ? null : _resetPassword,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                    child: Text('Glemt din adgangskode?',
                        style: GlasType.body(12.5, color: c.nightMuted)),
                  ),
                ),
              ),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NightField(hint: 'Dit navn', controller: _name),
              const SizedBox(height: 10),
              Text(
                'Alt bliver på din telefon. Navnet er kun det, de andre i '
                'rummet ser, når du deltager i en smagning.',
                style: GlasType.body(12.5, color: c.nightMuted, height: 1.5),
              ),
            ],
          ),

        if (_error != null)
          Text(_error!, style: GlasType.body(13, color: c.accent)),

        GlasButton(
          label: _busy
              ? 'Et øjeblik…'
              : hasPasswords
                  ? 'Log ind'
                  : 'Kom i gang',
          tone: GlasButtonTone.paper,
          enabled: !_busy,
          onTap: _signIn,
        ),

        Row(
          children: [
            Expanded(child: Container(height: 1, color: c.nightLine)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child:
                  Text('eller', style: GlasType.body(12, color: c.nightMuted)),
            ),
            Expanded(child: Container(height: 1, color: c.nightLine)),
          ],
        ),

        GlasButton(
          label: 'Deltag med kode uden konto',
          tone: GlasButtonTone.outline,
          height: 50,
          enabled: !_busy,
          onTap: _continueAsGuest,
        ),

        if (hasPasswords) ...[
          const SizedBox(height: 8),
          Center(
            child: GlasTap(
              onTap: () => context.push('/signup'),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text.rich(
                  TextSpan(
                    text: 'Ny her? ',
                    style: GlasType.body(14, color: c.nightMuted),
                    children: [
                      TextSpan(
                        text: 'Opret en konto',
                        style: GlasType.body(14, color: c.accent),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ] else
          Center(
            child: Text(
              'Smagninger deles direkte mellem telefonerne på jeres wi-fi. '
              'Ingen konto, ingen server.',
              textAlign: TextAlign.center,
              style: GlasType.body(12, color: c.nightMuted, height: 1.5),
            ),
          ),
      ],
    );
  }
}
