import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/auth_repository.dart';
import '../../../../features/student_dashboard/domain/services/student_selection_service.dart';
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
        role: 'student', // Always login as student in this app
      );

      if (kDebugMode) {
        print('Login success: $success');
      }

      if (success) {
        try {
          // Smart Student Selection Logic
          try {
            if (kDebugMode) {
              print('Smart Selection: Fetching family members...');
            }
            final family = await _authRepository.getFamilyMembers();

            if (family.length > 1) {
              if (kDebugMode) {
                print(
                    'Smart Selection: Found ${family.length} family members, calculating best student...');
              }
              final selectionService = StudentSelectionService();
              final bestStudent =
                  await selectionService.determineBestStudent(family);

              if (kDebugMode) {
                print(
                    'Smart Selection: Best student determined: ${bestStudent.name} (${bestStudent.id})');
              }

              // Switch to the best student before loading profile
              // This updates the stored user ID so getStudentProfile fetches the correct one
              await _authRepository.switchUser(bestStudent);
            }
          } catch (e) {
            // Silently fail smart selection and proceed with default student
            if (kDebugMode) {
              print('Smart Selection Error: $e');
            }
          }

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
