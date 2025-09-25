import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository = AuthRepository();
  
  AuthBloc() : super(AuthInitial()) {
    on<CheckAuthStatusEvent>(_onCheckAuthStatus);
    on<LoginWithPhoneEvent>(_onLoginWithPhone);
    on<LogoutEvent>(_onLogout);
    on<GetStudentProfileEvent>(_onGetStudentProfile);
  }
  
  Future<void> _onCheckAuthStatus(
    CheckAuthStatusEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final isLoggedIn = await _authRepository.isLoggedIn();
      if (kDebugMode) {
        print('Check auth status - isLoggedIn: $isLoggedIn');
      }
      
      if (isLoggedIn) {
        try {
          final student = await _authRepository.getStudentProfile();
          if (kDebugMode) {
            print('Student profile loaded: ${student.name}');
          }
          emit(AuthAuthenticated(student: student));
        } catch (e) {
          // If we can't get the profile but user is logged in
          if (kDebugMode) {
            print('Error getting profile but user is logged in: $e');
          }
          emit(const AuthAuthenticated());
        }
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking auth status: $e');
      }
      emit(AuthError('فشل في التحقق من حالة المصادقة'));
    }
  }
  
  Future<void> _onLoginWithPhone(
    LoginWithPhoneEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      if (kDebugMode) {
        print('Attempting login with phone: ${event.phone}');
      }
      
      final success = await _authRepository.login(
        event.phone,
        event.password,
      );
      
      if (kDebugMode) {
        print('Login success: $success');
      }
      
      if (success) {
        try {
          final student = await _authRepository.getStudentProfile();
          if (kDebugMode) {
            print('Student profile after login: ${student.toDebugString()}');
          }
          emit(AuthAuthenticated(student: student));
        } catch (e) {
          // If we can't get the profile but login was successful
          if (kDebugMode) {
            print('Login successful but error getting profile: $e');
          }
          emit(const AuthAuthenticated());
        }
      } else {
        emit(const AuthError('رقم الهاتف أو كلمة المرور غير صحيحة'));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Login error: $e');
      }
      emit(AuthError('فشل تسجيل الدخول: ${e.toString()}'));
    }
  }
  
  Future<void> _onLogout(
    LogoutEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authRepository.logout();
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError('فشل تسجيل الخروج: ${e.toString()}'));
    }
  }
  
  Future<void> _onGetStudentProfile(
    GetStudentProfileEvent event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthAuthenticated) {
      emit(AuthLoading());
      try {
        final student = await _authRepository.getStudentProfile();
        emit(AuthAuthenticated(student: student));
      } catch (e) {
        emit(AuthError('فشل في الحصول على الملف الشخصي: ${e.toString()}'));
      }
    }
  }
}
