#!/bin/bash
# pregrasp.sh のあとで実行する: ブロックの上へ移動 → 下降 → 閉じる → 固定 → 持ち上げ
# 使い方: pick.sh [物体名(省略時 block_red)]
source ~/dev_ws/scripts/env.sh
PX="${1:-0.0}"; PY="${2:-0.35}"; OBJ="${3:-block_red}"
Q="qx: -0.4025453, qy: 0.5813441, qz: 0.4025421, qw: 0.5813399"   # EE下向きの姿勢(pregrasp後に読んだ値)

robmove() {  # 引数: type x y z
  echo "== RobMove $1  x=$2 y=$3 z=$4"
  OUT=$(ros2 action send_goal /Robmove ros2srrc_data/action/Robmove "{type: '$1', speed: 1.0, x: $2, y: $3, z: $4, $Q}")
  echo "$OUT" | grep -E "success|message"
  if ! echo "$OUT" | grep -q "success: true"; then echo "!! 失敗のため中断"; exit 1; fi
}

moveg() {  # 引数: 閉じる割合(0-100)
  echo "== MoveG $1"
  OUT=$(ros2 action send_goal /Move ros2srrc_data/action/Move "{action: 'MoveG', speed: 1.0, moveg: $1}")
  echo "$OUT" | grep "result:"
  if echo "$OUT" | grep -q "FAILED"; then echo "!! 失敗のため中断"; exit 1; fi
}

attach() {
  echo "== ATTACH $OBJ"
  OUT=$(ros2 service call /ATTACHLINK linkattacher_msgs/srv/AttachLink "{model1_name: 'ur3', link1_name: 'EE_robotiq_2f85', model2_name: '$OBJ', link2_name: '$OBJ'}")
  echo "$OUT" | grep "response" -A 1
  if ! echo "$OUT" | grep -q "success=True"; then echo "!! 失敗のため中断"; exit 1; fi
}

moveg 0                       # 全開
robmove LIN $PX $PY 0.6826484   # ブロックの真上へ
robmove LIN $PX $PY 0.54        # 指がブロックの両側に入る高さ
moveg 50                      # 閉じる
attach                        # LinkAttacherで固定
robmove LIN $PX $PY 0.6826484   # 持ち上げ
echo "== pick 完了"
