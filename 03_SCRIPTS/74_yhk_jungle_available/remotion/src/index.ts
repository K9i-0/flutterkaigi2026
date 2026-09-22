import {registerRoot} from 'remotion';
import {SetStudyRoot} from './set-study';
import {DocumentaryRoot} from './documentary';
import {createElement, Fragment} from 'react';
registerRoot(()=>createElement(Fragment,null,createElement(DocumentaryRoot),createElement(SetStudyRoot)));
