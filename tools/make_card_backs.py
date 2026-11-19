from PIL import Image, ImageDraw, ImageFilter, ImageChops
import math
W,H=825,1125   # 2.75" x 3.75" at 300 dpi = poker card + 1/8" bleed all round
NAVY=(11,26,51); NAVY2=(22,44,80); CREAM=(250,239,212); YEL=(252,186,11); RED=(232,67,63)
yac=Image.open('/mnt/user-data/outputs/YoureACard/art/logo.png').convert('RGBA')
gh=Image.open('gem-heist-logo.png').convert('RGBA')
def trim(im): return im.crop(im.getbbox())
yac,gh=trim(yac),trim(gh)

def sticker(im,r,col):
    a=im.split()[3].point(lambda v:255 if v>40 else 0)
    big=Image.new('L',(im.width+4*r,im.height+4*r),0); big.paste(a,(2*r,2*r))
    for _ in range(r//4): big=big.filter(ImageFilter.MaxFilter(9))
    big=big.filter(ImageFilter.GaussianBlur(1.2))
    out=Image.new('RGBA',big.size,col+(0,)); out.putalpha(big)
    out.alpha_composite(im,(2*r,2*r)); return out

def scaled(im,w):
    h=round(im.height*w/im.width); return im.resize((w,h),Image.LANCZOS)

def base(bg,line,frame):
    S=2; img=Image.new('RGB',(W*S,H*S),bg); d=ImageDraw.Draw(img)
    step=110*S
    for k in range(-30,30):
        x=k*step
        d.line([(x,0),(x+H*S,H*S)],fill=line,width=3*S)
        d.line([(x+H*S,0),(x,H*S)],fill=line,width=3*S)
    # small diamonds at lattice crossings
    for i in range(-2,20):
        for j in range(-2,24):
            cx=i*step+(step//2 if j%2 else 0); cy=j*step//2
            r=10*S; d.polygon([(cx,cy-r),(cx+r,cy),(cx,cy+r),(cx-r,cy)],fill=line)
    # rounded frame inside the safe area (trim is 37.5px in, safe ~75px in)
    m=70*S; d.rounded_rectangle([m,m,W*S-m,H*S-m],radius=40*S,outline=frame,width=9*S)
    m2=88*S; d.rounded_rectangle([m2,m2,W*S-m2,H*S-m2],radius=28*S,outline=frame,width=3*S)
    return img.resize((W,H),Image.LANCZOS).convert('RGBA')

def star(d,x,y,r,col):
    pts=[]
    for i in range(8):
        a=i*math.pi/4-math.pi/2; rr=r if i%2==0 else r*0.3
        pts.append((x+rr*math.cos(a),y+rr*math.sin(a)))
    d.polygon(pts,fill=col)

# Option A: mirrored, reads right either way up (classic playing-card back)
a=base(NAVY,NAVY2,YEL)
g=sticker(scaled(gh,560),10,CREAM); y=sticker(scaled(yac,560),10,CREAM)
a.alpha_composite(g,((W-g.width)//2,H//2-g.height-28))
y180=y.rotate(180)
a.alpha_composite(y180,((W-y180.width)//2,H//2+28))
d=ImageDraw.Draw(a)
d.line([(170,H//2),(W-170,H//2)],fill=YEL,width=4)
star(d,W//2,H//2,22,YEL)
a.convert('RGB').save('back-A-mirrored.png',dpi=(300,300))

# Option B: Gem Heist centered big, You're a Card as the maker's mark at the bottom
b=base(NAVY,NAVY2,YEL)
g=sticker(scaled(gh,600),11,CREAM); y=sticker(scaled(yac,330),7,CREAM)
b.alpha_composite(g,((W-g.width)//2,(H-g.height)//2-70))
b.alpha_composite(y,((W-y.width)//2,H-y.height-120))
d=ImageDraw.Draw(b)
for x,yy,r in [(180,190,20),(W-180,190,20),(W//2,175,26)]: star(d,x,yy,r,YEL)
b.convert('RGB').save('back-B-gem-heist.png',dpi=(300,300))

# Option C: same as B on the yellow of the app icon
c=base(YEL,(240,168,0),NAVY)
g=scaled(gh,600); y=scaled(yac,330)
c.alpha_composite(sticker(g,11,CREAM),((W-g.width-44)//2,(H-g.height)//2-70))
y=sticker(y,7,CREAM); c.alpha_composite(y,((W-y.width)//2,H-y.height-120))
c.convert('RGB').save('back-C-yellow.png',dpi=(300,300))

# side-by-side preview
prev=Image.new('RGB',(W*3+80,H+40),(40,44,60))
for i,f in enumerate(['back-A-mirrored.png','back-B-gem-heist.png','back-C-yellow.png']):
    prev.paste(Image.open(f),(20+i*(W+20),20))
prev.resize((prev.width//2,prev.height//2),Image.LANCZOS).save('preview.png')
