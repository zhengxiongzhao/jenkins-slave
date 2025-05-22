# 定义 JDK 和 mvnd 版本及下载 URL
ARG JDK_VERSION=8u452-b09 # Updated JDK version
# ARG JDK_CHECKSUM has been removed as per user request to not check JDK checksum.
ARG JDK_URL=https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u452-b09/OpenJDK8U-jdk_x64_linux_hotspot_8u452b09.tar.gz

ARG MVND_VERSION=1.0.2
# ARG MVND_CHECKSUM has been removed as per user request to not check mvnd checksum.
ARG MVND_URL=https://github.com/apache/maven-mvnd/releases/download/${MVND_VERSION}/maven-mvnd-${MVND_VERSION}-linux-amd64.tar.gz

ARG KUBECTL_VERSION=v1.18.20
ARG KUBECTL_URL=https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl

# 定义版本和架构 (可以作为 ARG 从 docker build 命令传入)
ARG DOCKER_CLI_VERSION="28.1.1"
ARG BUILDX_VERSION="v0.14.0"
ARG TARGET_ARCH="x86_64" # Docker 下载链接中的架构名
ARG BUILDX_TARGET_ARCH="amd64" # Buildx 下载链接中的架构名

# 安装 Docker CLI
RUN curl -L "https://download.docker.com/linux/static/stable/${TARGET_ARCH}/docker-${DOCKER_CLI_VERSION}.tgz" | \
    tar -xz -C /usr/local/bin --strip-components=1 docker/docker && \
    chmod +x /usr/local/bin/docker

# 安装 Docker Buildx
RUN mkdir -p /usr/local/lib/docker/cli-plugins && \
    curl -L "https://github.com/docker/buildx/releases/download/${BUILDX_VERSION}/buildx-${BUILDX_VERSION}.linux-${BUILDX_TARGET_ARCH}" \
    -o /usr/local/lib/docker/cli-plugins/docker-buildx && \