from PIL import Image, ImageDraw, ImageFont
W,H=822,1122; B=36
NAVY=(11,26,51); IVORY=(250,243,226); YEL=(252,186,11); RED=(232,67,63); INK=(43,34,51)
img=Image.new('RGBA',(W,H),NAVY+(255,)); d=ImageDraw.Draw(img)
d.rounded_rectangle([B+18,B+18,W-B-18,H-B-18],radius=34,fill=IVORY,outline=YEL,width=6)
logo=Image.open('/tmp/backs/gem-heist-logo.png').convert('RGBA'); logo=logo.crop(logo.getbbox())
lw=380; logo=logo.resize((lw,round(logo.height*lw/logo.width)),Image.LANCZOS)
img.alpha_composite(logo,((W-lw)//2,B+44))
T=ImageFont.truetype('/tmp/fonts/Corben-Bold.ttf',38)
Bf=ImageFont.truetype('/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf',33)
R=ImageFont.truetype('/usr/share/fonts/truetype/google-fonts/Poppins-Regular.ttf',30) if __import__('os').path.exists('/usr/share/fonts/truetype/google-fonts/Poppins-Regular.ttf') else Bf
y=B+44+logo.height+18
d.text((W//2,y),"How to Play",font=T,fill=RED,anchor="mt"); y+=60
X=B+58; MAXW=W-2*X
def wrap(text,font):
    words=text.split(); lines=[]; line=""
    for w in words:
        t=(line+" "+w).strip()
        if d.textlength(t,font=font)>MAXW-28 and line: lines.append(line); line=w
        else: line=t
    lines.append(line); return lines
def item(head,body):
    global y
    d.text((X,y),head,font=Bf,fill=NAVY); y+=42
    for ln in wrap(body,R):
        d.text((X+14,y),ln,font=R,fill=INK); y+=37
    y+=14
item("Goal","First to finish 4 gem sets wins. Rubies need 2 cards; other gems need 3.")
item("Each turn","Draw 2. Make up to 3 plays: bank a bill, collect a gem, pawn a gem, hide a card in your vault, or play an action.")
item("End of turn","Keep 7 cards or fewer.")
item("Need cash?","Pawn a gem for 1 bill (Rubies and Diamonds: 2).")
item("Defense","Cards hidden in your vault fire on their own when you're targeted.")
print("bottom", y, "limit", H-B-40)
img.convert('RGB').save('mpc/front-90-how-to-play.png',dpi=(300,300))
