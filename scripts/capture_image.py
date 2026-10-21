#!/usr/bin/env python3
# 使い方: capture_image.py <トピック> <出力ファイル>
import sys, rclpy, numpy as np
from rclpy.node import Node
from rclpy.qos import qos_profile_sensor_data
from sensor_msgs.msg import Image

class Cap(Node):
    def __init__(self, topic, out):
        super().__init__('capture_once')
        self.out, self.done = out, False
        self.create_subscription(Image, topic, self.cb, qos_profile_sensor_data)
    def cb(self, m):
        if self.done: return
        a = np.frombuffer(m.data, dtype=np.uint8).reshape(m.height, m.width, 3)
        print('encoding:', m.encoding, 'size:', m.width, 'x', m.height)
        try:
            import cv2; cv2.imwrite(self.out, a[:, :, ::-1]); print('saved with cv2:', self.out)
        except ImportError:
            try:
                from PIL import Image as PI; PI.fromarray(a).save(self.out); print('saved with PIL:', self.out)
            except ImportError:
                with open(self.out + '.ppm', 'wb') as f:
                    f.write(b'P6 %d %d 255\n' % (m.width, m.height)); f.write(a.tobytes())
                print('saved as PPM:', self.out + '.ppm')
        self.done = True

rclpy.init()
n = Cap(sys.argv[1], sys.argv[2])
while rclpy.ok() and not n.done:
    rclpy.spin_once(n, timeout_sec=1.0)
rclpy.shutdown()
