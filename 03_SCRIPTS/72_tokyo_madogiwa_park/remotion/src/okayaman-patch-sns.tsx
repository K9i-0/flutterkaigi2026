import React from 'react';
import {AbsoluteFill, Composition, OffthreadVideo, Sequence, registerRoot, staticFile} from 'remotion';

const clips = [
  ['okayaman_original.mp4', '元動画のセリフ', 'おかやまん！大変驚いております！'],
  ['okayaman_large_not_seed43.mp4', 'Irodori v4 Largeでセリフを改変①', '大変驚いていません！'],
  ['okayaman_large_gyun.mp4', 'Irodori v4 Largeでセリフを改変②', 'ギュンギュンしています！'],
];
const Compare: React.FC = () => <AbsoluteFill style={{backgroundColor: 'black'}}>
  {clips.map(([src, label, text], index) => <Sequence key={src} from={index * 141} durationInFrames={141}>
    <OffthreadVideo src={staticFile(src)} style={{width: '100%', height: '100%'}} />
    <div style={{position: 'absolute', bottom: 0, left: 0, right: 0, background: '#000d', color: 'white', padding: '8px 18px', fontFamily: 'Hiragino Sans, sans-serif', fontSize: 20}}>
      <div style={{fontSize: 16, color: '#a9d9ff'}}>{index + 1}/3　{label}</div>
      {text}
    </div>
  </Sequence>)}
</AbsoluteFill>;
registerRoot(() => <Composition id="OkayamanPatchSns" component={Compare} width={854} height={480} fps={30} durationInFrames={423} />);
