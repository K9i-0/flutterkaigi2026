import React from 'react';
import {AbsoluteFill, Composition, OffthreadVideo, Sequence, registerRoot, staticFile} from 'remotion';
import manifest from './edit-manifest.json';
import {BattleFilm} from './BattleFilm';
import battleManifest from './battle-manifest.json';

const Remake: React.FC = () => (
  <AbsoluteFill style={{backgroundColor: 'black'}}>
    {manifest.segments.map((segment) => (
      <Sequence key={segment.id} from={segment.from} durationInFrames={segment.durationInFrames}>
        <OffthreadVideo
          src={staticFile(segment.src)}
          trimBefore={segment.trimBefore}
          trimAfter={segment.trimAfter}
          style={{width: '100%', height: '100%', objectFit: 'contain'}}
        />
      </Sequence>
    ))}
  </AbsoluteFill>
);

const Root: React.FC = () => (
  <>
  <Composition {...manifest.composition} component={Remake} />
  <Composition id="SovangelionBattle" component={BattleFilm} {...battleManifest.composition} />
  </>
);
registerRoot(Root);
