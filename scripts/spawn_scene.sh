#!/bin/bash
# 置き台・ブロック・トレイ・カメラをGazeboにスポーンする(Gazebo起動後に実行)
# 使い方: spawn_scene.sh                        赤・青・緑の3個を出す
#         BLOCKS="red blue" spawn_scene.sh      出すブロックを限定する
source ~/dev_ws/scripts/env.sh
SP="ros2 run ros2srrc_execution SpawnObject.py --package ros2srrc_ur3"
declare -A BY=( [red]=0.30 [blue]=0.40 [green]=0.50 )

$SP --urdf "table_static.urdf" --name "table_static" --x 0.0 --y 0.4 --z 0.25
for C in ${BLOCKS:-red blue green}; do
  $SP --urdf "block_$C.urdf" --name "block_$C" --x 0.0 --y ${BY[$C]} --z 0.53
done
$SP --urdf "tray_left.urdf"  --name "tray_left"  --x -0.17 --y 0.40 --z 0.501
$SP --urdf "tray_right.urdf" --name "tray_right" --x 0.17  --y 0.40 --z 0.501
$SP --urdf "camera_top.urdf" --name "camera_top" --x 0.0 --y 0.4 --z 1.5
