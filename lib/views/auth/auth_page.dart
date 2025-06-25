import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLogin = true;
  String? localError;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthProvider auth) async {
    FocusScope.of(context).unfocus();
    if (!mounted) return;
    setState(() => localError = null);
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      if (!mounted) return;
      setState(() => localError = 'Veuillez entrer un email valide.');
      return;
    }
    if (password.length < 6) {
      if (!mounted) return;
      setState(
        () =>
            localError = 'Le mot de passe doit contenir au moins 6 caractères.',
      );
      return;
    }
    final success = isLogin
        ? await auth.signIn(email, password)
        : await auth.signUp(email, password);
    if (!mounted) return;
    if (success) {
      setState(() {
        localError = null;
      });
      if (auth.errorMessage != null) {
        // Efface l'erreur du provider si succès
        auth.errorMessage = null;
      }
    } else if (auth.errorMessage != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auth.errorMessage!,
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleMode(AuthProvider auth) {
    if (!mounted) return;
    setState(() {
      isLogin = !isLogin;
      localError = null;
    });
    auth.errorMessage = null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                ),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: auth.isLoading ? null : () => _submit(auth),
                  child: auth.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isLogin ? 'Se connecter' : 'Créer un compte'),
                ),
                TextButton(
                  onPressed: auth.isLoading ? null : () => _toggleMode(auth),
                  child: Text(
                    isLogin ? 'Créer un compte' : 'Déjà inscrit ? Se connecter',
                  ),
                ),
                if (localError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      localError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (auth.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: AnimatedOpacity(
                      opacity: auth.errorMessage != null ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        auth.errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (auth.isLoading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
