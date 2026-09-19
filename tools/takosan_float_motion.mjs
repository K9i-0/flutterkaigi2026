import * as T from 'three';
/** Speed-driven additive motion for the canonical 27-bone Takosan rig. No mesh edits. */
export class TakosanFloatMotion {
  constructor(model, pivot) {
    this.pivot=pivot; this.speed=0; this.phase=0; this.time=0; this.swim=0;
    this.bones=[]; this.weights={sway:0,wave:0,pulse:0,alternate:0,curl:1};
    model.traverse(b=>{if(b.isBone)this.bones.push({bone:b,rest:b.quaternion.clone(),name:b.name});});
    this.tentacleCount=this.bones.filter(b=>/^Tentacle[1-6][._]?(Base|Mid|Tip)$/.test(b.name)).length;
    if(this.tentacleCount!==18)throw new Error(`触手の関節が不足しています: ${this.tentacleCount}/18`);
    this.euler=new T.Euler(); this.q=new T.Quaternion();
  }
  update(dt,targetSpeed,mode='float',pattern='curl',strength=1,bodyMotion=true) {
    const blend=1-Math.exp(-dt*3); this.speed+=(targetSpeed-this.speed)*blend;
    this.swim+=((mode==='swim'?1:0)-this.swim)*blend;
    for(const key of Object.keys(this.weights))this.weights[key]+=((key===pattern?1:0)-this.weights[key])*blend;
    this.time+=dt; this.phase+=dt*(1.8+this.speed*.85);
    const s=this.speed/3,p=this.phase,w=this.swim;
    // Model faces +Z; positive X rotation tilts the head toward +Z.
    this.pivot.rotation.x=s*(.40+w*.22)+w*s*.035*Math.sin(p);
    this.pivot.rotation.z=.022*Math.sin(this.time*1.1)*(1-s*.5);
    this.pivot.position.y=.48+.045*Math.sin(this.time*1.7)+w*s*.028*Math.sin(p);
    if(!bodyMotion){this.pivot.rotation.set(0,0,0);this.pivot.position.y=.48;}
    for(const {bone,rest,name} of this.bones){
      bone.quaternion.copy(rest);
      const m=/^Tentacle([1-6])[._]?(Base|Mid|Tip)$/.exec(name);
      let x=0,y=0,z=0;
      if(m){
        const i=+m[1]-1,j=['Base','Mid','Tip'].indexOf(m[2]);
        const delay=j*.8,travel=p-i*1.05-delay;
        const poses={
          sway:[(.13+j*.13)*Math.sin(p*.75-i*1.1-delay),.02*Math.sin(p+i),(.08+j*.06)*Math.cos(p*.62+i)],
          wave:[(.16+j*.16)*Math.sin(travel),.035*Math.sin(travel+.5),(.10+j*.075)*Math.cos(travel)],
          pulse:[(.17+j*.17)*Math.sin(p-delay*.5),0,(.06+j*.05)*Math.cos(p-delay*.5)],
          alternate:[(.16+j*.16)*Math.sin(p+(i%2)*Math.PI-delay*.6),0,(.08+j*.06)*Math.cos(p+(i%2)*Math.PI-delay*.6)],
          curl:[(.035+j*.19)*Math.sin(p*.8-i*.7-delay),(.02+j*.02)*Math.sin(p*.8-i*.7),(.025+j*.11)*Math.cos(p*.8-i*.7-delay)]
        };
        for(const [key,weight] of Object.entries(this.weights)){
          x+=poses[key][0]*weight*strength;y+=poses[key][1]*weight*strength;z+=poses[key][2]*weight*strength;
        }
        x+=s*.025*j*strength;
      }else if(!bodyMotion){continue;}else if(/UpperArm/.test(name)){
        x=.035*Math.sin(p-1)+s*.10; z=(name.endsWith('L')?1:-1)*(.04+.025*Math.sin(p));
      }else if(/Forearm/.test(name)){x=.045*Math.sin(p-.8);}
      else if(name==='Head'){x=-s*.12;}
      this.euler.set(x,y,z);this.q.setFromEuler(this.euler);bone.quaternion.multiply(this.q);
    }
    return {speed:this.speed,lean:this.pivot.rotation.x*180/Math.PI,tentacleCount:this.tentacleCount};
  }
}
