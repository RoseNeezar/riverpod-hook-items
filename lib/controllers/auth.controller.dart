import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:trackitem/repositories/auth.repo.dart';

final authControllerProvider =
    StateNotifierProvider((ref) => AuthController(ref.read)..appStarted());

class AuthController extends StateNotifier<User?> {
  final Reader _reader;

  StreamSubscription<User?>? _authStateChangesSubscription;

  AuthController(this._reader) : super(null) {
    _authStateChangesSubscription?.cancel();
    _authStateChangesSubscription = _reader(authRepositoryProvider)
        .authStateChanges
        .listen((user) => state = user);
  }

  @override
  void dispose() {
    _authStateChangesSubscription?.cancel();
    super.dispose();
  }

  void appStarted() async {
    final user = _reader(authRepositoryProvider).getCurrentUser();
    if (user == null) {
      await _reader(authRepositoryProvider).signInAnonymouusly();
    }
  }

  void signOut() async {
    await _reader(authRepositoryProvider).signOut();
  }
}
