import sys
from PIL import Image, ImageDraw, ImageFont
im = Image.open(sys.argv[1]).convert('RGB'); W, H = im.size
d = ImageDraw.Draw(im)
f = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', int(W / 70))
f2 = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', int(W / 95))
names = [('Ржавый меч', 'обычное', '#9AA0A6'), ('Железный палаш', 'обычное', '#9AA0A6'), ('Кузнечный молот', 'обычное', '#9AA0A6'),
         ('Клинок стража', 'редкое', '#4CAF50'), ('Молот стража', 'редкое', '#4CAF50'), ('Вихревой клинок', 'эпическое', '#9C5BE0'),
         ('Расколотый молот', 'эпическое', '#9C5BE0'), ('Ключ Привратника', 'легендарное', '#F5A524')]
cols, rows = 4, 2
for i, (n, r, c) in enumerate(names):
    rr, cc = divmod(i, cols)
    x = (cc + 0.5) * W / cols; y = (rr + 1) * H / rows - W / 40
    d.text((x, y), n, font=f, fill='#EDE3CF', anchor='ms')
    d.text((x, y + W / 70), r, font=f2, fill=c, anchor='ms')
im.save(sys.argv[2])
