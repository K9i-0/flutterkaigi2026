from pathlib import Path
import torch,subprocess,numpy as np
from demucs.pretrained import get_model
from demucs.apply import apply_model
from scipy.io import wavfile
p=Path(__file__).resolve().parents[2];out=p/'remotion/out/rescore';out.mkdir(exist_ok=True)
torch.set_num_threads(4);model=get_model('htdemucs');model.eval()
b=subprocess.check_output(['ffmpeg','-v','error','-i',str(p/'final_remotion_cm.mp4'),'-f','f32le','-ar','44100','-ac','2','-']);x=torch.from_numpy(np.frombuffer(b,'<f4').copy().reshape(-1,2).T);ref=x.mean(0);mu=ref.mean();std=ref.std()
with torch.inference_mode():stems=apply_model(model,((x-mu)/std)[None],device='cpu',shifts=0,split=True,overlap=.25,progress=True)[0]*std+mu
for name,s in zip(model.sources,stems):wavfile.write(out/f'{name}.wav',44100,s.T.numpy());print(name,flush=True)
