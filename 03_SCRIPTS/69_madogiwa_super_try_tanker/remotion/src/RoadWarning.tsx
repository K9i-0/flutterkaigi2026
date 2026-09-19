import React from 'react';
import {AbsoluteFill,Img,staticFile,useCurrentFrame,interpolate} from 'remotion';
export const RoadWarning:React.FC=()=>{const f=useCurrentFrame();const z=interpolate(f,[0,44],[1,1.045],{extrapolateRight:'clamp'});return <AbsoluteFill style={{overflow:'hidden',background:'#c0b5a2'}}>
<Img src={staticFile('chase_environment.jpg')} style={{width:'100%',height:'100%',objectFit:'cover',filter:'blur(6px)',transform:'scale(1.15)',opacity:.75}}/>
<AbsoluteFill style={{background:'linear-gradient(90deg,rgba(210,197,166,.25),rgba(151,179,189,.1))'}}/>
<div style={{position:'absolute',left:210,top:6,width:430,height:500,transform:`scale(${z})`,transformOrigin:'50% 65%',filter:'drop-shadow(5px 8px 5px rgba(0,0,0,.32))'}}>
<svg width="430" height="480" viewBox="0 0 430 480">
<defs><linearGradient id="pole"><stop stopColor="#626868"/><stop offset=".5" stopColor="#dfe3df"/><stop offset="1" stopColor="#828883"/></linearGradient><linearGradient id="yellow" x2="1" y2="1"><stop stopColor="#ffe36a"/><stop offset="1" stopColor="#edbc23"/></linearGradient></defs>
<path d="M204 245h22v235h-22z" fill="url(#pole)"/>
<path d="M215 18 L375 178 L215 338 L55 178 Z" fill="url(#yellow)" stroke="#35332b" strokeWidth="9" strokeLinejoin="round"/>
<g stroke="#24251f" strokeWidth="10" fill="none" strokeLinecap="round" strokeLinejoin="round">
<circle cx="130" cy="243" r="22"/><circle cx="235" cy="243" r="22"/><path d="M130 243l31-38h41l33 38m-74-38l21 38h-52m52 0l20-38 4-15h14M151 205h29"/>
<path d="M171 184l34-29 38 12 48-36m-74 26l-11 29-35 11m70-29l28 14 33-35" strokeWidth="17"/>
</g>
<ellipse cx="234" cy="124" rx="20" ry="26" fill="#f4f0e5" stroke="#24251f" strokeWidth="5" transform="rotate(27 234 124)"/>
<ellipse cx="228" cy="121" rx="4" ry="6" fill="#222"/><ellipse cx="242" cy="126" rx="4" ry="6" fill="#222"/><path d="M227 132l-3 10m16-6l-3 11" stroke="#c02b27" strokeWidth="5"/>
<path d="M265 91l9-12m-21 8l3-15M151 166l-17 5m23 6l-12 8" stroke="#24251f" strokeWidth="5"/>
<rect x="73" y="343" width="284" height="67" rx="5" fill="#f0eee2" stroke="#53544b" strokeWidth="3"/>
<text x="215" y="390" textAnchor="middle" fill="#24251f" fontSize="42" fontWeight="800" fontFamily="Hiragino Kaku Gothic ProN,sans-serif" letterSpacing="4">そば屋注意</text>
<circle cx="86" cy="355" r="3" fill="#777"/><circle cx="344" cy="398" r="3" fill="#777"/>
</svg></div></AbsoluteFill>};
