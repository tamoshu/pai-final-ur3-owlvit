#!/bin/bash
# 言語指示に従って、ブロックをトレイへ仕分け、置いた結果を画像で確認する
# 流れ: 観察・検出(全色まとめて) → 色ごとに「持つ・置く」 → 観察・確認(全色まとめて)
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
declare -A PX PY
AT_HOME=0   # アームがホーム姿勢にいるか(1=いる)

movej() {
  OUT=$(ros2 action send_goal /Move ros2srrc_data/action/Move "{action: 'MoveJ', speed: 1.0, movej: {joint1: $1, joint2: $2, joint3: $3, joint4: $4, joint5: $5, joint6: $6, joint7: 0.0}}")
  echo "$OUT" | grep "result:"
  if echo "$OUT" | grep -q "FAILED"; then echo "!! MoveJ失敗のため中断: $*"; exit 1; fi
}

PAIRS=$(python3 $S/parse_instruction.py "$@") || exit 1
COLORS=$(echo "$PAIRS" | awk '{print $1}' | tr '\n' ' ')
echo "== 指示: $*"
echo "$PAIRS" | sed 's/^/   /'

echo "== [1] 観察姿勢へ"
movej 180 -90 0 -90 0 0
echo "== [2] 撮影"
python3 $S/capture_image.py /camera_top/cam/image_raw $IMG > /dev/null || exit 1
echo "== [3] 検出 ($COLORS)"
python3 $S/locate_blocks.py $IMG $COLORS > $S/last_detect.txt 2> $S/last_detect.log
grep -E "target=" $S/last_detect.log
while read C X Y SC; do
  if [ "$X" = "none" ] || [ -z "$Y" ]; then echo "!! $C のブロックを検出できなかったため中断"; exit 1; fi
  PX[$C]=$X; PY[$C]=$Y
  echo "   検出: $C x=$X y=$Y score=$SC"
  echo "$C detect $X $Y $SC" >> $LOG
done < <(grep -E '^(red|blue|green) ' $S/last_detect.txt)

while read C TRAY; do
  echo "=========== $C -> $TRAY"
  echo "== [4] 下向き姿勢へ"
  if [ "$AT_HOME" != 1 ]; then movej 0 -90 0 -90 0 0; fi
  AT_HOME=0
  $S/pregrasp.sh > /dev/null || exit 1
  echo "== [5] 持つ"
  $S/pick.sh ${PX[$C]} ${PY[$C]} block_$C || exit 1
  echo "== [6] $TRAY トレイへ置く"
  $S/place.sh ${TX[$TRAY]} ${TY[$TRAY]} block_$C || exit 1
  echo "== [7] ホームへ戻る"
  movej 0 -90 0 -90 0 0
  AT_HOME=1
done <<< "$PAIRS"

echo "== [8] 置いた結果を確認"
movej 180 -90 0 -90 0 0
python3 $S/capture_image.py /camera_top/cam/image_raw $IMG2 > /dev/null || exit 1
python3 $S/locate_blocks.py $IMG2 $COLORS > $S/last_verify.txt 2> $S/last_verify.log
grep -E "target=" $S/last_verify.log
FAIL=0
while read C TRAY; do
  read -r _ VX VY VS <<< "$(grep -E "^$C " $S/last_verify.txt)"
  if [ "$VX" = "none" ] || [ -z "$VY" ]; then
    echo "   確認: NG ($C のブロックが検出できない)"
    echo "$C $TRAY verify NG notfound" >> $LOG
    FAIL=1; continue
  fi
  DIST=$(python3 -c "import math; print('%.3f' % math.hypot($VX-(${TX[$TRAY]}), $VY-(${TY[$TRAY]})))")
  if python3 -c "import sys; sys.exit(0 if $DIST <= $TOL else 1)"; then
    echo "   確認: OK ($C は $TRAY トレイの中心から ${DIST}m、許容 ${TOL}m)"
    echo "$C $TRAY verify OK $VX $VY $VS dist=$DIST" >> $LOG
  else
    echo "   確認: NG ($C は $TRAY トレイの中心から ${DIST}m、許容 ${TOL}m を超過)"
    echo "$C $TRAY verify NG $VX $VY $VS dist=$DIST" >> $LOG
    FAIL=1
  fi
done <<< "$PAIRS"
movej 0 -90 0 -90 0 0
if [ "$FAIL" = 1 ]; then echo "!! 仕分けに失敗したブロックがあります"; exit 1; fi
echo "== sort_blocks 完了"
