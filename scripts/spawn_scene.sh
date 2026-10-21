#!/bin/bash
# 置き台とブロックをGazeboにスポーンする(Gazebo起動後に実行)
source ~/dev_ws/scripts/env.sh
ros2 run ros2srrc_execution SpawnObject.py --package "ros2srrc_ur3" --urdf "table_static.urdf" --name "table_static" --x 0.0 --y 0.4 --z 0.25
ros2 run ros2srrc_execution SpawnObject.py --package "ros2srrc_ur3" --urdf "block_red.urdf" --name "block_red" --x ${1:-0.0} --y ${2:-0.35} --z 0.53
ros2 run ros2srrc_execution SpawnObject.py --package "ros2srrc_ur3" --urdf "camera_top.urdf" --name "camera_top" --x 0.0 --y 0.4 --z 1.5
