#!/usr/bin/env python3
"""
AUV Teleop Node
Converts geometry_msgs/Twist (from teleop_twist_keyboard) to
std_msgs/Float64MultiArray thruster setpoints for the Stonefish AUV.

Thruster layout (X-configuration, 4 horizontal + 2 vertical):
  index 0 = T_FR  front-right  horizontal  (angled +45°)
  index 1 = T_FL  front-left   horizontal  (angled -45°)
  index 2 = T_RR  rear-right   horizontal  (angled -45°)
  index 3 = T_RL  rear-left    horizontal  (angled +45°)
  index 4 = T_VF  vertical-front (down-pointing)
  index 5 = T_VR  vertical-rear  (down-pointing)

Twist mapping:
  linear.x  → surge  (forward/back)
  linear.y  → sway   (left/right)
  linear.z  → heave  (up/down)   [+z = up in ROS, invert for depth]
  angular.z → yaw    (rotate)

Keyboard bindings (teleop_twist_keyboard defaults):
  i        → forward
  ,        → backward
  j        → rotate left (yaw)
  l        → rotate right (yaw)
  u/o      → diagonal
  k        → stop
  t        → up (heave)
  b        → down (heave)
  q/z      → increase/decrease max speed
"""

import math
import rclpy
from rclpy.node import Node
from geometry_msgs.msg import Twist
from std_msgs.msg import Float64MultiArray


class AUVTeleop(Node):

    def __init__(self):
        super().__init__('auv_teleop')

        self.sub = self.create_subscription(
            Twist, '/cmd_vel', self.twist_callback, 10)

        self.pub = self.create_publisher(
            Float64MultiArray, '/auv/thrusters', 10)

        # Allocation matrix: maps [surge, sway, yaw] → 4 horizontal thrusters
        # Each column is the contribution of one DOF to each thruster
        # Thruster thrust direction resolved along vehicle X axis (cos 45° = 0.707)
        c = math.cos(math.radians(45))  # 0.7071
        # Rows: T_FR, T_FL, T_RR, T_RL
        # Cols: surge, sway, yaw
        self.B_horiz = [
            [ c, -c, -c],   # T_FR: +surge, -sway, -yaw
            [ c,  c,  c],   # T_FL: +surge, +sway, +yaw
            [-c, -c,  c],   # T_RR: -surge, -sway, +yaw
            [-c,  c, -c],   # T_RL: -surge, +sway, -yaw
        ]

        self.get_logger().info(
            'AUV Teleop ready.\n'
            'Subscribing: /cmd_vel\n'
            'Publishing:  /auv/thrusters (6 values)\n'
            'Keys: i=forward  ,=back  j=yaw-left  l=yaw-right\n'
            '      t=up  b=down  k=stop  q/z=speed up/down'
        )

    def twist_callback(self, msg: Twist):
        surge = msg.linear.x
        sway  = msg.linear.y
        yaw   = msg.angular.z
        # ROS z+ = up; positive heave cmd should push robot up → negative thruster
        heave = -msg.linear.z

        # ── Horizontal thrusters (4) ──────────────────────────────────────
        horiz = []
        for row in self.B_horiz:
            val = row[0] * surge + row[1] * sway + row[2] * yaw
            horiz.append(val)

        # ── Vertical thrusters (2) ────────────────────────────────────────
        vert = [heave, heave]

        setpoints = horiz + vert

        # Normalise so no value exceeds ±1.0
        max_val = max(abs(v) for v in setpoints)
        if max_val > 1.0:
            setpoints = [v / max_val for v in setpoints]

        out = Float64MultiArray()
        out.data = setpoints
        self.pub.publish(out)


def main(args=None):
    rclpy.init(args=args)
    node = AUVTeleop()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
