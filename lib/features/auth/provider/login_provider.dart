import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────
//  Login State
// ─────────────────────────────────────────────────────────────

enum LoginStatus { idle, loading, success, error }

class LoginState {
  const LoginState({
    this.phoneNumber = '',
    this.status = LoginStatus.idle,
    this.errorMessage,
  });

  final String phoneNumber;
  final LoginStatus status;
  final String? errorMessage;

  bool get isLoading => status == LoginStatus.loading;
  bool get hasError => status == LoginStatus.error;
  bool get isSuccess => status == LoginStatus.success;

  /// Basic validation: must have at least 10 digits (stripped of spaces/dashes)
  bool get isPhoneValid {
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10;
  }

  LoginState copyWith({
    String? phoneNumber,
    LoginStatus? status,
    String? errorMessage,
  }) {
    return LoginState(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}


class LoginNotifier extends StateNotifier<LoginState> {
  LoginNotifier() : super(const LoginState());

  void onPhoneChanged(String value) {
    state = state.copyWith(
      phoneNumber: value,
      status: LoginStatus.idle,
      errorMessage: null,
    );
  }

  Future<void> sendOtp() async {
    if (!state.isPhoneValid) {
      state = state.copyWith(
        status: LoginStatus.error,
        errorMessage: 'Please enter a valid phone number.',
      );
      return;
    }

    state = state.copyWith(status: LoginStatus.loading);
    await Future.delayed(const Duration(seconds: 2));
    state = state.copyWith(status: LoginStatus.success);
  }

  void reset() {
    state = const LoginState();
  }
}

final loginProvider =
StateNotifierProvider.autoDispose<LoginNotifier, LoginState>(
      (ref) => LoginNotifier(),
);