import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../routes.dart';
import '../theme/tokens.dart';
import '../widgets/big_action_button.dart';
import '../widgets/language_toggle.dart';
import '../widgets/setu_card.dart';
import '../widgets/setu_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  static final _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn(AppLocalizations l) async {
    final email = _email.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = l.emailInvalid);
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = l.passwordInvalid);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .signIn(email: email, password: _password.text);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l.loginFailed;
      });
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(Routes.pin, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(S.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: S.sm),
                Row(
                  children: [
                    const SetuLogo(size: 56),
                    const SizedBox(width: S.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.appName, style: T.h1),
                          Text(l.appTagline, style: T.bodySoft),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: S.lg),
                Text(l.chooseLanguage, style: T.label),
                const SizedBox(height: S.sm),
                const LanguageToggle(),
                const SizedBox(height: S.lg),
                SetuCard(
                  padding: const EdgeInsets.all(S.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l.loginTitle, style: T.h2),
                      const SizedBox(height: S.xs),
                      Text(l.loginSubtitle, style: T.bodySoft),
                      const SizedBox(height: S.lg),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        style: T.body,
                        decoration: InputDecoration(
                          labelText: l.emailLabel,
                          hintText: l.emailHint,
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(left: S.md, right: S.sm),
                            child: Icon(Icons.mail_outline,
                                size: 26, color: C.textSoft),
                          ),
                          prefixIconConstraints:
                              const BoxConstraints(minWidth: 0),
                        ),
                      ),
                      const SizedBox(height: S.md),
                      TextField(
                        controller: _password,
                        obscureText: _obscure,
                        style: T.body,
                        onSubmitted: (_) => _signIn(l),
                        decoration: InputDecoration(
                          labelText: l.passwordLabel,
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(left: S.md, right: S.sm),
                            child: Icon(Icons.lock_outline,
                                size: 26, color: C.textSoft),
                          ),
                          prefixIconConstraints:
                              const BoxConstraints(minWidth: 0),
                          suffixIcon: IconButton(
                            iconSize: 26,
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(height: S.md),
                      BigActionButton(
                        label: l.signIn,
                        icon: Icons.login,
                        onPressed: _busy ? null : () => _signIn(l),
                      ),
                      const SizedBox(height: S.sm),
                      TextButton(
                        onPressed: () => _forgotPassword(context, l),
                        child: Text(l.forgotPassword),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: S.md),
                  Row(
                    children: [
                      const Icon(Icons.error_outline, color: C.red, size: 24),
                      const SizedBox(width: S.sm),
                      Expanded(
                        child: Text(_error!,
                            style: T.body.copyWith(color: C.red)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: S.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _forgotPassword(BuildContext context, AppLocalizations l) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: C.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(S.radius),
        ),
        title: Text(l.forgotPasswordTitle, style: T.h2),
        content: Text(l.forgotPasswordBody, style: T.body),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: FilledButton.styleFrom(
              minimumSize: const Size(120, S.tapMin),
            ),
            child: Text(l.ok),
          ),
        ],
      ),
    );
  }
}
