"""Package recordings of real Aurea widgets with captions outside the UI."""
import json
import subprocess
import textwrap
import wave
import math
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/tutorial-scene3d'
REC=OUT/'recording'
FF=Path(r'C:\Users\SnyX\Downloads\Motion 2.0\tools\ffmpeg\bin')
clips=json.loads((REC/'clips.json').read_text(encoding='utf-8-sig'))
# Keep gestures intact; extend each final hold when narration needs more time.
spoken=[];ranges=[]
for i,clip in enumerate(clips):
    key=(clip['chapter'],clip['caption'])
    if ranges and ranges[-1]['key']==key:ranges[-1]['indices'].append(i)
    else:ranges.append({'key':key,'indices':[i]})
for i,group in enumerate(ranges):
    with wave.open(str(OUT/'narration'/f'voice-{i:03}.wav'),'rb') as source:
        params=source.getparams();pcm=source.readframes(source.getnframes())
        audio_duration=source.getnframes()/params.framerate
    visual=sum(clips[k]['duration'] for k in group['indices'])
    duration=math.ceil(max(visual,audio_duration+.45)*30)/30
    clips[group['indices'][-1]]['duration']+=duration-visual
    spoken.append((pcm,params,duration))
with wave.open(str(OUT/'narration.wav'),'wb') as narration:
    base=spoken[0][1];narration.setparams(base)
    for pcm,params,duration in spoken:
        assert params[:3]==base[:3]
        bpf=params.sampwidth*params.nchannels
        lead=round(.15*params.framerate)
        total=round(duration*params.framerate)
        tail=max(0,total-lead-len(pcm)//bpf)
        narration.writeframes(b'\0'*(lead*bpf)+pcm+b'\0'*(tail*bpf))
def stamp(t):
    centis=round(t*100)
    return f'{centis//360000}:{centis//6000%60:02}:{centis//100%60:02}.{centis%100:02}'
def subtitle(t):
    return '\\N'.join(textwrap.wrap(t,width=49)).replace('{','').replace('}','')
header='''[Script Info]
ScriptType: v4.00+
PlayResX: 1080
PlayResY: 1920
WrapStyle: 2
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Caption,Arial,36,&H00F2EDE9,&H000000FF,&H001A1512,&H001A1512,-1,0,0,0,100,100,0,0,1,0,0,2,70,70,34,1
Style: Chapter,Arial,32,&H003DFFB8,&H000000FF,&H001A1512,&H001A1512,-1,0,0,0,100,100,1,0,1,0,0,8,70,70,24,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
'''
elapsed=0;groups=[];concat=[]
for clip in clips:
    duration=clip['duration'];a=elapsed;elapsed+=duration
    concat.extend([f"file '{clip['file']}'",f'duration {duration:.4f}'])
    key=(clip['chapter'],clip['caption'])
    if groups and groups[-1]['key']==key:groups[-1]['end']=elapsed
    else:groups.append({'key':key,'start':a,'end':elapsed})
concat.append(f"file '{clips[-1]['file']}'")
(REC/'frames.ffconcat').write_text('ffconcat version 1.0\n'+'\n'.join(concat)+'\n',encoding='utf-8')
events=[]
for group in groups:
    chapter,caption=group['key'];start,end=stamp(group['start']),stamp(group['end'])
    events.append(f'Dialogue: 0,{start},{end},Chapter,,0,0,0,,{chapter}')
    events.append(f'Dialogue: 0,{start},{end},Caption,,0,0,0,,{subtitle(caption)}')
(REC/'captions.ass').write_text(header+'\n'.join(events),encoding='utf-8-sig')
(OUT/'roteiro.json').write_text(json.dumps(groups,ensure_ascii=False,indent=2),encoding='utf-8')
command=[str(FF/'ffmpeg.exe'),'-hide_banner','-loglevel','warning','-y','-f','concat','-safe','0',
    '-i','frames.ffconcat','-i',str(OUT/'narration.wav'),'-vf',"fps=30,pad=1080:1920:110:88:color=0x12151A,ass=captions.ass,scale=in_range=full:out_range=tv:out_color_matrix=bt709",
    '-t',str(elapsed),'-c:a','aac','-b:a','128k','-af','loudnorm=I=-16:TP=-1.5:LRA=7',
    '-c:v','libx264','-preset','fast','-crf','19','-pix_fmt','yuv420p',
    '-movflags','+faststart','-color_primaries','bt709','-color_trc','bt709','-colorspace','bt709',str(OUT/'TUTORIAL-CENA-3D.mp4')]
subprocess.run(command,cwd=REC,check=True)
probe=subprocess.check_output([str(FF/'ffprobe.exe'),'-v','error','-count_frames','-select_streams','v:0',
    '-show_entries','stream=codec_name,width,height,r_frame_rate,nb_read_frames:format=duration,size','-of','json',str(OUT/'TUTORIAL-CENA-3D.mp4')])
data=json.loads(probe)
data.update({'source':'Actual Aurea widgets, captured in a Flutter test session; compatibility preview renderer',
    'touchIndicatorsAdded':True,'captionsOutsideInterface':True,'plannedDuration':elapsed,'screenCaptures':len(clips),
    'narration':'Portuguese, synthetic voice Microsoft Maria Desktop'})
(OUT/'video-verification.json').write_text(json.dumps(data,indent=2),encoding='utf-8')
print(json.dumps(data,indent=2))
