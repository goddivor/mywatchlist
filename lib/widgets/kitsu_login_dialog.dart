import 'package:flutter/material.dart';

class KitsuLoginDialog extends StatefulWidget {
  final Function(String, String) onLogin;

  const KitsuLoginDialog({required this.onLogin, super.key});

  @override
  // ignore: library_private_types_in_public_api
  _KitsuLoginDialogState createState() => _KitsuLoginDialogState();
}

class _KitsuLoginDialogState extends State<KitsuLoginDialog> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Log in to Kitsu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Email address',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscureText,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final username = _usernameController.text.trim();
                final password = _passwordController.text.trim();
                widget.onLogin(username, password);
                Navigator.of(context).pop();
              },
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
