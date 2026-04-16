FROM ubuntu:24.04
LABEL maintainer="hamzahussain5500@gmail.com"

ARG rosversion=jazzy
ENV ROS_DISTRO=${rosversion}
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=graphics,utility,compute

# ── 1. Locale ────────────────────────────────────────────────────────────────
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    locales \
    && locale-gen en_US en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# ── 2. ROS2 Jazzy apt source ─────────────────────────────────────────────────
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    software-properties-common \
    curl \
    && add-apt-repository universe \
    && curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
       -o /usr/share/keyrings/ros-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu noble main" \
       | tee /etc/apt/sources.list.d/ros2.list > /dev/null \
    && rm -rf /var/lib/apt/lists/*

# ── 3. ROS2 Jazzy Desktop + colcon + DDS middleware ──────────────────────────
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ros-jazzy-desktop \
    python3-colcon-common-extensions \
    ros-jazzy-rmw-cyclonedds-cpp \
    ros-jazzy-rmw-zenoh-cpp \
    ros-jazzy-pcl-conversions \
    ros-jazzy-image-transport \
    ros-jazzy-tf2-ros \
    ros-jazzy-teleop-twist-keyboard \
    ros-jazzy-joy \
    ros-jazzy-joy-linux \
    ros-jazzy-teleop-twist-joy \
    joystick \
    xterm \
    && rm -rf /var/lib/apt/lists/*

# ── 4. Stonefish C++ build dependencies + general tools ──────────────────────
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    libglm-dev \
    libsdl2-dev \
    libfreetype6-dev \
    libglvnd-dev \
    libgl1 \
    libegl1 \
    libgles2 \
    mesa-utils \
    cmake \
    g++ \
    make \
    git \
    vim \
    iputils-ping \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

# ── 5. Clone, build and install Stonefish C++ library ────────────────────────
# Build twice: once for system-wide install, once with BUILD_TESTS=ON.
# BUILD_TESTS swaps the installed library for a local test variant, so the
# two builds must stay in separate directories.
RUN git clone https://github.com/patrykcieslak/stonefish.git /root/stonefish \
    && cd /root/stonefish \
    # --- install build (no tests) ---
    && mkdir build && cd build \
    && cmake .. -DCMAKE_BUILD_TYPE=Release \
    && make -j$(nproc) \
    && make install \
    && ldconfig \
    # --- test build ---
    && cd /root/stonefish \
    && mkdir build_tests && cd build_tests \
    && cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTS=ON \
    && make -j$(nproc)

# ── 6. Clone and build stonefish_ros2 wrapper ────────────────────────────────
RUN mkdir -p /root/ros2_ws/src \
    && cd /root/ros2_ws/src \
    && git clone https://github.com/patrykcieslak/stonefish_ros2.git \
    && cd /root/ros2_ws \
    && /bin/bash -c "source /opt/ros/jazzy/setup.bash && \
       colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release"

# ── 7. Create sonar_demo package ─────────────────────────────────────────────
RUN mkdir -p /root/ros2_ws/src/sonar_demo/scenarios \
             /root/ros2_ws/src/sonar_demo/data \
             /root/ros2_ws/src/sonar_demo/launch \
             /root/ros2_ws/src/sonar_demo/cfg

# CMakeLists.txt — includes Python script installation
RUN printf '%s\n' \
    'cmake_minimum_required(VERSION 3.8)' \
    'project(sonar_demo)' \
    'find_package(ament_cmake REQUIRED)' \
    'find_package(rclpy REQUIRED)' \
    'find_package(geometry_msgs REQUIRED)' \
    'find_package(std_msgs REQUIRED)' \
    'install(DIRECTORY scenarios data launch cfg DESTINATION share/${PROJECT_NAME})' \
    'install(PROGRAMS scripts/auv_teleop.py' \
    '  DESTINATION lib/${PROJECT_NAME}' \
    '  RENAME auv_teleop)' \
    'ament_package()' \
    > /root/ros2_ws/src/sonar_demo/CMakeLists.txt

# package.xml
RUN printf '%s\n' \
    '<?xml version="1.0"?>' \
    '<package format="3">' \
    '  <name>sonar_demo</name>' \
    '  <version>0.0.1</version>' \
    '  <description>AUV sonar demo with keyboard teleop in Stonefish</description>' \
    '  <maintainer email="you@email.com">you</maintainer>' \
    '  <license>MIT</license>' \
    '  <buildtool_depend>ament_cmake</buildtool_depend>' \
    '  <exec_depend>stonefish_ros2</exec_depend>' \
    '  <exec_depend>rviz2</exec_depend>' \
    '  <exec_depend>rclpy</exec_depend>' \
    '  <exec_depend>geometry_msgs</exec_depend>' \
    '  <exec_depend>std_msgs</exec_depend>' \
    '  <exec_depend>teleop_twist_keyboard</exec_depend>' \
    '  <export><build_type>ament_cmake</build_type></export>' \
    '</package>' \
    > /root/ros2_ws/src/sonar_demo/package.xml

# Scripts directory for Python nodes
RUN mkdir -p /root/ros2_ws/src/sonar_demo/scripts

# Copy propeller mesh from stonefish test data into the package data folder
RUN cp /root/stonefish/Tests/Data/propeller.obj /root/ros2_ws/src/sonar_demo/data/propeller.obj

# Scenario XML
COPY files/sonar_demo.scn /root/ros2_ws/src/sonar_demo/scenarios/sonar_demo.scn

# Launch file
COPY files/sonar_demo.launch.py /root/ros2_ws/src/sonar_demo/launch/sonar_demo.launch.py

# Teleop Python node
COPY files/auv_teleop.py /root/ros2_ws/src/sonar_demo/scripts/auv_teleop.py

# Build sonar_demo into the workspace
RUN /bin/bash -c "source /opt/ros/jazzy/setup.bash && \
    source /root/ros2_ws/install/setup.bash && \
    cd /root/ros2_ws && \
    colcon build --packages-select sonar_demo --cmake-args -DCMAKE_BUILD_TYPE=Release"

# ── 8. Source ROS2 and workspace in every bash session ───────────────────────
RUN echo "source /opt/ros/jazzy/setup.bash" >> /root/.bashrc \
    && echo "[ -f /root/ros2_ws/install/setup.bash ] && source /root/ros2_ws/install/setup.bash" >> /root/.bashrc


# install gazebo and libraries.
RUN /bin/bash -c "apt update && apt install -y ros-jazzy-ros-gz && \
    source /opt/ros/jazzy/setup.bash && \
    git clone https://github.com/libsdl-org/SDL.git -b SDL2 && \
    cd SDL && \
    mkdir build && cd build && ../configure && cmake && \
    make -j$(nproc) && make install && \
    apt install libfreetype6-dev"


#now setup the MBARI ROS pkg

RUN git clone https://github.com/AlePuglisi/MBARI-vehicles-sim-ros2.git /root/MBARI-vehicles-sim-ros2

RUN /bin/bash -c "source /opt/ros/jazzy/setup.bash && \
    source /root/ros2_ws/install/setup.bash && \
    cd /root/MBARI-vehicles-sim-ros2/stonefish_ws && \
    colcon build && \
    cd /root/MBARI-vehicles-sim-ros2/gazebo_ws && \
    source /root/MBARI-vehicles-sim-ros2/stonefish_ws/install/setup.bash && \
    colcon build"



RUN echo "source /root/MBARI-vehicles-sim-ros2/stonefish_ws/install/setup.bash" >> ~/.bashrc &&\
    echo "source /root/MBARI-vehicles-sim-ros2/gazebo_ws/install/setup.bash" >> ~/.bashrc






CMD ["/bin/bash"]
