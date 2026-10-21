#!/bin/bash
# ホーム姿勢から、ブロックの上で下向きの姿勢へ、関節を1つずつ動かす
source ~/dev_ws/scripts/env.sh
movej() {
  echo "== MoveJ: $*"
  OUT=$(ros2 action send_goal /Move ros2srrc_data/action/Move "{action: 'MoveJ', speed: 1.0, movej: {joint1: $1, joint2: $2, joint3: $3, joint4: $4, joint5: $5, joint6: $6, joint7: 0.0}}")
  echo "$OUT" | grep "result:"
  if echo "$OUT" | grep -q "FAILED"; then echo "!! 失敗のため中断"; exit 1; fi
}
movej 69.4 -90 0 -90 0 0
movej 69.4 -90 90 -90 0 0
movej 69.4 -90 90 -90 -90 0
echo "== 完了。現在位置:"
ros2 topic echo /Robpose --once
