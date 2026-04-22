import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/models/student.dart';
import '../../../../features/student_dashboard/domain/services/student_selection_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository = AuthRepository();

  AuthBloc() : super(AuthInitial()) {
    on<CheckAuthStatusEvent>(_onCheckAuthStatus);
    on<LoginWithPhoneEvent>(_onLoginWithPhone);
    on<LoginAsTeacherEvent>(_onLoginAsTeacher);
    on<LogoutEvent>(_onLogout);
    on<GetStudentProfileEvent>(_onGetStudentProfile);
  }

  // Transient failures (rate limits, brief network blips) should not surface
  // as errors to the user. Retry a few times with exponential backoff before
  // giving up.
  Future<Student> _fetchStudentProfileWithRetry({int maxAttempts = 3}) async {
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await _authRepository.getStudentProfile();
      } catch (e) {
        lastError = e;
        if (kDebugMode) {
          print('getStudentProfile attempt $attempt/$maxAttempts failed: $e');
        }
        if (attempt < maxAttempts) {
          final delayMs = 500 * (1 << (attempt - 1)); // 500ms, 1s, 2s
          await Future.delayed(Duration(milliseconds: delayMs));
        }
      }
    }
    throw lastError ?? Exception('Failed to fetch student profile');
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
        final role = await _authRepository.getCurrentUserRole();
        if (role == 'teacher') {
          try {
            final teacher = await _authRepository.getTeacherProfile();
            if (kDebugMode) {
              print('Teacher profile loaded: ${teacher.name}');
            }
            emit(AuthTeacherAuthenticated(teacher: teacher));
          } catch (e) {
            if (kDebugMode) {
              print('Error getting teacher profile but user is logged in: $e');
            }
            emit(const AuthTeacherAuthenticated());
          }
        } else {
          try {
            final student = await _fetchStudentProfileWithRetry();
            if (kDebugMode) {
              print('Student profile loaded: ${student.name}');
            }
            emit(AuthAuthenticated(student: student));
          } catch (e) {
            // Retries exhausted. Emit AuthError rather than
            // AuthAuthenticated(null) so the dashboard can show a proper
            // loading state and trigger a single auto-retry cycle.
            if (kDebugMode) {
              print('Error getting profile after retries but user is logged in: $e');
            }
            emit(AuthError('فشل في الحصول على الملف الشخصي: ${e.toString()}'));
          }
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
        final role = await _authRepository.getCurrentUserRole();
        if (role == 'teacher') {
          // Call the dedicated teacher-login endpoint to get full teacher+students data
          try {
            final teacher = await _authRepository.teacherLogin(
              event.phone,
              event.password,
            );
            if (kDebugMode) {
              print('Teacher login via teacher API: ${teacher.name}');
            }
            emit(AuthTeacherAuthenticated(teacher: teacher));
          } catch (e) {
            if (kDebugMode) {
              print('Teacher-login API failed, falling back to profile: $e');
            }
            try {
              final teacher = await _authRepository.getTeacherProfile();
              emit(AuthTeacherAuthenticated(teacher: teacher));
            } catch (_) {
              emit(const AuthTeacherAuthenticated());
            }
          }
        } else {
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

                await _authRepository.switchUser(bestStudent);
              }
            } catch (e) {
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
            if (kDebugMode) {
              print('Login successful but error getting profile: $e');
            }
            emit(const AuthAuthenticated());
          }
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

  Future<void> _onLoginAsTeacher(
    LoginAsTeacherEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      if (kDebugMode) {
        print('Attempting teacher login with phone: ${event.phone}');
      }
      final teacher = await _authRepository.teacherLogin(event.phone, event.password);
      if (kDebugMode) {
        print('Teacher login success: ${teacher.name}');
      }
      emit(AuthTeacherAuthenticated(teacher: teacher));
    } catch (e) {
      if (kDebugMode) {
        print('Teacher login error: $e');
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
    if (state is AuthAuthenticated || state is AuthError) {
      // Preserve the current student data so the UI stays functional
      // during a profile refresh failure (e.g. rate limiting, network glitch).
      final currentStudent =
          state is AuthAuthenticated ? (state as AuthAuthenticated).student : null;

      emit(AuthLoading());
      try {
        final student = await _fetchStudentProfileWithRetry();
        emit(AuthAuthenticated(student: student));
      } catch (e) {
        if (kDebugMode) {
          print('GetStudentProfile failed after retries: $e');
        }
        // If we already have student data, keep the authenticated state
        // instead of showing the error screen for transient failures.
        if (currentStudent != null) {
          emit(AuthAuthenticated(student: currentStudent));
        } else {
          emit(AuthError('فشل في الحصول على الملف الشخصي: ${e.toString()}'));
        }
      }
    }
  }
}
