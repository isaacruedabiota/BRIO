import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object> get props => [message];

  // The SnackBar shows this directly — just the message, without the class name.
  @override
  String toString() => message;
}

final class NetworkFailure     extends Failure { const NetworkFailure(super.message); }
final class UnauthorizedFailure extends Failure { const UnauthorizedFailure(super.message); }
final class NotFoundFailure     extends Failure { const NotFoundFailure(super.message); }
final class ServerFailure       extends Failure { const ServerFailure(super.message); }
final class ValidationFailure   extends Failure { const ValidationFailure(super.message); }
final class CacheFailure        extends Failure { const CacheFailure(super.message); }
