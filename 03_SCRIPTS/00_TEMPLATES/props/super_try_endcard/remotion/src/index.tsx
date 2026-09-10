import React from 'react';
import {Composition, registerRoot} from 'remotion';
import {Effects} from './Effects';
import effects from './effects-manifest.json';
const Root: React.FC=()=> <Composition id="SuperTryEndcardFinal" {...effects.composition} component={Effects} defaultProps={{mode:'B' as const,titleImage:'titles/title_meme.png',notice:true}}/>;
registerRoot(Root);
