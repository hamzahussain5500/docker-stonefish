FROM ubuntu:24.04
LABEL maintainer="your@email.com"

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
RUN git clone https://github.com/patrykcieslak/stonefish.git /root/stonefish \
    && cd /root/stonefish \
    && mkdir build && cd build \
    && cmake .. -DCMAKE_BUILD_TYPE=Release \
    && make -j$(nproc) \
    && make install \
    && ldconfig

# ── 6. Clone and build stonefish_ros2 wrapper ────────────────────────────────
RUN mkdir -p /root/ros2_ws/src \
    && cd /root/ros2_ws/src \
    && git clone https://github.com/patrykcieslak/stonefish_ros2.git \
    && cd /root/ros2_ws \
    && /bin/bash -c "source /opt/ros/jazzy/setup.bash && \
       colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release"

# ── 7. Source ROS2 and workspace in every bash session ───────────────────────
RUN echo "source /opt/ros/jazzy/setup.bash" >> /root/.bashrc \
    && echo "source /root/ros2_ws/install/setup.bash" >> /root/.bashrc

CMD ["/bin/bash"]
