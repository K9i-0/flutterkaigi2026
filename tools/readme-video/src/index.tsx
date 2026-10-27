import React from "react";
import {
  registerRoot,
  Composition,
  AbsoluteFill,
  Sequence,
  OffthreadVideo,
  Audio,
  staticFile,
  useCurrentFrame,
  interpolate,
} from "remotion";
import manifest from "./edit-manifest.json";

const Trailer = () => {
  const frame = useCurrentFrame();
  const uiScale = manifest.composition.height / 720;
  const caption = manifest.captions.find(
    (c) => frame >= c.startFrame && frame < c.endFrame,
  );
  const captionOpacity = caption
    ? interpolate(
        frame,
        [
          caption.startFrame,
          caption.startFrame + 10,
          caption.endFrame - 10,
          caption.endFrame,
        ],
        [0, 1, 1, 0],
        { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
      )
    : 0;
  const fadeOut = interpolate(
    frame,
    [
      manifest.composition.durationInFrames - 28,
      manifest.composition.durationInFrames - 1,
    ],
    [0, 1],
    { extrapolateLeft: "clamp" },
  );
  return (
    <AbsoluteFill style={{ background: "#081b26" }}>
      {manifest.shots.map((shot, index) => (
        <Sequence
          key={index}
          from={shot.startFrame}
          durationInFrames={shot.endFrame - shot.startFrame}
        >
          <OffthreadVideo
            src={staticFile(shot.file)}
            startFrom={shot.trimFrame}
            muted
            style={{ width: "100%", height: "100%", objectFit: "cover" }}
          />
        </Sequence>
      ))}
      <Sequence from={manifest.audio.startFrame}>
        <Audio src={staticFile(manifest.audio.file)} />
      </Sequence>
      {caption && (
        <>
          <div
            style={{
              position: "absolute",
              left: 0,
              right: 0,
              bottom: 0,
              height: 100 * uiScale,
              background: "linear-gradient(transparent, rgba(0,0,0,0.32))",
              opacity: captionOpacity,
            }}
          />
          <div
            style={{
              position: "absolute",
              bottom: 31 * uiScale,
              left: 70 * uiScale,
              right: 70 * uiScale,
              textAlign: "center",
              fontFamily:
                '"Hiragino Kaku Gothic ProN", "Hiragino Sans", sans-serif',
              fontSize: 25 * uiScale,
              fontWeight: 400,
              lineHeight: 1.4,
              letterSpacing: "0.025em",
              color: "#fff",
              textShadow: "0 1px 4px #000, 0 0 12px #0008",
              opacity: captionOpacity,
            }}
          >
            {caption.text}
          </div>
        </>
      )}
      <AbsoluteFill style={{ background: "#081b26", opacity: fadeOut }} />
    </AbsoluteFill>
  );
};
registerRoot(() => (
  <Composition {...manifest.composition} component={Trailer} />
));
