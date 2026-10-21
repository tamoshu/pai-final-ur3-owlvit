#!/bin/bash
# UR3 + Gazebo + MoveIt2/RViz を起動する。引数で構成を切り替え可(省略時は ur3_2)
# 使い方: ~/dev_ws/scripts/start_ur3.sh [ur3_1|ur3_2|ur3_3]
CONFIG="${1:-ur3_2}"
source ~/dev_ws/scripts/env.sh
ros2 launch ros2srrc_launch moveit2.launch.py package:=ros2srrc_ur3 config:=${CONFIG}
