from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math
S=4
W,H=1600*S,700*S
NAVY=(6,21,43,255); CREAM=(250,239,212,255); YEL=(252,186,11,255); RED=(232,67,63,255); RED2=(196,40,48,255); PINK=(255,140,130,255)
img=Image.new('RGBA',(W,H),(0,0,0,0)); d=ImageDraw.Draw(img)
OUT=20*S

# ---- swoosh under the gem (like the logo's red orbit)
sw=Image.new('RGBA',(W,H),(0,0,0,0)); sd=ImageDraw.Draw(sw)
sd.arc([110*S,400*S,640*S,680*S],105,235,fill=RED,width=22*S)

# ---- gem mascot
cx,cy,gw,gh=385*S,370*S,430*S,480*S
def P(x,y): return (cx+x*gw, cy+y*gh)
tl,tr=P(-0.24,-0.42),P(0.24,-0.42)
gl,gr=P(-0.5,-0.12),P(0.5,-0.12)
bt=P(0,0.5)
outline=[tl,tr,gr,bt,gl]
# shadow offset
off=(16*S,14*S)
d.polygon([(x+off[0],y+off[1]) for x,y in outline],fill=RED)
d.polygon(outline,fill=RED2)
# crown facets
m1=P(-0.12,-0.12); m2=P(0.12,-0.12)
d.polygon([tl,tr,m2,m1],fill=(244,96,90,255))       # table
d.polygon([tl,m1,gl],fill=PINK)                        # left crown facet
d.polygon([tr,gr,m2],fill=(220,58,58,255))
# pavilion facets
d.polygon([gl,m1,bt],fill=(226,70,66,255))
d.polygon([m1,m2,bt],fill=(208,48,52,255))
d.polygon([m2,gr,bt],fill=(178,30,42,255))
# facet lines
for a,b in [(tl,m1),(tr,m2),(m1,m2)]:
    d.line([a,b],fill=NAVY,width=7*S)
# bandit mask across the girdle
band=[P(-0.60,-0.12),P(-0.35,-0.20),P(-0.12,-0.16),P(0,-0.10),P(0.12,-0.16),P(0.35,-0.20),P(0.58,-0.12)]
d.line(band,fill=NAVY,width=104*S,joint='curve')
for p in (band[0],band[-1]): d.ellipse([p[0]-52*S,p[1]-52*S,p[0]+52*S,p[1]+52*S],fill=NAVY)
# eyes: wink (left) + open (right) in cream
ex,ey=P(-0.24,-0.17); d.arc([ex-48*S,ey-30*S,ex+48*S,ey+40*S],200,340,fill=CREAM,width=13*S)
ex,ey=P(0.24,-0.18); d.ellipse([ex-40*S,ey-34*S,ex+40*S,ey+34*S],fill=CREAM); d.ellipse([ex-12*S,ey-22*S,ex+16*S,ey+16*S],fill=NAVY)
# smile
sx,sy=P(0.02,0.13); d.arc([sx-70*S,sy-60*S,sx+60*S,sy+30*S],25,150,fill=NAVY,width=10*S)
# sparkle on the gem
def star(x,y,r,col):
    pts=[]
    for i in range(8):
        a=i*math.pi/4-math.pi/2; rr=r if i%2==0 else r*0.28
        pts.append((x+rr*math.cos(a),y+rr*math.sin(a)))
    d.polygon(pts,fill=col)
# outer outline last
d.line(outline+[outline[0]],fill=NAVY,width=OUT,joint='curve')
for p in outline: d.ellipse([p[0]-OUT/2,p[1]-OUT/2,p[0]+OUT/2,p[1]+OUT/2],fill=NAVY)
sx,sy=P(-0.18,-0.32); star(sx,sy,30*S,CREAM)
# big yellow sparkle (navy outlined), like the original
bx,by=665*S,110*S
star(bx,by,80*S,NAVY); star(bx,by,62*S,YEL)

# ---- wordmark
FONT='/tmp/fonts/Corben-Bold.ttf'
def fit(s,maxw,start):
    sz=start
    while True:
        f=ImageFont.truetype(FONT,sz*S); b=f.getbbox(s)
        if b[2]-b[0]<=maxw*S: return f,b
        sz-=4
txt=Image.new('RGBA',(W,H),(0,0,0,0)); td=ImageDraw.Draw(txt)
def word(x,y,s,f,fill):
    so=(14*S,14*S)
    td.text((x+so[0],y+so[1]),s,font=f,fill=RED,stroke_width=22*S,stroke_fill=RED)
    td.text((x,y),s,font=f,fill=fill,stroke_width=22*S,stroke_fill=NAVY)
f2,b2=fit("Heist",820,320)
f1,b1=fit("Gem",420,210)
x0=700
word(x0*S-b2[0]+ (820*S-(b2[2]-b2[0]))//2, 300*S-b2[1],"Heist",f2,YEL)
word(x0*S-b1[0]+ (820*S-(b1[2]-b1[0]))//2, 95*S-b1[1],"Gem",f1,CREAM)
txt=txt.rotate(4,resample=Image.BICUBIC,center=(1110*S,350*S))
img.alpha_composite(txt)
img=img.resize((3200,1400),Image.LANCZOS)
bbox=img.getbbox(); print(bbox)
img.save('/tmp/store/gh-logo-big.png')
