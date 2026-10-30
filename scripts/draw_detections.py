#!/usr/bin/env python3
# 使い方: draw_detections.py <入力画像> <出力画像> <色> [<色> ...] [--others]
#   色: red / blue / green
#   locate_blocks.py と同じ検出条件(妨害クエリ、枠の大きさ、採用スコア)で検出し、
#   採用された枠(各色の1位)を、緑の太枠とスコアで描く(ブロックの色と区別するため)。
#   緑のブロックを検出する場合は、BOX_RGB を別の色(例: 黄)に変える。
#   --others を付けると、採用されなかった枠(妨害クエリ側に分類された枠、
#   大きさの条件で除外された枠)も、灰色の細枠でラベルつきで描く(誤検出対策の説明用)。
#   画像は2倍に拡大してから描く(レポートでの見やすさのため)。
import sys, torch
from PIL import Image, ImageDraw, ImageFont
from transformers import OwlViTProcessor, OwlViTForObjectDetection

MIN_SCORE = 0.05
MAX_BOX_PX = 45              # locate_blocks.py と同じ値
DISTRACTORS = ["a wooden table", "a robot arm"]
SCALE = 2
BOX_RGB = (0, 200, 70)       # 採用した枠の色(赤・青ブロックと区別できる緑)
GRAY = (130, 130, 130)
FONT_SIZE = 32               # ラベルの文字サイズ(拡大後の画素)。大きすぎる/小さすぎる場合は調整する

def load_font(size):
    # Ubuntuに入っていることの多いDejaVuを試し、なければPillowの既定フォント(サイズ指定は新しい版のみ)
    for path in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            pass
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()
FONT = load_font(FONT_SIZE)

args = [a for a in sys.argv[1:] if not a.startswith("--")]
show_others = "--others" in sys.argv[1:]
if len(args) < 3:
    sys.exit("使い方: draw_detections.py <入力画像> <出力画像> <色> [<色> ...] [--others]")
in_path, out_path, colors = args[0], args[1], args[2:]

name = "google/owlvit-base-patch32"
processor = OwlViTProcessor.from_pretrained(name)
model = OwlViTForObjectDetection.from_pretrained(name).eval()
post = getattr(processor, "post_process_object_detection", None) or processor.image_processor.post_process_object_detection

image = Image.open(in_path).convert("RGB")
canvas = image.resize((image.width * SCALE, image.height * SCALE), Image.LANCZOS)
draw = ImageDraw.Draw(canvas)

def rect(box, color, width):
    x0, y0, x1, y1 = [float(t) * SCALE for t in box]
    draw.rectangle([x0, y0, x1, y1], outline=color, width=width)
    return x0, y0, x1, y1

def label(x, y, text, color, below_y=None):
    # 文字の背景を白にして読みやすくする(ASCII文字のみ)。枠の上に置き、はみ出す場合は枠の下に置く
    l, t, r, b = draw.textbbox((0, 0), text, font=FONT)
    w, h = r - l, b - t
    ty = y - h - 6
    if below_y is not None or ty < 0:
        ty = (below_y if below_y is not None else y) + 4
    tx = min(x, canvas.width - w - 6)
    draw.rectangle([tx, ty - 2, tx + w + 6, ty + h + 4], fill=(255, 255, 255))
    draw.text((tx + 3 - l, ty - t), text, fill=color, font=FONT)

for n, color in enumerate(colors):
    queries = ["a %s block" % color] + DISTRACTORS
    inputs = processor(text=[queries], images=image, return_tensors="pt")
    with torch.no_grad():
        outputs = model(**inputs)
    res = post(outputs=outputs, threshold=0.02, target_sizes=torch.tensor([image.size[::-1]]))[0]

    def box_size(i):
        b = [float(t) for t in res["boxes"][i]]
        return max(b[2] - b[0], b[3] - b[1])
    sel = [i for i in range(len(res["labels"])) if int(res["labels"][i]) == 0 and box_size(i) <= MAX_BOX_PX]
    sel.sort(key=lambda i: -float(res["scores"][i]))
    chosen = sel[0] if sel and float(res["scores"][sel[0]]) >= MIN_SCORE else None

    if show_others:
        for i in range(len(res["labels"])):
            if i == chosen or float(res["scores"][i]) < 0.1:
                continue
            q = queries[int(res["labels"][i])]
            reason = q if int(res["labels"][i]) != 0 else "too large"
            x0, y0, _, _ = rect(res["boxes"][i], GRAY, 1)
            label(x0, y0, "%s %.2f" % (reason, float(res["scores"][i])), GRAY)

    if chosen is None:
        print("%s: 見つかりませんでした" % color, file=sys.stderr)
        continue
    x0, y0, _, y1 = rect(res["boxes"][chosen], BOX_RGB, 3)
    # 隣り合うブロックのラベルが重ならないよう、2色目以降は枠の下に置く
    label(x0, y0, "%s block %.2f" % (color, float(res["scores"][chosen])), BOX_RGB, below_y=(y1 if n % 2 == 1 else None))

canvas.save(out_path)
print("保存しました: %s" % out_path)
