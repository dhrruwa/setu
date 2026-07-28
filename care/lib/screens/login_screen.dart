import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_data.dart';
import '../providers.dart';
import '../theme/tokens.dart';
import '../widgets/care_widgets.dart';

/// Centred card. Any credentials succeed — auth is mocked.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController(text: 'sridevi@phc.kar.gov.in');
  final _password = TextEditingController(text: 'demo');
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    await ref.read(authProvider.notifier).signIn(_email.text.trim());
    // The router redirects on session change; nothing to navigate here.
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(S.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: CareCard(
                padding: const EdgeInsets.all(S.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: C.teal,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          alignment: Alignment.center,
                          child: const Text('S',
                              style: TextStyle(
                                  color: C.onDark,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16)),
                        ),
                        const SizedBox(width: S.sm),
                        const Text('Setu Care', style: T.h1),
                      ],
                    ),
                    const SizedBox(height: S.sm),
                    const Text(
                      'Antenatal records from your ASHA workers, in one place.',
                      style: T.small,
                    ),
                    const SizedBox(height: S.lg),
                    const SectionLabel('Email'),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      style: T.body,
                      decoration: const InputDecoration(
                        hintText: 'name@phc.kar.gov.in',
                      ),
                    ),
                    const SizedBox(height: S.md),
                    const SectionLabel('Password'),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      style: T.body,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        suffixIcon: IconButton(
                          iconSize: 18,
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(height: S.lg),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(_busy ? 'Signing in…' : 'Sign in'),
                    ),
                    const SizedBox(height: S.md),
                    Text(
                      MockData.facility,
                      style: T.small,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
