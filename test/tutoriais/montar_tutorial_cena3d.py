"""
MONTA O TUTORIAL DA CENA 3D a partir dos quadros que o gravador tirou.

Le build/tutorial/cena3d/{quadros.json, cenas.json, quadros/*.png}, desenha
o dedo onde houve toque e a faixa de legenda embaixo de cada quadro, e
chama o ffmpeg (o embutido do imageio_ffmpeg) para fazer:

  - Downloads/Aurea-Tutoriais/tutorial-cena3d.mp4   (780 x 1908, para o grupo)
  - assets/tutoriais/cena3d.mp4                      (480 x 1174, para o app)
  - assets/tutoriais/cena3d.jpg                      (poster)
  - assets/tutoriais/cena3d.json                     (as cenas, com inicio e fim)
  - Downloads/Aurea-Tutoriais/tutorial-cena3d.srt

Rodar, na raiz do projeto:  python montar_tutorial_cena3d.py
"""
import json
import os
import subprocess
import textwrap

import imageio_ffmpeg
from PIL import Image, ImageDraw, ImageFont

RAIZ = r'C:\Users\SnyX\Documents\Projetos - Claude\Aurea'
ENTRADA = os.path.join(RAIZ, 'build', 'tutorial', 'cena3d')
MONTADO = os.path.join(ENTRADA, 'montado')
SAIDA = r'C:\Users\SnyX\Downloads\Aurea-Tutoriais'
ASSETS = os.path.join(RAIZ, 'assets', 'tutoriais')
FONTE = os.path.join(RAIZ, 'assets', 'templates', 'dnyx', 'AureaMotionSans.ttf')

ESCALA = 2            # o gravador tirou os PNG com pixelRatio 2
FAIXA = 220           # a altura da faixa de legenda, em px
FUNDO = (18, 21, 26)
LIMA = (184, 255, 61)
BRANCO = (233, 237, 242)
CINZA = (139, 148, 163)

os.makedirs(MONTADO, exist_ok=True)
os.makedirs(SAIDA, exist_ok=True)
os.makedirs(ASSETS, exist_ok=True)
for f in os.listdir(MONTADO):
    os.remove(os.path.join(MONTADO, f))

quadros = json.load(open(os.path.join(ENTRADA, 'quadros.json'), encoding='utf-8'))
cenas = json.load(open(os.path.join(ENTRADA, 'cenas.json'), encoding='utf-8'))
total = len(cenas)

# O fim de cada cena e o inicio da proxima; a ultima vai ate o fim.
duracao = sum(q['dur'] for q in quadros)
for i, c in enumerate(cenas):
    c['fim'] = cenas[i + 1]['inicio'] if i + 1 < len(cenas) else duracao
    c['inicio'] = round(c['inicio'], 3)
    c['fim'] = round(c['fim'], 3)

fonte_legenda = ImageFont.truetype(FONTE, 34)
fonte_passo = ImageFont.truetype(FONTE, 22)


def compor(caminho, dedo, cena):
    quadro = Image.open(caminho).convert('RGBA')
    w, h = quadro.size
    if dedo is not None:
        # O DEDO: um disco translucido com um anel lima, onde o toque foi.
        camada = Image.new('RGBA', quadro.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(camada)
        x, y = dedo[0] * ESCALA, dedo[1] * ESCALA
        r = 30
        d.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, 110))
        d.ellipse((x - r, y - r, x + r, y + r), outline=LIMA + (230,), width=4)
        quadro = Image.alpha_composite(quadro, camada)
    tela = Image.new('RGB', (w, h + FAIXA), FUNDO)
    tela.paste(quadro.convert('RGB'), (0, 0))
    d = ImageDraw.Draw(tela)
    # Um fio separando o app da faixa.
    d.line((0, h, w, h), fill=(40, 46, 56), width=2)
    passo = f'PASSO {cena["n"]} / {total}'
    d.text((32, h + 22), passo, font=fonte_passo, fill=LIMA)
    linhas = textwrap.wrap(cena['texto'], width=40)[:4]
    y = h + 60
    for linha in linhas:
        d.text((32, y), linha, font=fonte_legenda, fill=BRANCO)
        y += 40
    return tela


concat = []
ultimo = None
for i, q in enumerate(quadros):
    cena = cenas[q['cena'] - 1] if q['cena'] >= 1 else cenas[0]
    tela = compor(os.path.join(ENTRADA, 'quadros', q['arquivo']), q['dedo'], cena)
    nome = f'{i:04d}.png'
    tela.save(os.path.join(MONTADO, nome))
    concat.append(f"file '{nome}'\nduration {max(q['dur'], 0.04):.3f}")
    ultimo = nome
# O demuxer concat ignora a duracao do ultimo: repete-o.
concat.append(f"file '{ultimo}'")
open(os.path.join(MONTADO, 'concat.txt'), 'w', encoding='utf-8').write('\n'.join(concat) + '\n')

ff = imageio_ffmpeg.get_ffmpeg_exe()


def ffmpeg(*args):
    cmd = [ff, '-y', '-hide_banner', '-loglevel', 'error', *args]
    subprocess.run(cmd, check=True, cwd=MONTADO)


grande = os.path.join(SAIDA, 'tutorial-cena3d.mp4')
ffmpeg('-f', 'concat', '-safe', '0', '-i', 'concat.txt',
       '-vf', 'fps=24,format=yuv420p', '-c:v', 'libx264', '-preset', 'medium',
       '-crf', '21', '-movflags', '+faststart', grande)

pequeno = os.path.join(ASSETS, 'cena3d.mp4')
ffmpeg('-i', grande, '-vf', 'scale=480:-2,format=yuv420p', '-c:v', 'libx264',
       '-preset', 'medium', '-crf', '27', '-movflags', '+faststart', pequeno)

# O poster: o primeiro quadro do Estudio (a cena 4, o tour), reduzido.
poster_idx = next((i for i, q in enumerate(quadros) if q['cena'] == 4), 0)
Image.open(os.path.join(MONTADO, f'{poster_idx:04d}.png')).convert('RGB') \
    .resize((480, int(480 * (1688 + FAIXA) / 780))) \
    .save(os.path.join(ASSETS, 'cena3d.jpg'), quality=82)

json.dump(
    {
        'titulo': 'Cena 3D',
        'duracao': round(duracao, 3),
        'largura': 780,
        'altura': 1688 + FAIXA,
        'cenas': cenas,
    },
    open(os.path.join(ASSETS, 'cena3d.json'), 'w', encoding='utf-8'),
    ensure_ascii=False,
    indent=1,
)


def srt(t):
    ms = int(round(t * 1000))
    h, ms = divmod(ms, 3600000)
    m, ms = divmod(ms, 60000)
    s, ms = divmod(ms, 1000)
    return f'{h:02d}:{m:02d}:{s:02d},{ms:03d}'


with open(os.path.join(SAIDA, 'tutorial-cena3d.srt'), 'w', encoding='utf-8') as f:
    for c in cenas:
        f.write(f"{c['n']}\n{srt(c['inicio'])} --> {srt(c['fim'])}\n{c['texto']}\n\n")

print('quadros:', len(quadros), '| cenas:', total, '| duracao: %.1f s' % duracao)
for caminho in (grande, pequeno, os.path.join(ASSETS, 'cena3d.jpg')):
    print(f'{os.path.getsize(caminho) / 1e6:6.2f} MB  {caminho}')
