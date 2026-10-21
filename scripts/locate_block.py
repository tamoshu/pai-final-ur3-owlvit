#!/usr/bin/env python3
# 使い方: locate_block.py <画像>  →  標準出力の最終行に "x y score" を出す(経過は標準エラー出力)
import sys, torch
from PIL import Image
from transformers import OwlViTProcessor, OwlViTForObjectDetection

# カメラの設定(camera_top.urdf と一致させる)
CAM_X, CAM_Y, CAM_Z = 0.0, 0.4, 1.5
W, H = 640, 480
FX = (W / 2) / 0.5774        # 横視野角60度の焦点距離(画素)
OBJ_TOP_Z = 0.54             # ブロック上面の高さ(置き台天面0.5m + ブロック0.04m)
MIN_SCORE = 0.1

queries = ["a small red cube", "a wooden table", "a white box", "a robot arm"]
name = "google/owlvit-base-patch32"
processor = OwlViTProcessor.from_pretrained(name)
model = OwlViTForObjectDetection.from_pretrained(name).eval()

image = Image.open(sys.argv[1]).convert("RGB")
inputs = processor(text=[queries], images=image, return_tensors="pt")
with torch.no_grad():
    outputs = model(**inputs)
post = getattr(processor, "post_process_object_detection", None) or processor.image_processor.post_process_object_detection
res = post(outputs=outputs, threshold=0.02, target_sizes=torch.tensor([image.size[::-1]]))[0]

sel = [i for i in range(len(res["labels"])) if int(res["labels"][i]) == 0]
sel.sort(key=lambda i: -float(res["scores"][i]))
if not sel or float(res["scores"][sel[0]]) < MIN_SCORE:
    print("対象が見つかりませんでした", file=sys.stderr)
    sys.exit(1)

i = sel[0]
x0, y0, x1, y1 = [float(v) for v in res["boxes"][i]]
u, v = (x0 + x1) / 2, (y0 + y1) / 2
d = CAM_Z - OBJ_TOP_Z
x = CAM_X - (v - H / 2) * d / FX
y = CAM_Y - (u - W / 2) * d / FX
print("pixel center: u=%.0f v=%.0f  score=%.3f" % (u, v, float(res["scores"][i])), file=sys.stderr)
print("%.4f %.4f %.3f" % (x, y, float(res["scores"][i])))
