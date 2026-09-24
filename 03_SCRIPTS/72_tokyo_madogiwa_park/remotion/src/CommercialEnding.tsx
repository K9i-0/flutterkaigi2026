import {AbsoluteFill, Html5Audio, Img, Sequence, staticFile, useCurrentFrame, interpolate} from 'remotion';
import {EditComposition} from './Composition';
import reordered from './edit-manifest-reordered.json';
import timing from './commercial-timing.json';

const ProductCard = () => {
  const f = useCurrentFrame();
  const scale = interpolate(f, [0, 10], [0.88, 1], {extrapolateRight: 'clamp'});
  return <AbsoluteFill style={{background: '#ffdf30', fontFamily: 'Hiragino Sans, sans-serif', color: '#171717'}}>
    <div style={{position:'absolute', inset:14, border:'3px solid #171717'}} />
    <div style={{position:'absolute', left:34, top:35, width:360, height:380, overflow:'hidden', background:'white', borderRadius:18, transform:`scale(${scale})`, boxShadow:'8px 8px 0 #171717'}}>
      <Img src={staticFile('cm-product.webp')} style={{position:'absolute', width:756, maxWidth:'none', height:397, left:-397, top:0}} />
    </div>
    <div style={{position:'absolute', left:428, top:57, width:390}}>
      <div style={{fontSize:18, fontWeight:700, letterSpacing:4}}>WINDOW-SIDE CREW</div>
      <div style={{fontSize:55, fontWeight:900, lineHeight:1.2, marginTop:18}}>窓際族<br/>Tシャツ</div>
      <div style={{fontSize:30, fontWeight:800, marginTop:23}}>公式サイトで</div>
      <div style={{fontSize:45, fontWeight:900, color:'#c92320', marginTop:5}}>好評発売中！</div>
    </div>
    <div style={{position:'absolute', left:35, bottom:25, fontSize:15, letterSpacing:3, fontWeight:700}}>東京マドギワランド</div>
    <Sequence from={8}><Html5Audio src={staticFile('cm-sobaya.wav')} /></Sequence>
  </AbsoluteFill>;
};
export const CommercialEnding = ({edit = reordered}: {edit?: typeof reordered}) => <AbsoluteFill>
  <Sequence durationInFrames={edit.composition.durationInFrames}><EditComposition edit={edit}/></Sequence>
  <Sequence from={edit.composition.durationInFrames} durationInFrames={timing.duration}><ProductCard/></Sequence>
</AbsoluteFill>;
