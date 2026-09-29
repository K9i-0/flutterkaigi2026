import React from 'react';
import {AbsoluteFill, Composition, OffthreadVideo, Sequence, registerRoot, staticFile} from 'remotion';

const clips = [
  ['okayaman_original.mp4', '元動画', 'おかやまん！大変驚いております！'],
  ['okayaman_small_not.mp4', 'Small：動画の声を参照', '大変驚いていません！'],
  ['okayaman_large_not.mp4', 'Large：動画の声を参照', '大変驚いていません！'],
  ['okayaman_large_not_seed43.mp4', 'Large：否定形の再試行（seed43）', '大変驚いていません！'],
  ['okayaman_large_gyun.mp4', 'Large：動画の声を参照', 'ギュンギュンしています！'],
];
const Compare: React.FC = () => <AbsoluteFill style={{backgroundColor: 'black'}}>
  {clips.map(([src, label, text], index) => <Sequence key={src} from={index * 141} durationInFrames={141}>
    <OffthreadVideo src={staticFile(src)} style={{width: '100%', height: '100%'}} />
    <div style={{position: 'absolute', bottom: 0, left: 0, right: 0, background: '#000d', color: 'white', padding: '8px 18px', fontFamily: 'Hiragino Sans, sans-serif', fontSize: 20}}>
      <div style={{fontSize: 16, color: '#a9d9ff'}}>{index + 1}/5　{label}</div>
      {text}<span style={{fontSize: 13, marginLeft: 15}}>※表示は入力台詞</span>
    </div>
  </Sequence>)}
</AbsoluteFill>;
registerRoot(() => <Composition id="OkayamanPatch" component={Compare} width={854} height={480} fps={30} durationInFrames={705} />);
