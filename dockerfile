FROM ubuntu:24.04
LABEL maintainer="your@email.com"

ARG rosversion=jazzy
ENV ROS_DISTRO=${rosversion}
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Set locale
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    locales \
    && locale-gen en_US en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# Add ROS2 Jazzy apt source (official method)
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    software-properties-common \
    curl \
    && add-apt-repository universe \
    && curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null \
    && rm -rf /var/lib/apt/lists/*

# Install ROS2 Jazzy Desktop (includes rviz2, rqt, demos, GUI tools)
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ros-jazzy-desktop \
    python3-colcon-common-extensions \
    vim \
    git \
    iputils-ping \
    net-tools \
    ros-jazzy-rmw-cyclonedds-cpp \
    ros-jazzy-rmw-zenoh-cpp \
    && rm -rf /var/lib/apt/lists/*

# Source ROS in every interactive bash session
RUN echo "source /opt/ros/jazzy/setup.bash" >> /root/.bashrc

CMD ["/bin/bash"]
