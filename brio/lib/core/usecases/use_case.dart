abstract class UseCase<Output, Input> {
  Future<Output> call(Input params);
}

/// For use cases without input parameters.
class NoParams {
  const NoParams();
}
