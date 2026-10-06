import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

String userFacingError(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Email or password is incorrect.';
    }
    if (message.contains('email not confirmed')) {
      return 'Please confirm your email before signing in.';
    }
    if (message.contains('already registered') || message.contains('already been registered')) {
      return 'An account with this email already exists. Try signing in.';
    }
    if (message.contains('password')) {
      return 'The password could not be accepted. Please check it and try again.';
    }
    return 'Account sign-in could not be completed. Please try again.';
  }

  if (error is PostgrestException) {
    return 'The online service could not complete that action. Please try again.';
  }

  if (error is SocketException) {
    return 'No internet connection. SBILL will keep working offline.';
  }

  if (error is TimeoutException) {
    return 'The request timed out. Please try again.';
  }

  return fallback;
}
