#!/usr/bin/env python3
"""Render the maintained application Markdown to a one-page A4 PDF."""
from pathlib import Path
import argparse
from html import escape
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_CENTER
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle


def build(source, output, font):
    pdfmetrics.registerFont(TTFont('ApplicationCJK', str(font), subfontIndex=6))
    styles={
        'title':ParagraphStyle('title',fontName='ApplicationCJK',fontSize=19,leading=25,alignment=TA_CENTER,textColor=colors.HexColor('#10384b'),spaceAfter=5),
        'sub':ParagraphStyle('sub',fontName='ApplicationCJK',fontSize=10,leading=14,alignment=TA_CENTER,spaceAfter=10),
        'h':ParagraphStyle('h',fontName='ApplicationCJK',fontSize=11,leading=15,textColor=colors.HexColor('#087e83'),spaceBefore=7,spaceAfter=3),
        'body':ParagraphStyle('body',fontName='ApplicationCJK',fontSize=9.1,leading=13.1,wordWrap='CJK',spaceAfter=3),
        'table':ParagraphStyle('table',fontName='ApplicationCJK',fontSize=8.8,leading=12,wordWrap='CJK'),
    }
    story=[]; lines=source.read_text(encoding='utf-8').splitlines();i=0
    while i<len(lines):
        line=lines[i];i+=1
        if not line:continue
        if line.startswith('|'):
            rows=[]
            while True:
                if not line.startswith('| ---'):
                    rows.append([Paragraph(escape(v.strip()),styles['table']) for v in line.strip('|').split('|')])
                if i>=len(lines) or not lines[i].startswith('|'):break
                line=lines[i];i+=1
            table=Table(rows,colWidths=[64,467],hAlign='LEFT')
            table.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),colors.HexColor('#eaf2f4')),('GRID',(0,0),(-1,-1),.4,colors.HexColor('#cfdee2')),('VALIGN',(0,0),(-1,-1),'TOP'),('TOPPADDING',(0,0),(-1,-1),4),('BOTTOMPADDING',(0,0),(-1,-1),4)]))
            story.append(table);continue
        kind='title' if line.startswith('# ') else 'h' if line.startswith('## ') else 'sub' if i==3 else 'body'
        text=line.removeprefix('## ').removeprefix('# ').removeprefix('- ')
        story.append(Paragraph(escape(text),styles[kind]))
    output.parent.mkdir(parents=True,exist_ok=True)
    SimpleDocTemplate(str(output),pagesize=A4,leftMargin=32,rightMargin=32,topMargin=25,bottomMargin=25,
                      title='MedSeal-MBT 项目申报书',author='韩桢').build(story)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--source',type=Path,default=Path('PROJECT_APPLICATION.md'));p.add_argument('--output',type=Path,required=True);p.add_argument('--font',type=Path,default=Path('/System/Library/Fonts/Supplemental/Songti.ttc'))
    args=p.parse_args();build(args.source,args.output,args.font)
