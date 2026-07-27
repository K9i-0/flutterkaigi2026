/**
 * The canonical Sobaya model faces local -Z. Keep movement, attacks and the
 * rendered character on that same axis so he never appears to moonwalk.
 */
export function getPlayerFacingYaw(moveX: number, moveZ: number) {
  return Math.atan2(-moveX, -moveZ);
}

export function getPlayerForward(yaw: number) {
  return {
    x: -Math.sin(yaw),
    z: -Math.cos(yaw),
  };
}
