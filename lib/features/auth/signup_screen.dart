import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../core/theme/glas_theme.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/glas_widgets.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _groupCode = TextEditingController();
  bool _showGroupCode = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _groupCode.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Skriv dit navn.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(authServiceProvider).signUp(
            displayName: _name.text,
            email: _email.text.trim(),
            password: _password.text,
          );

      // An optional group code means they walk straight into a club.
      final code = _groupCode.text.trim();
      if (code.isNotEmpty) {
        try {
          await ref.read(groupRepositoryProvider).joinByCode(code);
        } on Object {
          // A bad code shouldn't block the account that was just created.
        }
      }

      if (mounted) context.go('/guide');
    } on Object catch (error) {
      setState(() => _error = describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.glas.onNight;

    return NightScreen(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
      children: [
        BackLink('← Log ind', color: c.nightMuted, onTap: () => context.pop()),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Opret en konto',
                style: GlasType.display(30, color: c.nightInk, height: 1.15)),
            const SizedBox(height: 8),
            SizedBox(
              width: 290,
              child: Text(
                'Din profil samler alt, du har smagt, og dine karakterer på '
                'tværs af grupper.',
                style: GlasType.body(13.5, color: c.nightMuted, height: 1.5),
              ),
            ),
          ],
        ),
        Column(
          children: [
            NightField(hint: 'Navn', controller: _name),
            const SizedBox(height: 10),
            NightField(
              hint: 'E-mail',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textCapitalization: TextCapitalization.none,
            ),
            const SizedBox(height: 10),
            NightField(
              hint: 'Vælg en adgangskode',
              controller: _password,
              obscure: true,
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel('Valgfrit', color: c.nightMuted),
            const SizedBox(height: 10),
            GlasTap(
              onTap: () => setState(() => _showGroupCode = !_showGroupCode),
              radius: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.nightLine),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Har du en gruppekode?',
                                  style:
                                      GlasType.body(14.5, color: c.nightInk)),
                              const SizedBox(height: 3),
                              Text('Så er du med i klubben fra start',
                                  style:
                                      GlasType.body(12, color: c.nightMuted)),
                            ],
                          ),
                        ),
                        Text(
                          _showGroupCode ? 'Skjul' : 'Tilføj',
                          style: GlasType.mono(13, color: c.nightMuted),
                        ),
                      ],
                    ),
                    if (_showGroupCode) ...[
                      const SizedBox(height: 12),
                      NightField(
                        hint: 'GRP-7F2A',
                        controller: _groupCode,
                        textCapitalization: TextCapitalization.characters,
                        style: GlasType.mono(15, color: c.nightInk, tracking: 0.1),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_error != null)
          Text(_error!, style: GlasType.body(13, color: c.accent)),
        Text(
          'Ved at oprette en konto accepterer du vilkårene og '
          'persondatapolitikken.',
          style: GlasType.body(11.5, color: c.nightMuted, height: 1.5),
        ),
        GlasButton(
          label: _busy ? 'Opretter…' : 'Opret konto',
          tone: GlasButtonTone.accent,
          enabled: !_busy,
          onTap: _signUp,
        ),
      ],
    );
  }
}
