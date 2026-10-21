# UR3 + OWL-ViT による言語指示ピック&プレース（PAI最終課題）

## 概要
カメラ画像から、オープン語彙の物体検出（OWL-ViT）で対象ブロックの位置を求め、
UR3（Gazebo Classic + MoveIt2）で持って置くシミュレーション。

## ベースコード
IFRA-Cranfield `ros2_SimRealRobotControl`（humbleブランチ、Apache-2.0）
https://github.com/IFRA-Cranfield/ros2_SimRealRobotControl

## 自作部分
- `scripts/`：撮影、検出、座標変換、ピック&プレースの各スクリプト
- `urdf/objects/`：ブロック、置き台、カメラ

## ベースへの変更
`patches/base_changes.diff`（ABBロボット用の依存を外す2か所）

## 外部モデル
OWL-ViT（`google/owlvit-base-patch32`、Hugging Face transformers 経由）