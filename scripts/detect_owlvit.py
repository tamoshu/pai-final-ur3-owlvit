#!/usr/bin/env python3
# 使い方: detect_owlvit.py <画像> "<探す物体>" ["<紛らわしい物1>" "<紛らわしい物2>" ...]
# 最初の言葉が探す対象。残りは、その枠を対象から外すための「妨害クエリ」。
import sys, time, torch
from PIL import Image, ImageDraw
from transformers import OwlViTProcessor, OwlViTForObjectDetection

img_path = sys.argv[1]
queries = sys.argv[2:] or ["a small red cube", "a wooden table", "a white box", "a robot arm"]
name = "google/owlvit-base-patch32"

t0 = time.time()
processor = OwlViTProcessor.from_pretrained(name)
model = OwlViTForObjectDetection.from_pretrained(name).eval()
print("model loaded: %.1f s" % (time.time() - t0))

image = Image.open(img_path).convert("RGB")
inputs = processor(text=[queries], images=image, return_tensors="pt")
t1 = time.time()
with torch.no_grad():
    outputs = model(**inputs)
print("inference: %.1f s" % (time.time() - t1))

post = getattr(processor, "post_process_object_detection", None) or processor.image_processor.post_process_object_detection
target = torch.tensor([image.size[::-1]])
res = post(outputs=outputs, threshold=0.02, target_sizes=target)[0]

print("--- 全候補(上位5件) ---")
for i in res["scores"].argsort(descending=True)[:5]:
    x0, y0, x1, y1 = [float(v) for v in res["boxes"][i]]
    print("  '%s'  score=%.3f  box=(%.0f, %.0f, %.0f, %.0f)" % (queries[int(res["labels"][i])], float(res["scores"][i]), x0, y0, x1, y1))

sel = [i for i in range(len(res["labels"])) if int(res["labels"][i]) == 0]
sel.sort(key=lambda i: -float(res["scores"][i]))
print("--- 対象 '%s' の候補 ---" % queries[0])
draw = ImageDraw.Draw(image)
for rank, i in enumerate(sel[:3]):
    x0, y0, x1, y1 = [float(v) for v in res["boxes"][i]]
    print("#%d  score=%.3f  box=(%.0f, %.0f, %.0f, %.0f)  center=(u=%.0f, v=%.0f)" % (
        rank + 1, float(res["scores"][i]), x0, y0, x1, y1, (x0 + x1) / 2, (y0 + y1) / 2))
    if rank == 0:
        draw.rectangle([x0, y0, x1, y1], outline=(0, 255, 0), width=3)
if not sel:
    print("対象が見つかりませんでした")
image.save(img_path.replace(".png", "_det.png"))
