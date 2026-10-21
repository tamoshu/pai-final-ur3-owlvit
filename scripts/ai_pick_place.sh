#!/bin/bash
# AIで位置を決めるピック&プレース
# 前提: start_ur3.sh と spawn_scene.sh が済み、アームがホーム姿勢であること
source ~/dev_ws/scripts/env.sh
S=~/dev_ws/scripts
IMG=~/dev_ws/observe.png

movej() {
  OUT=$(ros2 action send_goal /Move ros2srrc_data/action/Move "{action: 'MoveJ', speed: 1.0, movej: {joint1: $1, joint2: $2, joint3: $3, joint4: $4, joint5: $5, joint6: $6, joint7: 0.0}}")
  echo "$OUT" | grep "result:"
  if echo "$OUT" | grep -q "FAILED"; then echo "!! 失敗のため中断"; exit 1; fi
}

echo "== [1] 観察用の姿勢へ(グリッパーを視野の外へ)"
movej 180 -90 0 -90 0 0
echo "== [2] カメラ画像を撮影"
python3 $S/capture_image.py /camera_top/cam/image_raw $IMG || exit 1
echo "== [3] AI(OWL-ViT)でブロックを検出"
RESULT=$(python3 $S/locate_block.py $IMG 2>/dev/null | tail -1)
read PX PY SCORE <<< "$RESULT"
if [ -z "$PY" ]; then echo "!! ブロックを検出できなかったため中断"; exit 1; fi
echo "   検出: x=$PX y=$PY score=$SCORE"
echo "== [4] ホーム姿勢へ戻る"
movej 0 -90 0 -90 0 0
echo "== [5] 下向き姿勢へ"
$S/pregrasp.sh || exit 1
echo "== [6] 検出した位置で持つ"
$S/pick.sh $PX $PY || exit 1
echo "== [7] 置く"
$S/place.sh || exit 1
echo "== ai_pick_place 完了"
