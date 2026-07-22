import 'package:flutter/material.dart';

import '../services/auth_session_service.dart';
import 'lobby_screen.dart';
import 'login_screen.dart';

/// Switches between [LoginScreen] and [LobbyScreen] based on session.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthSessionService.instance,
      builder: (context, _) {
        final signedIn = AuthSessionService.instance.isSignedIn;
        return signedIn ? const LobbyScreen() : const LoginScreen();
      },
    );
  }
}
