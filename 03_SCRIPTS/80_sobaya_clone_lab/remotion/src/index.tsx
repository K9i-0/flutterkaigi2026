import React from 'react';
import {AbsoluteFill, Composition, interpolate, registerRoot, useCurrentFrame} from 'remotion';
import m from './edit-manifest.json';

const C = {cyan: '#78f5df', dim: '#73918b', white: '#ecf7f1', amber: '#ffc66b', red: '#ff685d'};
const mono = '"SFMono-Regular", Menlo, monospace';
const font = '"Hiragino Sans", "Noto Sans JP", sans-serif';
const progress = (f: number, start: number, end: number) =>
  interpolate(f, [start, end], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
const fmt = (n: number) => Math.round(n).toLocaleString('en-US');

const Target: React.FC<{index: number}> = ({index}) => {
  const frame = useCurrentFrame();
  const subject = m.subjects[index];
  const start = index ? m.timing.yameStart : m.timing.fukuStart;
  const end = index ? m.timing.yameEnd : m.timing.fukuEnd;
  const p = progress(frame, start, end);
  const active = frame >= start;
  const done = frame >= end;
  const color = done ? (index ? C.red : C.amber) : C.cyan;
  return <>
    <div style={{position: 'absolute', left: subject.x, top: subject.y, width: subject.w, height: subject.h}}>
      <svg width={subject.w} height={subject.h} style={{position: 'absolute', opacity: 0.7}}>
        <path d={`M 0 40 V 0 H 40 M ${subject.w - 40} 0 H ${subject.w} V 40 M 0 ${subject.h - 40} V ${subject.h} H 40 M ${subject.w - 40} ${subject.h} H ${subject.w} V ${subject.h - 40}`} fill="none" stroke={color} strokeWidth="3"/>
      </svg>
      {active && !done && <div style={{position: 'absolute', left: 2, right: 2, top: p * (subject.h - 50), height: 50, background: `linear-gradient(transparent,${color}25)`, borderBottom: `2px solid ${color}`}}/>}
    </div>
    <div style={{position: 'absolute', left: subject.x - 35, top: 584, width: subject.w + 70, height: 265, padding: '18px 35px', boxSizing: 'border-box', background: 'linear-gradient(90deg,rgba(4,17,20,.95),rgba(4,17,20,.72))', borderTop: `2px solid ${color}`}}>
      <div style={{display: 'flex', alignItems: 'center', justifyContent: 'space-between'}}>
        <span style={{fontSize: 42}}>{subject.name}</span>
        <span style={{fontSize: 30, color, letterSpacing: 3}}>{done ? subject.classification : active ? '測定中' : ''}</span>
      </div>
      <div style={{display: 'flex', alignItems: 'baseline', gap: 18, marginTop: 6}}>
        <span style={{fontFamily: mono, fontSize: 152, lineHeight: 1.12, letterSpacing: -8, color, fontVariantNumeric: 'tabular-nums'}}>{active ? fmt(subject.value * p) : '—'}</span>
        <span style={{fontFamily: mono, fontSize: 34, color: C.dim}}>MW</span>
      </div>
    </div>
  </>;
};

export const MadogiwaScanner: React.FC<{preview?: boolean}> = ({preview = false}) => {
  const frame = useCurrentFrame();
  const alarm = frame >= m.timing.yameEnd;
  const capture = frame >= m.timing.capture;
  return <AbsoluteFill style={{fontFamily: font, color: C.white, background: preview ? '#071416' : 'transparent'}}>
    {preview && <AbsoluteFill style={{backgroundImage: 'radial-gradient(ellipse at 45% 45%,#173b36 0%,transparent 70%),linear-gradient(#21443e22 1px,transparent 1px),linear-gradient(90deg,#21443e22 1px,transparent 1px)', backgroundSize: '100% 100%,80px 80px,80px 80px'}}/>}
    <AbsoluteFill style={{opacity: progress(frame, 0, m.timing.bootEnd)}}>
      <div style={{position: 'absolute', left: 110, right: 110, top: 68, display: 'flex', justifyContent: 'space-between', alignItems: 'baseline'}}>
        <div style={{fontSize: 40, letterSpacing: 5, color: C.cyan}}>窓際力測定</div>
        <div style={{fontSize: 27, color: C.white}}>標準窓際社員 ＝ 10 MW</div>
      </div>
      <Target index={0}/><Target index={1}/>
      {alarm && <div style={{position: 'absolute', left: 110, right: 110, top: 888, height: 112, display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#3b1716ef', borderTop: `2px solid ${C.red}`, color: C.red, fontSize: capture ? 52 : 62, letterSpacing: 9, opacity: progress(frame, m.timing.yameEnd, m.timing.yameEnd + 4)}}>
        {capture ? '両名を捕獲せよ' : '規格外の窓際力を検出'}
      </div>}
      <div style={{position: 'absolute', left: 110, right: 110, bottom: 38, display: 'flex', justifyContent: 'space-between', fontFamily: mono, fontSize: 13, letterSpacing: 1.5, color: C.dim, opacity: 0.65}}>
        <span>TAKO LAB / MW-ANALYZER 07 / RELATIVE INDEX</span>
        <span>原体 SOBA-01 : {fmt(m.reference.sobaya)} MW / {capture ? '生体回収・損傷厳禁' : '比較検体検索中'}</span>
      </div>
    </AbsoluteFill>
  </AbsoluteFill>;
};

const Root: React.FC = () => <>{[true, false].map(preview => <Composition key={String(preview)} id={preview ? 'ScannerPreview' : 'ScannerOverlay'} component={MadogiwaScanner} {...m.composition} defaultProps={{preview}}/>)}</>;
registerRoot(Root);
