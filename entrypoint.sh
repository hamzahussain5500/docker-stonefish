#!/bin/bash
set -e

source /opt/ros/${ROS_DISTRO:-jazzy}/setup.bash

# Source the pre-built stonefish_ros2 workspace (baked into image)
if [ -f /root/ros2_ws/install/setup.bash ]; then
    source /root/ros2_ws/install/setup.bash
fi

# Source bind-mounted MBARI workspaces if already built
if [ -f /root/MBARI-vehicles-sim-ros2/stonefish_ws/install/setup.bash ]; then
    source /root/MBARI-vehicles-sim-ros2/stonefish_ws/install/setup.bash
fi

if [ -f /root/MBARI-vehicles-sim-ros2/gazebo_ws/install/setup.bash ]; then
    source /root/MBARI-vehicles-sim-ros2/gazebo_ws/install/setup.bash
fi

exec "$@"
