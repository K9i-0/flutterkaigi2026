import React from 'react';
import {AbsoluteFill, Composition, Img, OffthreadVideo, Sequence, staticFile, interpolate, registerRoot, useCurrentFrame} from 'remotion';
import m from './edit-manifest.json';
import production from './production-edit.json';
import horror from './horror-edit.json';

const C = {cyan: '#78f5df', dim: '#73918b', white: '#ecf7f1', amber: '#ffc66b', red: '#ff685d'};
const mono = '"SFMono-Regular", Menlo, monospace';
const font = '"Hiragino Sans", "Noto Sans JP", sans-serif';
const progress = (f: number, start: number, end: number) =>
  interpolate(f, [start, end], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
const fmt = (n: number) => Math.round(n).toLocaleString('en-US');

const Target: React.FC<{index: number}> = ({index}) => {
  const frame = useCurrentFrame();
  const subject = m.subjects[index];
  const isYametaro = subject.id === "02";
  const start = isYametaro ? m.timing.yameStart : m.timing.fukuStart;
  const end = isYametaro ? m.timing.yameEnd : m.timing.fukuEnd;
  const p = progress(frame, start, end);
  const active = frame >= start;
  const done = frame >= end;
  const color = done ? (isYametaro ? C.red : C.amber) : C.cyan;
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

export const MadogiwaScanner: React.FC<{preview?: boolean; captureDelay?: number}> = ({preview = false, captureDelay = 0}) => {
  const frame = useCurrentFrame();
  const alarm = frame >= m.timing.yameEnd;
  const capture = frame >= m.timing.capture + captureDelay;
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

export const CloneLabFilm: React.FC<{extraFrames?: number}> = ({extraFrames = 0}) => <AbsoluteFill style={{background: '#000'}}>
  <Sequence durationInFrames={horror.scanExtension.sourceCutFrame}>
    <OffthreadVideo src={staticFile(production.inputVideo)} style={{width:'100%',height:'100%',objectFit:'contain'}}/>
  </Sequence>
  <Sequence from={horror.scanExtension.sourceCutFrame+extraFrames} durationInFrames={production.composition.durationInFrames-horror.scanExtension.sourceCutFrame}>
    <OffthreadVideo src={staticFile(production.inputVideo)} startFrom={horror.scanExtension.sourceCutFrame} style={{width:'100%',height:'100%',objectFit:'contain'}}/>
  </Sequence>
  <Sequence from={production.scannerStartFrame} durationInFrames={production.scannerDurationInFrames+extraFrames}>
    <AbsoluteFill style={{background: 'radial-gradient(ellipse at center,#16302d,#061214 75%)'}}>
      {production.scannerPortraits.map((p, i) => {
        const scale = p.size / p.cropSize;
        return <div key={i} style={{position: 'absolute',left:p.left,top:p.top,width:p.size,height:p.size,overflow:'hidden'}}>
          <Img src={staticFile(production.scannerStillImage)} style={{position:'absolute',maxWidth:'none',width:854*scale,height:480*scale,left:-p.cropX*scale,top:-p.cropY*scale}}/>
        </div>;
      })}
    </AbsoluteFill>
    <MadogiwaScanner captureDelay={extraFrames}/>
  </Sequence>
</AbsoluteFill>;

const HorrorTitle: React.FC = () => {
  const frame = useCurrentFrame();
  const titleFrames = horror.durationFrames-horror.titleStartFrame;
  const opacity = 1-progress(frame,titleFrames-horror.titleFadeOutFrames,titleFrames-1);
  const shake = interpolate(frame,horror.endingImpact.shakeFrames,horror.endingImpact.shakePixels,{extrapolateRight:'clamp'});
  const scale = interpolate(frame,[0,titleFrames-1],[1,1.025],{extrapolateRight:'clamp'});
  return <AbsoluteFill style={{background:'#000',overflow:'hidden',opacity}}>
    <Img src={staticFile(horror.titleBackground)} style={{width:'100%',height:'100%',objectFit:'cover',transform:`scale(${scale})`}}/>
    <AbsoluteFill style={{background:'linear-gradient(transparent 42%,rgba(0,0,0,.15) 62%,rgba(0,0,0,.72) 100%)'}}/>
    <div style={{position:'absolute',left:180,bottom:52,width:1560,height:350,overflow:'hidden',mixBlendMode:'screen',maskImage:'linear-gradient(transparent,black 12%,black 91%,transparent)',transform:`translateX(${shake}px)`}}>
      <Img src={staticFile(horror.titleImage)} style={{position:'absolute',left:0,top:-260,width:1560,height:'auto',maskImage:'linear-gradient(to right,transparent,black 6%,black 94%,transparent)'}}/>
    </div>
  </AbsoluteFill>;
};
export const CloneLabHorror: React.FC = () => <AbsoluteFill style={{background:'#000'}}>
  <Sequence durationInFrames={production.composition.durationInFrames+horror.scanExtension.extraFrames}><CloneLabFilm extraFrames={horror.scanExtension.extraFrames}/></Sequence>
  <Sequence from={horror.povReplacement.startFrame} durationInFrames={horror.povReplacement.durationFrames}>
    <OffthreadVideo muted src={staticFile('pov-replacement.mp4')} playbackRate={horror.povReplacement.playbackRate} style={{width:'100%',height:'100%',objectFit:'contain'}}/>
  </Sequence>
  <Sequence from={horror.titleStartFrame} durationInFrames={horror.durationFrames-horror.titleStartFrame}><HorrorTitle/></Sequence>
</AbsoluteFill>;

const Root: React.FC = () => <><Composition id="CloneLabHorror" component={CloneLabHorror} {...production.composition} durationInFrames={horror.durationFrames}/><Composition id="CloneLabFilm" component={CloneLabFilm} {...production.composition}/>{[true, false].map(preview => <Composition key={String(preview)} id={preview ? 'ScannerPreview' : 'ScannerOverlay'} component={MadogiwaScanner} {...m.composition} defaultProps={{preview}}/>)}</>;
registerRoot(Root);
