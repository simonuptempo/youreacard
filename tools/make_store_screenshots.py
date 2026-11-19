from PIL import Image, ImageDraw, ImageFilter, ImageFont
import random, math
K='/tmp/shots/keep/'
NUN='/mnt/user-data/outputs/YoureACard/fonts/Nunito.ttf'
RAW='/tmp/print/raw/'; ART='/mnt/user-data/outputs/YoureACard/art/'
CREAM=(250,239,212); GOLD=(252,186,11); NAVY_A=(14,30,58); NAVY_B=(8,16,34)
SHOTS=[('board2x','Steal gems. Build sets.','First to finish 4 gem sets wins', ('swipe','grand')),
       ('replay2x','Watch every sneaky move','Replay their turn, step by step', ('lockpick','mirror')),
       ('crew2x','Put yourself in the game','Your photo or character on any card', ('wild','swap')),
       ('explainer2x','Learn in a minute','A quick tutorial gets you playing', ('payup','shield'))]

def font(size,w=900):
    f=ImageFont.truetype(NUN,size)
    try: f.set_variation_by_axes([w])
    except Exception: pass
    return f

def bg(W,H):
    img=Image.new('RGB',(W,H)); d=ImageDraw.Draw(img)
    for y in range(H):
        t=y/H; d.line([(0,y),(W,y)],fill=tuple(int(NAVY_A[i]+(NAVY_B[i]-NAVY_A[i])*t) for i in range(3)))
    # faint diamond lattice, like the card back
    lat=Image.new('RGBA',(W,H),(0,0,0,0)); ld=ImageDraw.Draw(lat); step=W//7
    for k in range(-12,24):
        x=k*step
        ld.line([(x,0),(x+H,H)],fill=(255,255,255,10),width=3)
        ld.line([(x+H,0),(x,H)],fill=(255,255,255,10),width=3)
    img=img.convert('RGBA'); img.alpha_composite(lat)
    # soft gold glow behind the caption
    glow=Image.new('RGBA',(W,H),(0,0,0,0)); gd=ImageDraw.Draw(glow)
    gd.ellipse([W*0.1,-H*0.12,W*0.9,H*0.22],fill=(252,186,11,40))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(W//10)))
    return img

def rounded(im,r):
    m=Image.new('L',im.size,0); ImageDraw.Draw(m).rounded_rectangle([0,0,im.width-1,im.height-1],r,fill=255)
    out=im.convert('RGBA'); out.putalpha(m); return out

def framed_shot(canvas,shot,x,y,w):
    im=Image.open(K+shot+'.png').convert('RGB')
    h=round(im.height*w/im.width); im=im.resize((w,h),Image.LANCZOS)
    r=w//18; b=max(5,w//170)
    sh=Image.new('RGBA',canvas.size,(0,0,0,0)); ImageDraw.Draw(sh).rounded_rectangle([x-b,y-b+w//40,x+w+b,y+h+b+w//40],r+b,fill=(0,0,0,150))
    canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(w//30)))
    ImageDraw.Draw(canvas).rounded_rectangle([x-b,y-b,x+w+b,y+h+b],r+b,fill=GOLD)
    canvas.alpha_composite(rounded(im,r),(x,y))
    return h

def caption(canvas,head,sub,cy,size):
    d=ImageDraw.Draw(canvas); W=canvas.width
    fh=font(size,900); fs=font(int(size*0.5),700)
    d.text((W/2,cy),head,font=fh,fill=CREAM,anchor='mm')
    d.text((W/2,cy+size*0.95),sub,font=fs,fill=GOLD,anchor='mm')

def side_card(canvas,kind,cx,cy,h,rot):
    im=Image.open(RAW+kind+'.png').convert('RGBA'); w=round(im.width*h/im.height); im=im.resize((w,h),Image.LANCZOS)
    r=im.rotate(rot,resample=Image.BICUBIC,expand=True)
    sh=Image.new('RGBA',r.size,(0,0,0,0)); a=r.split()[3].point(lambda v:int(v*0.5)); blk=Image.new('RGBA',r.size,(0,0,0,255)); blk.putalpha(a)
    pad=40; big=Image.new('RGBA',(r.width+2*pad,r.height+2*pad),(0,0,0,0)); big.alpha_composite(blk,(pad+10,pad+20)); big=big.filter(ImageFilter.GaussianBlur(18)); big.alpha_composite(r,(pad,pad))
    canvas.alpha_composite(big,(int(cx-big.width/2),int(cy-big.height/2)))

def iphone(i,shot,head,sub,cards):
    W,H=1206,2622; c=bg(W,H)
    caption(c,head,sub,270,92)
    w=1080; framed_shot(c,shot,(W-w)//2,530,w)
    c.convert('RGB').save('shots/iphone-%d-%s.png'%(i,shot.replace('2x','')))

def ipad(i,shot,head,sub,cards):
    W,H=2064,2752; c=bg(W,H)
    side_card(c,cards[0],330,1650,760,9)
    side_card(c,cards[1],W-330,1650,760,-9)
    caption(c,head,sub,280,118)
    w=1180; framed_shot(c,shot,(W-w)//2,520,w)
    c.convert('RGB').save('shots/ipad-%d-%s.png'%(i,shot.replace('2x','')))

for i,(shot,head,sub,cards) in enumerate(SHOTS,1):
    iphone(i,shot,head,sub,cards); ipad(i,shot,head,sub,cards)
print('ok')
