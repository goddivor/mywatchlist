import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/auth/kitsu_auth.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/user_kitsu_v2.dart';
import 'package:mywatchlist/user/trackers/models/tracker_model.dart';

/// Kitsu has no web sign in: it takes a username (or email) and a password. The dialog runs
/// the sign in itself, so the caller gets a yes/no and every failure has a visible reason.
class KitsuLoginDialog extends StatefulWidget {
  /// Prefilled when an account signs in again.
  final String? initialUsername;

  const KitsuLoginDialog({super.key, this.initialUsername});

  /// Opens the dialog; true when the user is signed in to Kitsu afterwards.
  static Future<bool> show(BuildContext context, {String? initialUsername}) async {
    final signedIn = await showDialog<bool>(
      context: context,
      builder: (_) => KitsuLoginDialog(initialUsername: initialUsername),
    );
    return signedIn ?? false;
  }

  @override
  State<KitsuLoginDialog> createState() => _KitsuLoginDialogState();
}

class _KitsuLoginDialogState extends State<KitsuLoginDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _username =
      TextEditingController(text: widget.initialUsername);
  final TextEditingController _password = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final user = UserKitsuV2.instance;
    String? error;
    try {
      await KitsuAuth().signInWithKitsu(
        context,
        _username.text.trim(),
        _password.text,
      );
      if (user.status != AuthStatus.AUTHENTICATED) {
        error = S.current.Acc_Kitsu_Wrong;
      }
    } catch (_) {
      error = S.current.Acc_Kitsu_Network;
    }
    if (error != null) {
      // The sign in leaves the status "in progress" when it fails: free the button.
      user.setStatus(AuthStatus.UNAUTHENTICATED);
      user.notifyAccountChange();
    }
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return AlertDialog(
      icon: ClipOval(
        child: Image.asset(
          TrackerInfo.kitsu.logoAsset,
          width: 48,
          height: 48,
          cacheWidth: 144,
        ),
      ),
      title: Text(S.current.Acc_Kitsu_Title),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.current.Acc_Kitsu_Hint,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _username,
                enabled: !_busy,
                autofocus: widget.initialUsername == null,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                decoration: InputDecoration(
                  labelText: S.current.Acc_Kitsu_Username,
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  border: const OutlineInputBorder(),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                focusNode: _passwordFocus,
                enabled: !_busy,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: S.current.Acc_Kitsu_Password,
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: _obscure
                        ? S.current.Acc_Show_Password
                        : S.current.Acc_Hide_Password,
                    icon: Icon(_obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: _required,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, size: 18, color: colors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: colors.error),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(S.current.Cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(S.current.Log_In),
        ),
      ],
    );
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? S.current.Acc_Field_Required : null;
}
