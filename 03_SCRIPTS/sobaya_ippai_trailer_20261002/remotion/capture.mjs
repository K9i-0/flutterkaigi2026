// Usage: node capture.mjs <VM websocket URI> <simulator ID> <perfect|spill>
// Requires a debug app exposing madogiwa.pourAction; records real simulation.
import {spawn} from 'node:child_process';
import fs from 'node:fs';
const [uri,device,take='perfect']=process.argv.slice(2);
if(!uri||!device||!['perfect','spill'].includes(take))throw Error('VM URI, simulator ID and perfect|spill required');
const ws=new WebSocket(uri);await new Promise((ok,no)=>{ws.onopen=ok;ws.onerror=no;});
let id=0;const pending=new Map();ws.onmessage=e=>{const r=JSON.parse(e.data);if(r.id){pending.get(r.id)?.(r);pending.delete(r.id);}};
const call=(method,params={})=>new Promise((ok,no)=>{const k=String(++id);const timeout=setTimeout(()=>no(Error(`Timeout ${method}`)),30000);pending.set(k,r=>{clearTimeout(timeout);r.error?no(Error(JSON.stringify(r.error))):ok(r.result);});ws.send(JSON.stringify({jsonrpc:'2.0',id:k,method,params}));});
const vm=await call('getVM');const isolateId=vm.isolates.find(x=>x.name==='main').id;
fs.mkdirSync('../capture',{recursive:true});const output=`../capture/${take==='spill'?'spill2':'perfect'}.mp4`;
const recorder=spawn('xcrun',['simctl','io',device,'recordVideo','--codec=h264','--force',output],{stdio:'inherit'});
const wait=ms=>new Promise(r=>setTimeout(r,ms));
try{await wait(3500);await call('ext.flutter.madogiwa.pourAction',{isolateId,action:'capture',take});let state;
for(let i=0;i<60;i++){await wait(1000);state=await call('ext.flutter.madogiwa.inspectPour',{isolateId});if(state.phase==='result')break;}
fs.writeFileSync(`../capture/${take}-state.json`,JSON.stringify(state,null,2));await wait(3000);
}finally{recorder.kill('SIGINT');await new Promise(r=>recorder.on('exit',r));ws.close();}
