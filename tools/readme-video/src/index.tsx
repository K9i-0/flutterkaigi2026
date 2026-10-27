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

const mint = "#68efcc";
const Shot: React.FC<{ shot: (typeof manifest.shots)[number] }> = ({
  shot,
}) => {
  const f = useCurrentFrame();
  const enter = interpolate(f, [0, 12], [0, 1], { extrapolateRight: "clamp" });
  const tilt = interpolate(
    f,
    [0, shot.endFrame - shot.startFrame],
    [-0.6, 0.6],
  );
  return (
    <AbsoluteFill>
      <div
        style={{
          position: "absolute",
          left: 64,
          top: 102,
          opacity: enter,
          transform: `translateY(${(1 - enter) * 10}px)`,
        }}
      >
        <div
          style={{
            color: mint,
            fontSize: 14,
            letterSpacing: 3,
            marginBottom: 6,
          }}
        >
          {shot.label}
        </div>
        <div
          style={{
            fontSize: 42,
            fontWeight: 700,
            lineHeight: 1.25,
            whiteSpace: "pre-line",
          }}
        >
          {shot.headline}
        </div>
      </div>
      <div
        style={{
          position: "absolute",
          left: 160,
          right: 160,
          top: 190,
          perspective: 1800,
        }}
      >
        <div
          style={{
            padding: 7,
            background: "#182f3b",
            border: "1px solid #50717c",
            borderRadius: 25,
            boxShadow: "0 28px 55px #0008",
            transform: `rotateY(${tilt}deg)`,
          }}
        >
          <OffthreadVideo
            src={staticFile(shot.file)}
            startFrom={shot.trimFrame}
            muted
            style={{ display: "block", width: "100%", borderRadius: 18 }}
          />
        </div>
      </div>
    </AbsoluteFill>
  );
};
const Trailer = () => {
  const f = useCurrentFrame();
  const c = manifest.captions.find((c) => f >= c.startFrame && f < c.endFrame);
  return (
    <AbsoluteFill
      style={{
        background: "#081b26",
        color: "#f7fbfb",
        fontFamily: '"Hiragino Sans", "Noto Sans JP", sans-serif',
        fontWeight: 500,
      }}
    >
      <AbsoluteFill
        style={{
          background:
            "radial-gradient(ellipse at 85% 30%, #13525388, transparent 65%)",
        }}
      />
      <div
        style={{
          position: "absolute",
          left: 64,
          right: 64,
          top: 40,
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          borderBottom: "1px solid #ffffff30",
          paddingBottom: 17,
        }}
      >
        <span style={{ fontSize: 17, letterSpacing: 2 }}>
          FLUTTERKAIGI 2026{" "}
          <span style={{ color: mint, marginLeft: 15 }}>GAME SHOWCASE</span>
        </span>
        <span style={{ fontSize: 23, fontWeight: 700 }}>
          ゆめテレ{" "}
          <span style={{ fontSize: 12, fontWeight: 500, color: "#a7c2cd" }}>
            特集
          </span>
        </span>
      </div>
      {manifest.shots.map((shot, i) => (
        <Sequence
          key={i}
          from={shot.startFrame}
          durationInFrames={shot.endFrame - shot.startFrame}
        >
          <Shot shot={shot} />
        </Sequence>
      ))}
      <Sequence from={manifest.audio.startFrame}>
        <Audio src={staticFile("narration.wav")} />
      </Sequence>
      <div
        style={{
          position: "absolute",
          bottom: 16,
          left: 64,
          right: 64,
          display: "flex",
          justifyContent: "space-between",
          fontSize: 11,
          color: "#9eb6c2",
          letterSpacing: 1,
        }}
      >
        <span>iPhone 18 Pro Simulator · 自動入力によるゲーム映像</span>
        <span>Flutter Scene × Dart</span>
      </div>
      {c && (
        <div
          style={{
            position: "absolute",
            left: 100,
            right: 100,
            bottom: 42,
            textAlign: "center",
            fontSize: 21,
            lineHeight: 1.45,
            color: "#fff",
            whiteSpace: "pre-line",
          }}
        >
          <span
            style={{
              background: "#081b26ed",
              boxShadow: "0 0 0 8px #081b26ed",
              borderBottom: "3px solid #258D91",
            }}
          >
            {c.text}
          </span>
        </div>
      )}
      <div
        style={{
          position: "absolute",
          bottom: 0,
          height: 3,
          width: `${(f / manifest.composition.durationInFrames) * 100}%`,
          background: mint,
        }}
      />
    </AbsoluteFill>
  );
};
registerRoot(() => (
  <Composition {...manifest.composition} component={Trailer} />
));
