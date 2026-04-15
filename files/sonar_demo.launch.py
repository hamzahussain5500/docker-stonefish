import os
from launch import LaunchDescription
from launch.actions import TimerAction
from launch_ros.actions import Node
from ament_index_python.packages import get_package_share_directory


def generate_launch_description():
    pkg = get_package_share_directory('sonar_demo')

    data_path     = os.path.join(pkg, 'data')
    scenario_path = os.path.join(pkg, 'scenarios', 'sonar_demo.scn')

    # ── Stonefish simulator ──────────────────────────────────────────────────
    simulator = Node(
        package='stonefish_ros2',
        executable='stonefish_simulator',
        name='stonefish_simulator',
        arguments=[
            data_path,       # argv[1] — simulation data dir
            scenario_path,   # argv[2] — scenario XML
            '100.0',         # argv[3] — simulation rate Hz
            '1280',          # argv[4] — window width
            '720',           # argv[5] — window height
            'high',          # argv[6] — rendering quality
        ],
        output='screen',
    )

    # ── AUV teleop converter (Twist → Float64MultiArray thrusters) ───────────
    auv_teleop = Node(
        package='sonar_demo',
        executable='auv_teleop',
        name='auv_teleop',
        output='screen',
    )

    # ── Keyboard teleop — opens in its own xterm window ─────────────────────
    # Keys:  i=forward  ,=back  j=yaw-left  l=yaw-right
    #        t=up  b=down  k=stop  q/z=speed up/down
    keyboard = TimerAction(
        period=2.0,
        actions=[Node(
            package='teleop_twist_keyboard',
            executable='teleop_twist_keyboard',
            name='teleop_keyboard',
            prefix='xterm -title "AUV Keyboard Control" -e',
            remappings=[('cmd_vel', '/cmd_vel')],
            output='screen',
        )]
    )

    # ── RViz2 ────────────────────────────────────────────────────────────────
    rviz = TimerAction(
        period=3.0,
        actions=[Node(
            package='rviz2',
            executable='rviz2',
            name='rviz2',
            output='screen',
        )]
    )

    return LaunchDescription([simulator, auv_teleop, keyboard, rviz])
