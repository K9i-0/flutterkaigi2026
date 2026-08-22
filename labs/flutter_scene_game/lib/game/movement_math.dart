import 'dart:math' as math;

const double maxJumpClimb = 1.25;
const double jumpArcHeight = 1.25;

bool canTraverseHeight({
  required double currentHeight,
  required double targetHeight,
  double maxClimb = maxJumpClimb,
}) => targetHeight >= 0 && (targetHeight - currentHeight).abs() <= maxClimb;

double jumpArcOffset(double progress, {double height = jumpArcHeight}) {
  final t = progress.clamp(0.0, 1.0);
  return 4 * height * t * (1 - t);
}

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
