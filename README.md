# docker-stonefish

Docker image with **ROS2 Jazzy Desktop** + **Stonefish simulator** built from source, with NVIDIA GPU passthrough for OpenGL rendering.

## What's inside

| Component | Version |
|---|---|
| Base OS | Ubuntu 24.04 |
| ROS2 | Jazzy Desktop |
| Stonefish C++ lib | latest (`master`) |
| stonefish_ros2 | latest (`master`) |
| GPU support | NVIDIA (OpenGL 4.3+) |

## Prerequisites (host machine)

- Docker + Docker Compose
- NVIDIA GPU with driver installed
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)

```bash
# Install NVIDIA Container Toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

## Build

```bash
# Allow GUI apps to display on host screen
xhost +local:docker

docker compose build
```

The build clones and compiles Stonefish and stonefish_ros2 from source — expect ~10-15 minutes.

## Run

```bash
docker compose up -d
docker compose exec ros2-jazzy bash
```

The compose file bind-mounts your host workspace folder `../ros2_ws` into the container at `/root/ros2_ws`, so anything you edit in VS Code is visible in the container (and vice versa).

If this host workspace is new/empty, build it once inside the container:

```bash
source /opt/ros/jazzy/setup.bash
cd /root/ros2_ws
colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release
```

## Verify inside the container

```bash
# GPU is visible
nvidia-smi

# OpenGL 4.6 via NVIDIA driver
glxinfo | grep "OpenGL version"

# Stonefish library installed
ldconfig -p | grep Stonefish

# ROS2 wrapper ready
ros2 pkg list | grep stonefish
```

## Run the Stonefish simulator

Create a scenario XML and a launch file that includes `stonefish_simulator.launch.py`:

```python
# my_scenario.launch.py
from launch import LaunchDescription
from launch.actions import IncludeLaunchDescription
from launch.launch_description_sources import PythonLaunchDescriptionSource
from ament_index_python.packages import get_package_share_directory
import os

def generate_launch_description():
    return LaunchDescription([
        IncludeLaunchDescription(
            PythonLaunchDescriptionSource(
                os.path.join(get_package_share_directory('stonefish_ros2'),
                             'launch', 'stonefish_simulator.launch.py')
            ),
            launch_arguments={
                'simulation_data': '/path/to/data',
                'scenario_desc':   '/path/to/scenario.xml',
                'simulation_rate': '100.0',
                'window_res_x':    '1280',
                'window_res_y':    '720',
                'rendering_quality': 'high',
            }.items()
        )
    ])
```

```bash
ros2 launch /path/to/my_scenario.launch.py
```

## DDS middleware

Default is **FastDDS** (no config file needed). To switch, change `RMW_IMPLEMENTATION` in `.env`:

| Middleware | Value |
|---|---|
| FastDDS (default) | `rmw_fastrtps_cpp` |
| CycloneDDS | `rmw_cyclonedds_cpp` |
| Zenoh | `rmw_zenoh_cpp` |
