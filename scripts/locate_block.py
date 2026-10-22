#!/usr/bin/env python3
# 使い方: locate_block.py <画像> ["<探す物体>" ["<妨害クエリ1>" "<妨害クエリ2>" ...]]
#   標準出力の最終行に "x y score" を出す(経過は標準エラー出力)
#   探す物体の省略時は "a red block"、妨害クエリの省略時は台・白い箱・ロボットアーム
import sys, torch
from PIL import Image
from transformers import OwlViTProcessor, OwlViTForObjectDetection

# カメラの設定(camera_top.urdf と一致させる。画像の上が +X、左が +Y)
CAM_X, CAM_Y, CAM_Z = 0.0, 0.4, 1.5
W, H = 640, 480
FX = (W / 2) / 0.5774        # 横視野角60度の焦点距離(画素)
OBJ_TOP_Z = 0.54             # ブロック上面の高さ(置き台天面0.5m + ブロック0.04m)
MIN_SCORE = 0.05
MAX_BOX_PX = 45             # ブロックの枠の最大の辺(画素)。トレイ(約65)や台(175以上)を除外する

target = sys.argv[2] if len(sys.argv) > 2 else "a red block"
distractors = sys.argv[3:] or ["a wooden table", "a robot arm"]
queries = [target] + distractors
name = "google/owlvit-base-patch32"
processor = OwlViTProcessor.from_pretrained(name)
model = OwlViTForObjectDetection.from_pretrained(name).eval()

image = Image.open(sys.argv[1]).convert("RGB")
inputs = processor(text=[queries], images=image, return_tensors="pt")
with torch.no_grad():
    outputs = model(**inputs)
post = getattr(processor, "post_process_object_detection", None) or processor.image_processor.post_process_object_detection
res = post(outputs=outputs, threshold=0.02, target_sizes=torch.tensor([image.size[::-1]]))[0]

def box_size(i):
    b = [float(t) for t in res["boxes"][i]]
    return max(b[2] - b[0], b[3] - b[1])
sel = [i for i in range(len(res["labels"])) if int(res["labels"][i]) == 0 and box_size(i) <= MAX_BOX_PX]
sel.sort(key=lambda i: -float(res["scores"][i]))
for k in sel[:3]:
    print("  cand score=%.3f size=%.0f box=%s" % (float(res["scores"][k]), box_size(k), [round(float(t)) for t in res["boxes"][k]]), file=sys.stderr)
if not sel or float(res["scores"][sel[0]]) < MIN_SCORE:
    print("対象が見つかりませんでした: %s" % target, file=sys.stderr)
    sys.exit(1)

i = sel[0]
x0, y0, x1, y1 = [float(v) for v in res["boxes"][i]]
u, v = (x0 + x1) / 2, (y0 + y1) / 2
d = CAM_Z - OBJ_TOP_Z
x = CAM_X - (v - H / 2) * d / FX
y = CAM_Y - (u - W / 2) * d / FX
second = float(res["scores"][sel[1]]) if len(sel) > 1 else 0.0
print("target=%r pixel center: u=%.0f v=%.0f score=%.3f (2nd=%.3f)" % (target, u, v, float(res["scores"][i]), second), file=sys.stderr)
print("%.4f %.4f %.3f" % (x, y, float(res["scores"][i])))
