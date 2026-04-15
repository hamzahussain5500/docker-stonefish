# docker-stonefish

Docker image with **ROS2 Jazzy Desktop** + **Stonefish simulator** built from source, with NVIDIA GPU passthrough for OpenGL rendering. Includes a ready-to-run **FLS sonar demo** with a simple underwater robot.

## What's inside

| Component | Details |
|---|---|
| Base OS | Ubuntu 24.04 |
| ROS2 | Jazzy Desktop |
| Stonefish C++ lib | latest (`master`) |
| stonefish_ros2 | latest (`master`) |
| GPU support | NVIDIA (OpenGL 4.3+) |
| Sonar demo | `sonar_demo` ROS2 package (pre-built) |

## Repository layout

```
docker-stonefish/
├── Dockerfile
├── docker-compose.yml
├── .env
├── README.md
└── files/
    ├── sonar_demo.scn          # Stonefish scenario XML
    └── sonar_demo.launch.py    # ROS2 launch file
```

---

## Prerequisites (host machine)

- Docker + Docker Compose
- NVIDIA GPU with driver installed (`nvidia-smi` must work)
- NVIDIA Container Toolkit

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

---

## Build

```bash
# Allow GUI apps to open on your host display
xhost +local:docker

cd docker-stonefish
docker compose build
```

The build clones and compiles Stonefish, stonefish_ros2, and the sonar_demo package — expect ~10–20 minutes.

---

## Run

```bash
docker compose up -d
docker compose exec ros2-jazzy bash
```

---

## Verify (inside the container)

```bash
nvidia-smi                          # GPU visible
glxinfo | grep "OpenGL version"     # expect OpenGL 4.6 NVIDIA
ldconfig -p | grep Stonefish        # Stonefish C++ lib installed
ros2 pkg list | grep stonefish      # stonefish_ros2 ready
ros2 pkg list | grep sonar_demo     # sonar demo ready
```

---

## Run the FLS sonar demo

```bash
# Inside the container
ros2 launch sonar_demo sonar_demo.launch.py
```

Two windows open:
- **Stonefish 3D renderer** — shows the underwater scene with the AUV and a box obstacle 5 m ahead
- **RViz2** — add the sonar topic here to visualize the data

### Visualize sonar output in RViz2

1. In RViz2, set **Fixed Frame** → `world`
2. Click **Add** → **By topic** → `/auv/fls` → select **Image**
3. The sonar fan image appears — bright returns = detected objects

Or use rqt in a second terminal:

```bash
docker compose exec ros2-jazzy bash
ros2 run rqt_image_view rqt_image_view /auv/fls
```

### Published topics

| Topic | Type | Rate | Description |
|---|---|---|---|
| `/auv/fls` | `sensor_msgs/Image` | 5 Hz | FLS sonar intensity image |
| `/auv/imu` | `sensor_msgs/Imu` | 50 Hz | IMU orientation + angular velocity |
| `/auv/odometry` | `nav_msgs/Odometry` | 10 Hz | Ground-truth pose |

---

## Sonar scenario explained

The demo scene (`files/sonar_demo.scn`) contains:

- **Seabed** — flat plane at 10 m depth
- **Obstacle** — 1 m³ box placed 5 m ahead of the robot at 5 m depth
- **AUV** — box-shaped robot spawned at 3 m depth facing the obstacle
- **FLS sensor** — mounted on the robot nose, 120° horizontal fan, 20° vertical, 0.2–20 m range

The obstacle appears as a bright arc in the sonar image at roughly 5 m range.

### FLS parameter reference

| Parameter | Value | Meaning |
|---|---|---|
| `beams` | 256 | Angular resolution of the fan |
| `bins` | 300 | Range resolution (samples per beam) |
| `horizontal_fov` | 120° | Width of the sonar fan |
| `vertical_fov` | 20° | Vertical aperture |
| `range_min/max` | 0.2–20 m | Detection range |
| `gain` | 1.1 | Echo amplification |
| `multiplicative` noise | 0.03 | 3% proportional noise |
| `additive` noise | 0.05 | Background noise floor |
| `colormap` | `hot` | Display colour (hot = black→red→yellow→white) |

---

## Add your own scenario

1. Create a new `.scn` file in `files/` following the same XML structure
2. Create a matching launch file that points `scenario_desc` to your new `.scn`
3. Rebuild only the demo package:

```bash
cd /root/ros2_ws
colcon build --packages-select sonar_demo
source install/setup.bash
```

Available sonar types in Stonefish:

| Type | XML tag | Description |
|---|---|---|
| Forward Looking Sonar | `type="fls"` | Fan-shaped, sees ahead |
| Side Scan Sonar | `type="sss"` | Two lateral beams, seabed mapping |
| Mechanical Scanning | `type="msis"` | 360° rotating single beam |

---

## DDS middleware

Default is **FastDDS** (no config file needed). Change `RMW_IMPLEMENTATION` in `.env` to switch:

| Middleware | Value |
|---|---|
| FastDDS (default) | `rmw_fastrtps_cpp` |
| CycloneDDS | `rmw_cyclonedds_cpp` |
| Zenoh | `rmw_zenoh_cpp` |
