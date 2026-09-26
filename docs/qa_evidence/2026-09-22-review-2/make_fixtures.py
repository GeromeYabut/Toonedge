from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
p=Path('/private/tmp/toonedge-review-1138/fixtures'); p.mkdir(exist_ok=True)
f=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',56)
for i in range(1,9):
 im=Image.new('RGB',(800,1200),[(225,190,130),(135,195,195),(185,160,220),(155,205,155)][(i-1)%4]); d=ImageDraw.Draw(im)
 for y in (70,550,1050): d.text((45,y),f'QA PANEL {i} / {y}',fill=(25,25,35),font=f)
 im.save(p/f'{i}.png')
def page(name,title,body):
 q=p/name;q.parent.mkdir(parents=True,exist_ok=True);q.write_text(f'<!doctype html><meta name="viewport" content="width=device-width, initial-scale=1"><title>{title}</title><style>body{{margin:0;font:20px sans-serif}} img{{display:block;width:100%;height:auto}} a{{display:block;padding:14px}}</style>{body}')
page('index.html','QA ordinary page','<h1>ToonEdge review fixtures</h1><p>This is an ordinary text page.</p>'+''.join(f'<a href="/{x}">{x}</a>' for x in ['series/chapter-1/','medium/','article/','challenge/','broken/chapter-1/']))
for ch in (1,2,3):
 page(f'series/chapter-{ch}/index.html',f'QA Journey Chapter {ch}',f'<h1>QA Journey Chapter {ch}</h1><a href="/series/">QA Journey series</a>'+''.join(f'<img src="/{i}.png" alt="Panel {i}">' for i in range(1,9))+f'<a rel="prev" href="/series/chapter-{max(1,ch-1)}/">Previous Chapter</a><a rel="next" href="/series/chapter-{ch+1}/">Next Chapter</a>')
page('series/index.html','QA Journey','<h1>QA Journey</h1>'+''.join(f'<a href="/series/chapter-{i}/">Chapter {i}</a>' for i in (1,2)))
page('medium/index.html','QA three panels','<h1>Three panels</h1>'+''.join(f'<img src="/{i}.png">' for i in range(1,4)))
page('article/index.html','A garden photo essay','<article><h1>A garden photo essay</h1>'+''.join('<p>'+('This article explains garden planting and seasonal care. '*45)+f'</p><img src="/{i}.png" alt="Garden photograph {i}">' for i in range(1,9))+'</article>')
page('challenge/index.html','Just a moment...','<h1>Enable JavaScript and cookies to continue</h1>')
page('broken/chapter-1/index.html','QA Broken Chapter 1','<h1>QA Broken Chapter 1</h1>'+''.join(f'<img width="800" height="1200" style="height:600px" src="/missing-{i}.png" data-reader-page-image data-reader-index="{i}">' for i in range(1,9)))
