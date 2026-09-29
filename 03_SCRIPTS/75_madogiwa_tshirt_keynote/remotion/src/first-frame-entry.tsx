import React from 'react';
import {Composition, registerRoot} from 'remotion';
import {FirstFrameFilm} from './FirstFrame';
import edit from './first-frame.json';

registerRoot(() => <Composition id="MadogiwaKeynoteLargeFirstFrame"
  component={FirstFrameFilm} width={edit.width} height={edit.height}
  fps={edit.fps} durationInFrames={edit.durationInFrames} />);
