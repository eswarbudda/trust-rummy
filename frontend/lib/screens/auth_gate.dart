import 'package:flutter/material.dart';

import '../services/auth_session_service.dart';
import '../services/user_presence_service.dart';
import 'lobby_screen.dart';
import 'login_screen.dart';

/// Switches between [LoginScreen] and [LobbyScreen] based on session,
/// and keeps `/ws/user` presence connected while signed in.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    AuthSessionService.instance.addListener(_syncPresence);
    _syncPresence();
  }

  @override
  void dispose() {
    AuthSessionService.instance.removeListener(_syncPresence);
    UserPresenceService.instance.disconnect();
    super.dispose();
  }

  void _syncPresence() {
    if (AuthSessionService.instance.isSignedIn) {
      UserPresenceService.instance.ensureConnected();
    } else {
      UserPresenceService.instance.disconnect();
    }
  }

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
