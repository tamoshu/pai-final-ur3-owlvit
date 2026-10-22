#!/bin/bash
# pick.sh のあとで実行する: 横へ運ぶ → 下降 → 固定解除 → グリッパーを開く → 持ち上げて離れる
# 使い方: place.sh [x] [y] [物体名]   (省略時 x=0.15 y=0.35 block_red)
source ~/dev_ws/scripts/env.sh
PX="${1:-0.15}"
PY="${2:-0.35}"
OBJ="${3:-block_red}"
Q="qx: -0.4025453, qy: 0.5813441, qz: 0.4025421, qw: 0.5813399"   # EE下向きの姿勢

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

detach() {
  echo "== DETACH $OBJ"
  OUT=$(ros2 service call /DETACHLINK linkattacher_msgs/srv/DetachLink "{model1_name: 'ur3', link1_name: 'EE_robotiq_2f85', model2_name: '$OBJ', link2_name: '$OBJ'}")
  echo "$OUT" | grep "response" -A 1
  if ! echo "$OUT" | grep -q "success=True"; then echo "!! 失敗のため中断"; exit 1; fi
}

robmove LIN $PX $PY 0.6826484   ; read -rp "[pose確認後 Enter] "
robmove LIN $PX $PY 0.54        ; read -rp "[pose確認後 Enter] "
detach                          ; read -rp "[pose確認後 Enter] "
moveg 0                         ; read -rp "[pose確認後 Enter] "
robmove LIN $PX $PY 0.6826484   ; read -rp "[pose確認後 Enter] "
echo "== place 完了"
