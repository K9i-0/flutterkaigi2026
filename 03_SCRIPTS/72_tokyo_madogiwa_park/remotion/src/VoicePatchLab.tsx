import {AbsoluteFill, OffthreadVideo, Sequence, staticFile} from 'remotion';
export const VoicePatchLab = () => <AbsoluteFill style={{backgroundColor: 'black'}}>
  {[{src: 'lab_before.mp4', label: '修正前：Wanの元音声'}, {src: 'lab_after.mp4', label: '検証：動画の声を参照したIrodoriで1.2秒だけ差し替え'}].map((clip, index) =>
    <Sequence key={clip.src} from={index * 155} durationInFrames={155}>
      <OffthreadVideo src={staticFile(clip.src)} style={{width: '100%', height: '100%'}} />
      <div style={{position: 'absolute', bottom: 0, left: 0, right: 0, background: '#000c', color: 'white', padding: '9px 16px', fontSize: 21, fontFamily: 'Hiragino Sans, sans-serif'}}>{clip.label}</div>
    </Sequence>)}
</AbsoluteFill>;
