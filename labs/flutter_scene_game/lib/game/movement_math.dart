import 'dart:math' as math;

/// Canonical voxel characters face local -Z after their model correction.
double characterFacingYaw(double moveX, double moveZ) =>
    math.atan2(-moveX, -moveZ);

/// Converts screen-space input into the handedness used by flutter_scene's
/// look-at camera (`right = up × forward`).
(double x, double z) cameraRelativeMovement({
  required double yaw,
  required double right,
  required double forward,
}) {
  final rightX = -math.cos(yaw);
  final rightZ = math.sin(yaw);
  final forwardX = -math.sin(yaw);
  final forwardZ = -math.cos(yaw);
  return (
    rightX * right + forwardX * forward,
    rightZ * right + forwardZ * forward,
  );
}
