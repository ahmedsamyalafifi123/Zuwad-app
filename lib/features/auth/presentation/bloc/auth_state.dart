import 'package:equatable/equatable.dart';
import '../../domain/models/student.dart';
import '../../domain/models/teacher.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final Student? student;
  
  const AuthAuthenticated({this.student});
  
  @override
  List<Object?> get props => [student];
}

class AuthTeacherAuthenticated extends AuthState {
  final Teacher? teacher;

  const AuthTeacherAuthenticated({this.teacher});

  @override
  List<Object?> get props => [teacher];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  
  const AuthError(this.message);
  
  @override
  List<Object> get props => [message];
}
