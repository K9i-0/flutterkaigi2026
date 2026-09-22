import React from 'react';
import {AbsoluteFill, Composition, OffthreadVideo, staticFile, useCurrentFrame} from 'remotion';
import manifest from './edit-manifest.json';
import './style.css';

const fade = (frame: number, start: number, end: number) => Math.max(0, Math.min(1, (frame-start)/8, (end-frame)/8));
const Documentary: React.FC<{preview?: boolean}> = ({preview=false}) => {
  const frame=useCurrentFrame();
  return <AbsoluteFill className="documentary">
    {preview ? <AbsoluteFill className="layout-background"><div className="preview-note">テロップ設計プレビュー／本編映像は未生成</div></AbsoluteFill> : <OffthreadVideo src={staticFile(manifest.inputVideo)} style={{width:'100%',height:'100%',objectFit:'contain'}}/>}
    <div className="station">YHK</div>
    {manifest.overlays.map((item,i) => frame>=item.startFrame && frame<item.endFrame ? <div key={i} className={`overlay ${item.kind}`} style={{opacity:fade(frame,item.startFrame,item.endFrame)}}>
      {'kicker' in item && <div className="kicker">{item.kicker}</div>}
      <div className="main-text">{item.text}</div>
      {'detail' in item && <div className="detail">{item.detail}</div>}
    </div> : null)}
    {manifest.captions.map((item,i) => frame>=item.startFrame && frame<item.endFrame ? <div key={i} className="caption" style={{opacity:fade(frame,item.startFrame,item.endFrame)}}>{item.text}</div> : null)}
  </AbsoluteFill>;
};
export const Root: React.FC = () => <>
  <Composition id="YhkDocumentary" component={Documentary} width={manifest.composition.width} height={manifest.composition.height} fps={manifest.composition.fps} durationInFrames={manifest.composition.durationInFrames}/>
  <Composition id="YhkLayoutPreview" component={Documentary} defaultProps={{preview:true}} width={manifest.composition.width} height={manifest.composition.height} fps={manifest.composition.fps} durationInFrames={manifest.composition.durationInFrames}/>
</>;
