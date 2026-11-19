from PIL import Image, ImageDraw, ImageFilter, ImageFont
import random, math
RAW='/tmp/print/raw/'
ART='/mnt/user-data/outputs/YoureACard/art/'
FONT='/tmp/fonts/Corben-Bold.ttf'
CREAM=(250,239,212); NAVY=(6,21,43); RED=(232,67,63); YEL=(252,186,11)
logo=Image.open('gh-logo-big.png').convert('RGBA'); logo=logo.crop(logo.getbbox())
yac=Image.open(ART+'logo.png').convert('RGBA'); yac=yac.crop(yac.getbbox())

def felt(W,H,seed=3):
    # deep green table: radial glow + fine noise + vignette
    img=Image.new('RGB',(W,H))
    small=Image.new('RGB',(W//8,H//8)); px=small.load()
    cx,cy=small.width/2,small.height*0.45
    rmax=math.hypot(small.width/2,small.height/2)
    for y in range(small.height):
        for x in range(small.width):
            t=min(1.0,math.hypot(x-cx,(y-cy)*1.25)/rmax)
            a=(34,96,64); b=(7,32,24)
            px[x,y]=tuple(int(a[i]+(b[i]-a[i])*(t**1.3)) for i in range(3))
    img=small.resize((W,H),Image.BICUBIC)
    rnd=random.Random(seed)
    noise=Image.effect_noise((W//2,H//2),22).resize((W,H)).convert('L')
    img=Image.blend(img,Image.merge('RGB',(noise,noise,noise)),0.045)
    return img.convert('RGBA')

def card(kind,h):
    im=Image.open(RAW+kind+'.png').convert('RGBA')
    w=round(im.width*h/im.height)
    return im.resize((w,h),Image.LANCZOS)

def shadowed(im,rot,blur=None):
    blur=blur or max(8,im.height//40)
    r=im.rotate(rot,resample=Image.BICUBIC,expand=True)
    pad=blur*4
    sh=Image.new('RGBA',(r.width+pad*2,r.height+pad*2),(0,0,0,0))
    a=r.split()[3].point(lambda v:int(v*0.55))
    blk=Image.new('RGBA',r.size,(0,0,0,255)); blk.putalpha(a)
    sh.alpha_composite(blk,(pad+blur//2,pad+blur))
    sh=sh.filter(ImageFilter.GaussianBlur(blur))
    sh.alpha_composite(r,(pad,pad))
    return sh

def place(canvas,im,cx,cy):
    canvas.alpha_composite(im,(int(cx-im.width/2),int(cy-im.height/2)))

def fan(canvas,kinds,cx,cy,h,spread,step,lift):
    n=len(kinds)
    for i,k in enumerate(kinds):
        t=i-(n-1)/2
        rot=-t*spread
        x=cx+t*step
        y=cy+abs(t)*lift
        place(canvas,shadowed(card(k,h),rot),x,y)

def gem(name,size,rot=0):
    im=Image.open(ART+'treasure-%s.png'%name).convert('RGBA')
    im=im.resize((size,size),Image.LANCZOS)
    return shadowed(im,rot,blur=max(6,size//25))

NUNITO='/mnt/user-data/outputs/YoureACard/fonts/Nunito.ttf'
def text(canvas,s,cx,cy,size,fill=CREAM):
    f=ImageFont.truetype(NUNITO,size)
    try: f.set_variation_by_axes([900])
    except Exception: pass
    sh=Image.new('RGBA',canvas.size,(0,0,0,0)); d=ImageDraw.Draw(sh)
    d.text((cx,cy+size//12),s,font=f,fill=(0,0,0,170),anchor='mm')
    sh=sh.filter(ImageFilter.GaussianBlur(size//10))
    canvas.alpha_composite(sh)
    ImageDraw.Draw(canvas).text((cx,cy),s,font=f,fill=fill,anchor='mm')

def logo_at(canvas,cx,cy,w,lg=logo):
    l=lg.resize((w,round(lg.height*w/lg.width)),Image.LANCZOS)
    glow=Image.new('RGBA',l.size,(0,0,0,0)); g=Image.new('RGBA',l.size,(0,0,0,255)); g.putalpha(l.split()[3].point(lambda v:int(v*0.45)))
    pad=w//10
    big=Image.new('RGBA',(l.width+2*pad,l.height+2*pad),(0,0,0,0)); big.alpha_composite(g,(pad,pad+w//60))
    big=big.filter(ImageFilter.GaussianBlur(w//60)); big.alpha_composite(l,(pad,pad))
    place(canvas,big,cx,cy)
    return l.height

LEFT=['swipe','swap','grand']
RIGHT=['lockpick','payup','wild']
TAG="Steal gems. Outsmart your friends."

def scene_wide(W,H,safe):  # safe = (x0,y0,x1,y1) where key content must sit
    c=felt(W,H)
    x0,y0,x1,y1=safe; sw=x1-x0; sh=y1-y0
    cx=(x0+x1)/2
    ch=int(sh*0.52)                       # card height
    # gems scattered behind the cards
    rnd=random.Random(7)
    for name,fx,fy,s in [('ruby',0.03,0.18,0.10),('emerald',0.30,0.86,0.08),('sapphire',0.70,0.88,0.08),('diamond',0.97,0.16,0.10),('amethyst',0.24,0.10,0.07),('topaz',0.77,0.08,0.07)]:
        place(c,gem(name,int(sh*s*1.6),rnd.uniform(-20,20)),x0+sw*fx,y0+sh*fy)
    fan(c,LEFT,x0+sw*0.135,y0+sh*0.50,ch,10,ch*0.30,ch*0.04)
    fan(c,RIGHT,x0+sw*0.865,y0+sh*0.50,ch,10,ch*0.30,ch*0.04)
    lh=logo_at(c,cx,y0+sh*0.40,int(sw*0.36))
    text(c,TAG,cx,y0+sh*0.40+lh*0.5+sh*0.13,int(sh*0.068))
    return c.convert('RGB')

def scene_stack(W,H,safe,seed=5):
    # logo on top, a fan of cards, the tagline underneath, all inside `safe`
    c=felt(W,H,seed)
    x0,y0,x1,y1=safe; sw=x1-x0; sh=y1-y0; cx=(x0+x1)/2
    lw=int(min(sw*0.50, sh*0.42*logo.width/logo.height))
    lh=logo_at(c,cx,y0+sh*0.185,lw)
    ch=int(sh*0.42)
    rnd=random.Random(3)
    for name,fx,fy,s_ in [('ruby',0.06,0.10,0.09),('diamond',0.94,0.10,0.09),('emerald',0.05,0.62,0.07),('sapphire',0.95,0.62,0.07)]:
        place(c,gem(name,int(sh*s_*1.4),rnd.uniform(-20,20)),x0+sw*fx,y0+sh*fy)
    fan(c,['swipe','swap','wild','grand','lockpick'],cx,y0+sh*0.61,ch,8,ch*0.40,ch*0.05)
    text(c,TAG,cx,y0+sh*0.935,int(sh*0.06))
    return c.convert('RGB')

def scene_search(W,H):
    return scene_stack(W,H,(0,0,W,H))

# 1) Header only, 21:9
scene_wide(3840,1646,(110,90,3730,1500)).save('header-3840x1646.png')
# 2) Universal 16:9 (header crop is the middle 21:9 band, search crop the middle 3:2)
W,H=5244,2950
hh=round(W*9/21); sw3=round(H*3/2)
safe=((W-sw3)//2+60,(H-hh)//2+60,(W+sw3)//2-60,(H+hh)//2-60)
scene_stack(W,H,safe).save('universal-5244x2950.png')
# 3) Search results 3:2
s=scene_search(3840,2560); s.save('search-3840x2560.png')
s.resize((1920,1280),Image.LANCZOS).save('search-1920x1280.png')
print('done')
