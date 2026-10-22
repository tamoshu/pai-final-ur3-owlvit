#!/bin/bash
# 言語指示に従って、ブロックをトレイへ仕分け、置いた結果を画像で確認する
# 使い方: sort_blocks.sh "赤いブロックを左のトレイへ"
#         sort_blocks.sh "赤は左、青は右"
# 環境変数: TOL=許容距離[m] (省略時 0.06。トレイは12cm四方)
# 前提: start_ur3.sh と spawn_scene.sh が済み、アームがホーム姿勢であること
source ~/dev_ws/scripts/env.sh
S=~/dev_ws/scripts
IMG=~/dev_ws/observe_loop.png
IMG2=~/dev_ws/verify_loop.png
LOG=~/dev_ws/sort_log.txt
TOL=${TOL:-0.06}
declare -A TX=( [left]=-0.17 [right]=0.17 )
declare -A TY=( [left]=0.40  [right]=0.40 )
AT_OBS=0   # アームが観察姿勢にいるか(1=いる)

movej() {
  OUT=$(ros2 action send_goal /Move ros2srrc_data/action/Move "{action: 'MoveJ', speed: 1.0, movej: {joint1: $1, joint2: $2, joint3: $3, joint4: $4, joint5: $5, joint6: $6, joint7: 0.0}}")
  echo "$OUT" | grep "result:"
  if echo "$OUT" | grep -q "FAILED"; then echo "!! MoveJ失敗のため中断: $*"; exit 1; fi
}

verify() {   # 引数: 色 トレイ
  movej 180 -90 0 -90 0 0
  AT_OBS=1
  python3 $S/capture_image.py /camera_top/cam/image_raw $IMG2 > /dev/null || return 1
  local RES VX VY VS DIST
  RES=$(python3 $S/locate_block.py $IMG2 "a $1 block" 2>$S/last_verify.log | tail -1)
  grep -E "target=" $S/last_verify.log
  read VX VY VS <<< "$RES"
  if [ -z "$VY" ]; then
    echo "   確認: NG ($1 のブロックが検出できない)"
    echo "$1 $2 verify NG notfound" >> $LOG
    return 1
  fi
  DIST=$(python3 -c "import math; print('%.3f' % math.hypot($VX-(${TX[$2]}), $VY-(${TY[$2]})))")
  if python3 -c "import sys; sys.exit(0 if $DIST <= $TOL else 1)"; then
    echo "   確認: OK ($1 は $2 トレイの中心から ${DIST}m、許容 ${TOL}m)"
    echo "$1 $2 verify OK $VX $VY $VS dist=$DIST" >> $LOG
  else
    echo "   確認: NG ($1 は $2 トレイの中心から ${DIST}m、許容 ${TOL}m を超過)"
    echo "$1 $2 verify NG $VX $VY $VS dist=$DIST" >> $LOG
    return 1
  fi
}

PAIRS=$(python3 $S/parse_instruction.py "$@") || exit 1
echo "== 指示: $*"
echo "$PAIRS" | sed 's/^/   /'

while read C TRAY; do
  echo "=========== $C -> $TRAY"
  echo "== [1] 観察姿勢へ"
  if [ "$AT_OBS" != 1 ]; then movej 180 -90 0 -90 0 0; else echo "   (確認時の観察姿勢のまま)"; fi
  echo "== [2] 撮影"
  python3 $S/capture_image.py /camera_top/cam/image_raw $IMG > /dev/null || exit 1
  echo "== [3] 検出 (a $C block)"
  RESULT=$(python3 $S/locate_block.py $IMG "a $C block" 2>$S/last_detect.log | tail -1)
  grep -E "cand|target=" $S/last_detect.log
  read PX PY SCORE <<< "$RESULT"
  if [ -z "$PY" ]; then echo "!! $C のブロックを検出できなかったため中断"; exit 1; fi
  echo "   検出: x=$PX y=$PY score=$SCORE"
  echo "$C $TRAY $PX $PY $SCORE" >> $LOG
  echo "== [4] ホームへ戻り、下向き姿勢へ"
  movej 0 -90 0 -90 0 0
  AT_OBS=0
  $S/pregrasp.sh > /dev/null || exit 1
  echo "== [5] 持つ"
  $S/pick.sh $PX $PY block_$C || exit 1
  echo "== [6] $TRAY トレイへ置く"
  $S/place.sh ${TX[$TRAY]} ${TY[$TRAY]} block_$C || exit 1
  echo "== [7] ホームへ戻る"
  movej 0 -90 0 -90 0 0
  echo "== [8] 置いた結果を確認"
  verify $C $TRAY || { echo "!! $C の仕分けに失敗したため中断"; exit 1; }
done <<< "$PAIRS"
movej 0 -90 0 -90 0 0
echo "== sort_blocks 完了"
