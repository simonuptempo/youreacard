from PIL import Image, ImageDraw, ImageFont
W,H=822,1122; B=36
NAVY=(11,26,51); IVORY=(250,243,226); YEL=(252,186,11); RED=(232,67,63); INK=(43,34,51)
ACT=(190,38,48); DEF=(102,64,200); AUTO=(168,112,10)
img=Image.new('RGBA',(W,H),NAVY+(255,)); d=ImageDraw.Draw(img)
d.rounded_rectangle([B+18,B+18,W-B-18,H-B-18],radius=34,fill=IVORY,outline=YEL,width=6)
T=ImageFont.truetype('/tmp/fonts/Corben-Bold.ttf',46)
H2=ImageFont.truetype('/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf',27)
NB=ImageFont.truetype('/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf',27)
R=ImageFont.truetype('/usr/share/fonts/truetype/google-fonts/Poppins-Regular.ttf',25)
y=B+52
d.text((W//2,y),"Card Guide",font=T,fill=RED,anchor="mt"); y+=66
X=B+50; RIGHT=W-B-50
def wrap(text,font,maxw):
    words=text.split(); lines=[]; line=""
    for w in words:
        t=(line+" "+w).strip()
        if d.textlength(t,font=font)>maxw and line: lines.append(line); line=w
        else: line=t
    lines.append(line); return lines
def section(title,col):
    global y
    d.text((X,y),title.upper(),font=H2,fill=col); y+=36
    d.line([(X,y),(RIGHT,y)],fill=col+(),width=3); y+=12
NAMEW=255
def entry(name,cost,text,col):
    global y
    d.text((X,y),name,font=NB,fill=col)
    if cost is not None:
        cx=X+d.textlength(name,font=NB)+24; cy=y+21
        d.ellipse([cx-17,cy-17,cx+17,cy+17],fill=col)
        d.text((cx,cy),str(cost),font=H2,fill=IVORY,anchor="mm")
    lines=wrap(text,R,RIGHT-X-NAMEW)
    if len(lines)==2:
        words=text.split(); best=None
        for i in range(1,len(words)):
            a,b=' '.join(words[:i]),' '.join(words[i:])
            wa,wb=d.textlength(a,font=R),d.textlength(b,font=R)
            if max(wa,wb)<=RIGHT-X-NAMEW and (best is None or max(wa,wb)<best[0]): best=(max(wa,wb),[a,b])
        if best: lines=best[1]
    yy=y+3
    for ln in lines: d.text((X+NAMEW,yy),ln,font=R,fill=INK); yy+=31
    y=max(y+38,yy+2)+5
section("Actions  (cost in bills)",ACT)
entry("Trade",1,"Swap a gem of yours for one of theirs",ACT)
entry("Shakedown",1,"Take a random card from their hand",ACT)
entry("Pay Up!",0,"They pay you 2 bills",ACT)
entry("Heist",2,"Take 1 gem from a set they haven't finished",ACT)
entry("Grand Heist",5,"Take a whole finished set",ACT)
entry("Lockpick",2,"Defuse a Defense, or steal a decoy",ACT)
entry("Lucky Break",0,"Draw 2 cards",ACT)
y+=8
section("Defense  (hide in your vault)",DEF)
entry("Shield",None,"Blocks the action",DEF)
entry("Mirror",None,"Bounces it back at them",DEF)
entry("Snare",None,"Blocks it, and you keep their card",DEF)
y+=8
section("Plays itself when drawn",AUTO)
entry("Windfall",None,"Take up to 10 bills from the discard pile",AUTO)
entry("Double Crossed",None,"Lose up to 10 bills from your bank",AUTO)
print("bottom",y,"limit",H-B-40)
img.convert('RGB').save('mpc/back-90-card-guide.png',dpi=(300,300))
