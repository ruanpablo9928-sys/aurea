"""Render the canonical research text; no separate authored report copy."""
from pathlib import Path
import re
from xml.sax.saxutils import escape

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.pagesizes import A4
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'docs/research/alight-motion-hierarchy/report-source.md'
OUTPUT = ROOT / 'output/pdf/AUREA-hierarquia-de-edicao.pdf'
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
pdfmetrics.registerFont(TTFont('Report', 'C:/Windows/Fonts/segoeui.ttf'))
pdfmetrics.registerFont(TTFont('ReportBold', 'C:/Windows/Fonts/segoeuib.ttf'))
pdfmetrics.registerFontFamily('Report', normal='Report', bold='ReportBold')
NAVY = colors.HexColor('#18232E')
GREEN = colors.HexColor('#3D7048')
MUTED = colors.HexColor('#536271')
styles = {
    'body': ParagraphStyle('Body', fontName='Report', fontSize=10, leading=14,
        textColor=NAVY, spaceAfter=8, alignment=TA_LEFT),
    'title': ParagraphStyle('Title', fontName='ReportBold', fontSize=26, leading=31,
        textColor=NAVY, spaceAfter=14),
    'h2': ParagraphStyle('H2', fontName='ReportBold', fontSize=18, leading=23,
        textColor=NAVY, spaceAfter=14, keepWithNext=True),
    'h3': ParagraphStyle('H3', fontName='ReportBold', fontSize=11, leading=15,
        textColor=GREEN, spaceBefore=7, spaceAfter=5, keepWithNext=True),
    'cell': ParagraphStyle('Cell', fontName='Report', fontSize=9, leading=12,
        textColor=NAVY),
    'thead': ParagraphStyle('TableHeader', fontName='ReportBold', fontSize=9,
        leading=12, textColor=colors.white),
}

def inline(text):
    # Escape XML first, then convert only the source's simple bold/link syntax.
    text = escape(text)
    text = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', text)
    return re.sub(r'\[([^\]]+)\]\((https?://[^)]+)\)',
        lambda m: f'<a href="{m[2]}" color="#3D7048"><u>{m[1]}</u></a>', text)

def footer(canvas, doc):
    w, h = A4
    canvas.saveState()
    canvas.setFillColor(GREEN)
    canvas.rect(44, h - 31, 30, 3, fill=1, stroke=0)
    canvas.setFont('ReportBold', 8)
    canvas.drawString(82, h - 33, 'AUREA / PESQUISA E IMPLEMENTAÇÃO')
    canvas.setStrokeColor(colors.HexColor('#DCE3E8'))
    canvas.line(44, 42, w-44, 42)
    canvas.setFont('Report', 8)
    canvas.setFillColor(MUTED)
    canvas.drawString(44, 28, '05 SET 2026  •  Fluxos documentados + verificação local')
    canvas.drawRightString(w-44, 28, str(doc.page))
    canvas.restoreState()

lines = SOURCE.read_text(encoding='utf-8').splitlines()
assert 'VALIDATION_RESULT' not in '\n'.join(lines), 'Complete verification before rendering.'
story = []
section = 0
i = 0
while i < len(lines):
    line = lines[i].strip()
    if not line:
        i += 1
        continue
    if line.startswith('|'):
        rows = []
        while i < len(lines) and lines[i].strip().startswith('|'):
            cells = [v.strip() for v in lines[i].strip().strip('|').split('|')]
            if not all(re.fullmatch(r':?-+:?', c) for c in cells): rows.append(cells)
            i += 1
        widths = [113, 160, 234] if len(rows[0]) == 3 else [253.5, 253.5]
        table = Table([[Paragraph(inline(c), styles['thead' if r == 0 else 'cell'])
            for c in row] for r, row in enumerate(rows)], colWidths=widths, repeatRows=1)
        table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), NAVY),
            ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.HexColor('#EEF3F3'), colors.white]),
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 9),
            ('RIGHTPADDING', (0, 0), (-1, -1), 9),
            ('TOPPADDING', (0, 0), (-1, -1), 7),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 7),
        ]))
        story.extend([table, Spacer(1, 12)])
        continue
    if line.startswith('### '):
        story.append(Paragraph(inline(line[4:]), styles['h3']))
    elif line.startswith('## '):
        if section: story.append(PageBreak())
        section += 1
        story.append(Paragraph(inline(line[3:]), styles['h2']))
    elif line.startswith('# '):
        story.append(Paragraph(inline(line[2:]), styles['title']))
    else:
        story.append(Paragraph(inline(line), styles['body']))
    i += 1

doc = SimpleDocTemplate(str(OUTPUT), pagesize=A4, rightMargin=44, leftMargin=44,
    topMargin=54, bottomMargin=57, title='AUREA: uma hierarquia de edição mais clara',
    author='Codex - pesquisa e implementação para AUREA')
doc.build(story, onFirstPage=footer, onLaterPages=footer)
print(OUTPUT)
