from PIL import Image, ImageDraw, ImageFont
import json, statistics, os
B=36; W,H=750+2*B,1050+2*B   # 822 x 1122, MakePlayingCards' poker size with bleed
meta=json.load(open('raw/counts.json'))
NAMES={"swipe":"heist","swap":"trade","loot1":"bill-1","loot2":"bill-2","loot3":"bill-3","loot4":"bill-4","loot5":"bill-5","grand":"grand-heist","payup":"pay-up","lucky":"lucky-break","doublecross":"double-crossed"}
def edge_color(im):
    px=[]
    for y in range(200,850,10):
        for x in (1,2,3):
            p=im.getpixel((x,y))
            if p[3]>200: px.append(p[:3])
    return tuple(int(statistics.median([p[i] for p in px])) for i in range(3))
def bleed(im):
    out=Image.new('RGBA',(W,H),edge_color(im)+(255,))
    out.alpha_composite(im,(B,B))
    return out.convert('RGB')
n=0
for k in meta['order']:
    im=Image.open(f'raw/{k}.png').convert('RGBA')
    card=bleed(im)
    for i in range(meta['counts'][k]):
        n+=1
        card.save(f'mpc/front-{n:02d}-{NAMES.get(k,k)}.png',dpi=(300,300))
print(n)
