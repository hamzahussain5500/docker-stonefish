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
optitrack-roboticslab-ws/
├── docker-stonefish/
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── .env
│   ├── README.md
│   └── files/
│       ├── sonar_demo.scn          # Stonefish scenario XML
│       └── sonar_demo.launch.py    # ROS2 launch file
└── MBARI-vehicles-sim-ros2/        # cloned on host, bind-mounted into container
    ├── stonefish_ws/
    └── gazebo_ws/
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
# 1. Clone MBARI workspace next to docker-stonefish (only needed once)
cd /home/hamza/cub_marine/optitrack-roboticslab-ws
git clone https://github.com/AlePuglisi/MBARI-vehicles-sim-ros2.git

# 2. Allow GUI apps to open on your host display
xhost +local:docker

# 3. Build the image
cd docker-stonefish
docker compose build
```

The build compiles Stonefish, stonefish_ros2, and the sonar_demo package — expect ~10–20 minutes.
The MBARI workspace is **not** baked into the image; it is bind-mounted from the host (see [Editing the MBARI workspace](#editing-the-mbari-workspace)).

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

## Editing the MBARI workspace

The MBARI repo lives on your **host** at `optitrack-roboticslab-ws/MBARI-vehicles-sim-ros2/` and is bind-mounted read-write into the container at `/root/MBARI-vehicles-sim-ros2`. Edits you make on the host (or inside the container) are immediately visible on both sides and survive `docker compose down`.

### First-time build (inside the container)

After cloning on the host and starting the container for the first time, build both workspaces once:

```bash
docker compose exec ros2-jazzy bash

# Inside the container:
source /opt/ros/jazzy/setup.bash
source /root/ros2_ws/install/setup.bash

cd /root/MBARI-vehicles-sim-ros2/stonefish_ws
colcon build

cd /root/MBARI-vehicles-sim-ros2/gazebo_ws
source /root/MBARI-vehicles-sim-ros2/stonefish_ws/install/setup.bash
colcon build
```

The `build/`, `install/`, and `log/` directories are written into your host clone and persist across container restarts. The `.bashrc` inside the container sources these overlays automatically on the next shell open.

### Iterating on a package

```bash
# Edit files on the host with your favourite editor, then rebuild only what changed:
cd /root/MBARI-vehicles-sim-ros2/stonefish_ws   # or gazebo_ws
colcon build --packages-select <package_name>
source install/setup.bash
```

No `docker compose build` needed — only do that when you change the Dockerfile itself.

### Things to be careful about

| Concern | Detail |
|---|---|
| Absolute paths in install overlay | colcon bakes `/root/MBARI-vehicles-sim-ros2` into the overlay. Do **not** move or rename the host clone after the first build, or you must rebuild inside the container. |
| Build artifacts are container-native | The `install/` tree won't work if run directly on the host (different architecture / library paths). |
| `gazebo_ws` depends on `stonefish_ws` | Always build `stonefish_ws` first, and re-source it before building `gazebo_ws`. |
| Stale overlays after a rebuild | If you run `docker compose build` and the image changes, open a fresh shell so `.bashrc` is re-evaluated. |

---


## Run the FLS sonar demo (not tested, doesnt work)

```bash
# Inside the container
ros2 launch sonar_demo sonar_demo.launch.py
```

Two windows open:
- **Stonefish 3D renderer** — shows the underwater scene with the AUV and a box obstacle 5 m ahead
- **RViz2** — add the sonar topic here to visualize the data

### Visualize sonar output in RViz2 (not tested)

1. In RViz2, set **Fixed Frame** → `world`
2. Click **Add** → **By topic** → `/auv/fls` → select **Image**
3. The sonar fan image appears — bright returns = detected objects

Or use rqt in a second terminal:

```bash
docker compose exec ros2-jazzy bash
ros2 run rqt_image_view rqt_image_view /auv/fls
```

### Published topics (unsure)

| Topic | Type | Rate | Description |
|---|---|---|---|
| `/auv/fls` | `sensor_msgs/Image` | 5 Hz | FLS sonar intensity image |
| `/auv/imu` | `sensor_msgs/Imu` | 50 Hz | IMU orientation + angular velocity |
| `/auv/odometry` | `nav_msgs/Odometry` | 10 Hz | Ground-truth pose |

---

## Sonar scenario explained (RECHECK)

The demo scene (`files/sonar_demo.scn`) contains:

- **Seabed** — flat plane at 10 m depth
- **Obstacle** — 1 m³ box placed 5 m ahead of the robot at 5 m depth
- **AUV** — box-shaped robot spawned at 3 m depth facing the obstacle
- **FLS sensor** — mounted on the robot nose, 120° horizontal fan, 20° vertical, 0.2–20 m range

The obstacle appears as a bright arc in the sonar image at roughly 5 m range.

### FLS parameter reference (???)

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
