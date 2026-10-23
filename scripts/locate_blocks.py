#!/usr/bin/env python3
# 使い方: locate_blocks.py <画像> <色> [<色> ...]    色: red / blue / green
#   標準出力に、色ごとに "色 x y score" を1行ずつ出す(見つからなければ "色 none")
#   モデルは1回だけ読み込み、色ごとに、locate_block.py と同じ条件で検出する
import sys, torch
from PIL import Image
from transformers import OwlViTProcessor, OwlViTForObjectDetection

# カメラの設定(camera_top.urdf と一致させる。画像の上が +X、左が +Y)
CAM_X, CAM_Y, CAM_Z = 0.0, 0.4, 1.5
W, H = 640, 480
FX = (W / 2) / 0.5774        # 横視野角60度の焦点距離(画素)
OBJ_TOP_Z = 0.54             # ブロック上面の高さ
MIN_SCORE = 0.05
MAX_BOX_PX = 45              # ブロックの枠の最大の辺(画素)。トレイや台を除外する
DISTRACTORS = ["a wooden table", "a robot arm"]

name = "google/owlvit-base-patch32"
processor = OwlViTProcessor.from_pretrained(name)
model = OwlViTForObjectDetection.from_pretrained(name).eval()
post = getattr(processor, "post_process_object_detection", None) or processor.image_processor.post_process_object_detection

image = Image.open(sys.argv[1]).convert("RGB")
d = CAM_Z - OBJ_TOP_Z

for color in sys.argv[2:]:
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
    if not sel or float(res["scores"][sel[0]]) < MIN_SCORE:
        print("%s none" % color)
        print("target=%r: 見つかりませんでした" % queries[0], file=sys.stderr)
        continue
    i = sel[0]
    x0, y0, x1, y1 = [float(v) for v in res["boxes"][i]]
    u, v = (x0 + x1) / 2, (y0 + y1) / 2
    x = CAM_X - (v - H / 2) * d / FX
    y = CAM_Y - (u - W / 2) * d / FX
    second = float(res["scores"][sel[1]]) if len(sel) > 1 else 0.0
    print("target=%r pixel center: u=%.0f v=%.0f score=%.3f (2nd=%.3f)" % (queries[0], u, v, float(res["scores"][i]), second), file=sys.stderr)
    print("%s %.4f %.4f %.3f" % (color, x, y, float(res["scores"][i])))
