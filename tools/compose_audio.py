#!/usr/bin/env python3
"""Original, reproducible arcade synth score and effects. No sampled recordings.

Authoring dependencies: numpy, scipy, ffmpeg. Not needed to play or build.
"""
from pathlib import Path
import subprocess
import tempfile
import wave
import numpy as np
from scipy.signal import butter, sosfilt

ROOT = Path(__file__).resolve().parents[1]
RATE = 44100
RNG = np.random.default_rng(340)

def timeline(seconds): return np.arange(round(seconds*RATE))/RATE
def hz(note): return 440*2**((note-69)/12)
def fade(x, attack=0.005, release=0.04):
    n=len(x); a=min(int(attack*RATE),n); r=min(int(release*RATE),n)
    env=np.ones(n);env[:a]*=np.linspace(0,1,a);env[-r:]*=np.linspace(1,0,r)
    return x*env
def noise(t, low=1200, high=None):
    x=RNG.normal(0,1,len(t))
    if high:
        return sosfilt(butter(2,[low,high],btype='bandpass',fs=RATE,output='sos'),x)
    return sosfilt(butter(2,low,btype='highpass',fs=RATE,output='sos'),x)
def synth(note, seconds, kind='pluck'):
    t=timeline(seconds);f=hz(note)
    if kind=='bass':
        x=np.sin(2*np.pi*f*t)*0.7
        for harmonic in range(2,9): x+=np.sin(2*np.pi*f*harmonic*t)*0.24/harmonic
        return fade(np.tanh(x*2)*np.exp(-t*2.1),0.003,0.05)*0.8
    if kind=='chord':
        x=sum(np.sin(2*np.pi*f*r*t)/r for r in range(1,8))
        return fade(np.tanh(x*1.8)*np.exp(-t*1.1),0.015,0.18)*0.42
    mod=np.sin(2*np.pi*f*2*t)*np.exp(-t*7)*1.8
    x=np.sin(2*np.pi*f*t+mod)+0.24*np.sin(2*np.pi*f*1.003*t)
    return fade(x*np.exp(-t*(4.0 if kind=='pluck' else 1.7)),0.008,0.09)*0.66
def kick():
    t=timeline(0.42);phase=2*np.pi*(47*t+85*(1-np.exp(-t*42))/42)
    x=np.sin(phase)*np.exp(-t*11)+noise(t,2500)*np.exp(-t*100)*0.16
    return fade(np.tanh(x*1.5),0.001,0.05)
def snare():
    t=timeline(0.27)
    x=noise(t,1200,13000)*np.exp(-t*17)*0.72
    x+=(np.sin(2*np.pi*182*t)+0.35*np.sin(2*np.pi*333*t))*np.exp(-t*30)*0.45
    return fade(x,0.001,0.03)
def hat(open_hat=False):
    t=timeline(0.27 if open_hat else 0.075)
    x=noise(t,7000)*np.exp(-t*(17 if open_hat else 60))
    return fade(x,0.001,0.015)*0.27

def write_wav(path, arr, peak=0.84):
    arr=np.asarray(arr);arr=arr/ max(np.max(np.abs(arr)),0.001)*peak
    path.parent.mkdir(parents=True,exist_ok=True)
    with wave.open(str(path),'wb') as out:
        out.setnchannels(1 if arr.ndim==1 else arr.shape[1]);out.setsampwidth(2);out.setframerate(RATE)
        out.writeframes((arr*32767).astype('<i2').tobytes())

def compose(name,bpm,tonic,variant):
    beat=60/bpm;bars=32;n=round(bars*4*beat*RATE);song=np.zeros((n,2),np.float32)
    def put(x,when,volume=1.0,pan=0.0,echo=False):
        start=round(when*RATE)%n
        gain=np.array([np.sqrt((1-pan)/2),np.sqrt((1+pan)/2)])*volume
        for delay,g in ([(0,1),(beat*0.75,0.22),(beat*1.5,0.10)] if echo else [(0,1)]):
            idx=(np.arange(len(x))+start+round(delay*RATE))%n
            song[idx]+=x[:,None]*gain*g
    k,s,h,o=kick(),snare(),hat(),hat(True)
    progression=([0,-3,-5,-2] if variant%2==0 else [0,3,-2,-5])
    motifs=[[12,15,19,22,19,15,12,10],[12,19,22,24,22,19,15,10],[12,12,15,17,19,17,15,10],[12,19,15,22,24,22,19,15]]
    for bar in range(bars):
        root=tonic+progression[(bar//2)%4];base=bar*4*beat
        bridge=16<=bar<20;intro=bar<4
        for step in range(16):
            t=base+step*beat/4
            if step in ([0,8] if bridge else [0,6,8,11]):put(k,t,0.63)
            if step in [4,12]:put(s,t,0.40 if intro else 0.52)
            if step%2==0 or not intro:put(o if step in [6,14] else h,t,0.35 if step%2 else 0.65,(-1)**step*0.24)
            if not bridge and bar%8==7 and step>=12:put(s,t,0.14+(step-12)*0.025,0.10)
            if step%2==0:
                note=root+(12 if step in [6,14] else 0)
                put(synth(note,beat*0.45,'bass'),t,0.43)
            if not intro and step%2==0:
                arp=root+24+[0,7,12,15,7,12,19,15][step//2]
                put(synth(arp,beat*0.4),t,0.065 if bridge else 0.12,0.55 if step%4 else -0.55,True)
        for step in ([0] if bridge else [0,6,10]):
            for interval in [12,19,24]:
                put(synth(root+interval,beat*1.3,'chord'),base+step*beat/4,0.08,-0.40 if interval==19 else 0.40)
        if bar>=4 and not bridge:
            motif=motifs[variant%len(motifs)]
            for j in range(8):
                note=root+12+motif[(j+2*(bar%2))%8]
                if bar>=24 and j>=6: note+=12
                put(synth(note,beat*0.66,'lead'),base+j*beat/2,0.19 if variant else 0.15,0.08,True)
    # Gentle sidechain pulse preserves the kick; a short circular room tail keeps the loop continuous.
    pulse=(np.arange(n)/RATE)%beat
    song*=((0.86+0.14*(1-np.exp(-pulse*15))))[:,None]
    song+=np.roll(song,round(RATE*0.113),axis=0)*0.045
    song=np.tanh(song*1.15)
    with tempfile.TemporaryDirectory() as tmp:
        wav=Path(tmp)/'mix.wav';write_wav(wav,song,0.84)
        out=ROOT/'audio/music'/name
        subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(wav),'-c:a','libvorbis','-q:a','5',str(out)],check=True)
    print(f'{name}: {bpm} BPM, {len(song)/RATE:.2f}s, original 32-bar stereo composition')

def effects():
    folder=ROOT/'audio/sfx'
    def effect(name, data):write_wav(folder/(name+'.wav'),data,0.78)
    def chord(notes,duration):return sum(synth(note,duration,'lead') for note in notes)
    effect('ui_click',synth(83,0.10))
    effect('ui_confirm',np.concatenate([synth(76,0.10),synth(83,0.16)]))
    effect('countdown',chord([72,84],0.16))
    effect('go',chord([76,83,88],0.48))
    effect('perfect_landing',np.concatenate([chord([76,88],0.09),chord([79,91],0.09),chord([83,95],0.30)]))
    effect('score',np.concatenate([synth(84,0.06),synth(91,0.14)]))
    effect('finish',np.concatenate([chord([n,n+7,n+12],d) for n,d in [(64,.19),(67,.19),(71,.19),(76,.85)]]))
    t=timeline(0.5);effect('jump_takeoff',fade(noise(t,1500)*np.sin(np.pi*t/.5)*.16+np.sin(2*np.pi*(180*t+850*t*t))*np.exp(-t*9)*.28))
    t=timeline(0.9);effect('boost',fade(noise(t,800)*np.exp(-t*3)*.28+np.sin(2*np.pi*(90*t+160*t*t))*np.exp(-t*4)*.30))
    for name,hard in [('landing_soft',False),('landing_hard',True),('crash_01',True),('crash_02',True)]:
        t=timeline(.55 if hard else .23)
        x=noise(t,180,7000)*np.exp(-t*(9 if hard else 20))*.5+np.sin(2*np.pi*(62*t+8*(1-np.exp(-t*30))/30))*np.exp(-t*16)*.8
        effect(name,fade(x,0.001,0.04))
    t=timeline(.55);effect('mud_splash',fade(noise(t,200,2600)*np.exp(-t*9)*(0.6+0.4*np.sin(2*np.pi*28*t))))
    for name,f in [('idle',38),('mid',77),('high',126)]:
        t=timeline(2.0)
        phase=2*np.pi*f*t+0.16*np.sin(2*np.pi*7*t)
        x=sum(np.sin(phase*k+0.15*k)/(k**.8) for k in range(1,18))
        x=np.tanh(x*1.6)*(.90+.10*np.sin(2*np.pi*17*t))
        write_wav(ROOT/'audio/engine'/('engine_'+name+'.wav'),x,.60)
    print('15 gameplay/menu effects and 3 periodic engine loops written')

if __name__=='__main__':
    for args in [('menu_theme.ogg',128,40,0),('race_loop_1.ogg',152,40,1),('race_loop_2.ogg',160,42,2),('race_loop_3.ogg',148,38,3)]:compose(*args)
    effects()
