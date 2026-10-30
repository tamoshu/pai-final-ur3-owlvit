# UR3 + OWL-ViT による言語指示ピック&プレース（PAI最終課題）

## 概要

「赤は左、青は右」のような言葉の指示を受け取り、真上のカメラ画像から、オープン語彙の物体検出（OWL-ViT）でブロックの位置を求め、UR3（Gazebo Classic + MoveIt2）が、色ごとに指定のトレイへ仕分けるシミュレーションです。置いた後は再撮影して、各ブロックがトレイ内にあるかを自動で確認します。

- 検出は、学習なしの推論のみで、ローカルのCPUで実行します（外部APIは使いません）。
- 把持は、摩擦ではなく、ベースコードの LinkAttacher（固定ジョイント）による簡易化です。

処理の流れ：指示の解釈 → 撮影 → 検出（全色を1回で）と座標変換 → 色ごとにピック&プレース → 再撮影と結果の確認

## ベースコードと、課題サンプルとの関係

IFRA-Cranfield `ros2_SimRealRobotControl`（humbleブランチ、Apache-2.0）
https://github.com/IFRA-Cranfield/ros2_SimRealRobotControl

このリポジトリは、課題サンプル「Pick and Place Task - ROS2 Gazebo Simulation (UR3 + Robotiq 2f-85)」のソースです。ベースの付属デモは、アームのみの固定動作で、物体の認識は含みません。本作品では、検出に基づく動作、言語指示の解釈、置いた結果の確認を、自作しました。

## 自作部分

- `scripts/`：撮影、検出、座標変換、言語指示の解釈、ピック&プレース、全体制御の各スクリプト
- `urdf/objects/`：ブロック（赤・青・緑）、置き台、トレイ（左右）、真上カメラのURDF

| ファイル | 役割 |
|---|---|
| `env.sh` | ROS 2とワークスペースの環境を読み込む（`source` して使う） |
| `start_ur3.sh` | UR3 + Gazebo + MoveIt2/RViz を起動する |
| `spawn_scene.sh` | 置き台、ブロック、トレイ、カメラをスポーンする |
| `pregrasp.sh` | ホームから下向き姿勢まで、3段のMoveJで動かす |
| `pick.sh`、`place.sh` | 指定位置でのピック、指定位置へのプレース |
| `capture_image.py` | カメラ画像を1枚保存する |
| `detect_owlvit.py` | OWL-ViTの検出結果を表示し、枠つきの画像を保存する（動作確認用） |
| `locate_block.py`、`locate_blocks.py` | OWL-ViTで検出し、ワールド座標（x, y）に変換する（`locate_blocks.py` は複数色を1回で検出） |
| `draw_detections.py` | 検出結果（採用された枠）を画像に描いて保存する（レポートの図の作成用。`--others` で、採用されなかった枠も描く） |
| `parse_instruction.py` | 指示文を、キーワード対応で（色、トレイ）の組に変換する（LLMは使用していません） |
| `ai_pick_place.sh` | 1個のブロックを、観察 → 撮影 → 検出 → ピック → プレースする |
| `sort_blocks.sh` | 指示文から、検出 → 色ごとのピック&プレース → 結果の確認まで、一括で実行する |

## ベースへの変更

`patches/base_changes.diff`（ABBロボット用の依存を外す2か所）

- `ros2srrc_execution/CMakeLists.txt`：`abb_robot_msgs` への依存2行をコメントアウト
- `ros2srrc_execution/python/ExecuteProgram.py`：ABB用グリッパーのモジュール読み込みを `try/except ImportError` で囲む

## 外部モデル・ライブラリ

- OWL-ViT（`google/owlvit-base-patch32`、Apache-2.0、Hugging Face transformers 経由）
- PyTorch（CPU版）、transformers、Pillow、OpenCV、NumPy

## 動作環境

動作を確認した環境です。

- ROS 2 Humble（Ubuntu 22.04）、Gazebo Classic 11.10.2
- PyTorch 2.6.0（CPU版）、transformers 5.20.2、Pillow 12.3.0
- GPUなし。初回の検出時に、OWL-ViTのモデル（約613 MB）をダウンロードします。

## 実行手順

### 1. ベースコードの準備

1. ベースコード（上記URL）を、`Installation.md` に従ってビルドします。`gazebo_ros2_control` は、ベースのREADMEの指示に従い、0.4.6をソースからビルドします。
2. ベースコードのリポジトリで、`patches/base_changes.diff` を適用します（`git apply`）。
3. `urdf/objects/` のファイルを、ベースの `ros2srrc_ur3/urdf/objects/` にコピーします（ソース側と、`install` 側の `share/ros2srrc_ur3/urdf/objects/` の両方）。
4. `scripts/` を、`~/dev_ws/scripts/` に置きます。各スクリプトは、ワークスペースが `~/dev_ws` にあることを前提に、`~/dev_ws/scripts/env.sh` や `~/dev_ws/install/setup.bash` を読み込みます。別の場所を使う場合は、各スクリプトの `~/dev_ws` を、自分の環境に合わせて書き換えてください。

### 2. 実行

ターミナルを分けて、次の順に実行します。

```bash
# ターミナル1：UR3 + Gazebo + MoveIt2 を起動する
~/dev_ws/scripts/start_ur3.sh

# ターミナル2：シーンを配置し、仕分けを実行する（アームがホーム姿勢のとき）
~/dev_ws/scripts/spawn_scene.sh
~/dev_ws/scripts/sort_blocks.sh "赤は左、青は右"
```

`sort_blocks.sh` の指示文の例：`"赤は左、青は右"`、`"赤いブロックを左のトレイへ"`

- 左右は、ロボットから台を見た向きです（左 = −X、右 = +X）。
- 検出できない色があれば、何も動かす前に中断します。
- 置いた後は再撮影して、各ブロックが、置き先のトレイの中心から0.06 m以内かを判定します。
- 実行すると、`~/dev_ws/` の下に、撮影した画像（`observe_loop.png`、`verify_loop.png`）と、実行ログ（`sort_log.txt`）が作られます。`~/dev_ws/scripts/` の下にも、検出結果（`last_detect.*`、`last_verify.*`）が作られます。

## 限界

- 検証は、赤・青の2個のブロックと、決まった配置のみです。
- 検出のスコアは約0.1で、余裕は大きくありません。
- 検出で使う枠の大きさの条件は、カメラの高さとブロックの大きさを前提にしています。
- 同じトレイに2個以上入れる指示、緑ブロックの仕分けは、未対応です。

詳細は、提出したレポートを参照してください。

## ライセンス

ベースコード（IFRA-Cranfield）は Apache License 2.0 です。出典とライセンスは、`NOTICE.md` に記載しています。
