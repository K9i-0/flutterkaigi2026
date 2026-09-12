import 'dart:async';

/// Owns one successful asset-load claim per resident region. The previous
/// region remains recoverable until the replacement has mounted and warmed.
/// Scene removal and reference removal belong in [detach], before [release].
class HazardRegionLoader<T extends Object> {
  HazardRegionLoader({
    required this.acquire,
    required this.release,
    required this.prepare,
    required this.attach,
    required this.detach,
    required this.warmUp,
    this.onChanged,
  });

  final Future<T> Function(String id) acquire;
  final Future<void> Function(String id) release;
  final void Function(String id, T resource) prepare;
  final void Function(String id, T resource) attach;
  final void Function(String id, T resource) detach;
  final Future<void> Function() warmUp;
  final void Function()? onChanged;
  String? currentId, targetId;
  T? current;
  Object? error;
  Object? releaseError;
  bool loading = false, _disposed = false;
  Future<bool>? _operation;

  /// [commit] runs synchronously only after preparation succeeds. It should
  /// perform the already-validated gameplay transition without awaiting I/O.
  Future<bool> activate(String id, {required void Function() commit}) {
    if (_disposed || loading) return Future.value(false);
    loading = true;
    targetId = id;
    error = null;
    onChanged?.call();
    return _operation = _activate(id, commit);
  }

  Future<bool> _activate(String id, void Function() commit) async {
    final previous = current, previousId = currentId;
    T? candidate;
    var previousDetached = false, candidateAttached = false;
    try {
      if (previousId == id) {
        commit();
        return true;
      }
      candidate = await acquire(id);
      if (_disposed) return false;
      prepare(id, candidate);
      if (previous != null) {
        detach(previousId!, previous);
        previousDetached = true;
      }
      // Record before calling attach so a partial mount is also rolled back.
      candidateAttached = true;
      attach(id, candidate);
      await warmUp();
      if (_disposed) return false;
      commit();
      current = candidate;
      currentId = id;
      candidate = null; // Ownership transferred; finally must not release it.
      if (previous != null) await _release(previousId!);
      return true;
    } catch (failure) {
      error = failure;
      return false;
    } finally {
      if (candidate != null) {
        if (candidateAttached) detach(id, candidate);
        if (previousDetached && !_disposed) attach(previousId!, previous!);
        // acquire throwing owns no claim: the registry rolls that back itself.
        await _release(id);
      }
      loading = false;
      if (error == null) targetId = null;
      if (!_disposed) onChanged?.call();
    }
  }

  Future<void> _release(String id) async {
    try {
      await release(id);
    } catch (failure) {
      // The world has already committed or rolled back. A cleanup failure
      // cannot safely turn that completed gameplay operation into a retry.
      releaseError = failure;
    }
  }

  void clearError() {
    if (loading) return;
    error = null;
    targetId = null;
    if (!_disposed) onChanged?.call();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    // A late successful acquire is released by its own finally block.
    await _operation;
    final resource = current, id = currentId;
    current = null;
    currentId = null;
    if (resource != null) {
      detach(id!, resource);
      await _release(id);
    }
  }
}
