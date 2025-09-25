import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class LoginWithPhoneEvent extends AuthEvent {
  final String phone;
  final String password;

  const LoginWithPhoneEvent({
    required this.phone,
    required this.password,
  });

  @override
  List<Object> get props => [phone, password];
}

class CheckAuthStatusEvent extends AuthEvent {}

class LogoutEvent extends AuthEvent {}

class GetStudentProfileEvent extends AuthEvent {}
