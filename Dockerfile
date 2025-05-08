# 使用官方的 Jenkins inbound agent 作为基础镜像
FROM jenkins/inbound-agent:latest-jdk17 AS base

# 切换到 root 用户以安装软件
USER root

# 定义 JDK 和 mvnd 版本及下载 URL
ARG JDK_VERSION=8u412-b08
ARG JDK_CHECKSUM=f6cb00580df239389097c8990923916b21610ff10e21a79140760a0170000607
ARG JDK_URL=https://github.com/adoptium/temurin8-binaries/releases/download/jdk${JDK_VERSION}/OpenJDK8U-jdk_x64_linux_hotspot_${JDK_VERSION}.tar.gz

ARG MVND_VERSION=1.0.2
ARG MVND_CHECKSUM=1f061c3d038150000e31791694149a1b79485899819057a3145903378a2f811a
ARG MVND_URL=https://github.com/apache/maven-mvnd/releases/download/${MVND_VERSION}/mvnd-${MVND_VERSION}-linux-amd64.tar.gz

# ENV JAVA_HOME is inherited from base image (JDK 17)
ENV JDK8_HOME=/opt/jdk-1.8
# Add mvnd to PATH
ENV PATH=/opt/mvnd/bin:$PATH

# 安装必要的工具 (wget, tar, etc.)
# This layer installs tools required for downloading and extracting JDK and mvnd.
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    tar \
    gzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 安装 Adoptium JDK 1.8 和 Apache mvnd
# This single RUN command installs both JDK 8 and mvnd to reduce image layers.
RUN set -eux; \
    # --- JDK 1.8 Installation ---
    echo "Installing Adoptium JDK ${JDK_VERSION} to ${JDK8_HOME}..."; \
    mkdir -p ${JDK8_HOME}; \
    wget -q -O /tmp/openjdk.tar.gz ${JDK_URL}; \
    echo "Verifying JDK 8 checksum (${JDK_CHECKSUM})..."; \
    echo "${JDK_CHECKSUM}  /tmp/openjdk.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/openjdk.tar.gz -C ${JDK8_HOME} --strip-components=1; \
    rm -f /tmp/openjdk.tar.gz; \
    echo "Ensuring JDK 8 binaries are executable..."; \
    chmod +x ${JDK8_HOME}/bin/java ${JDK8_HOME}/bin/javac; \
    echo "Verifying JDK 8 installation (${JDK8_HOME}/bin/java -version):"; \
    ${JDK8_HOME}/bin/java -version; \
    ${JDK8_HOME}/bin/javac -version; \
    echo "JDK 1.8 installation complete."; \
    \
    # --- Apache mvnd Installation ---
    echo "Installing Apache mvnd ${MVND_VERSION} to /opt/mvnd..."; \
    mkdir -p /opt/mvnd; \
    wget -q -O /tmp/mvnd.tar.gz ${MVND_URL}; \
    echo "Verifying mvnd checksum (${MVND_CHECKSUM})..."; \
    echo "${MVND_CHECKSUM}  /tmp/mvnd.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/mvnd.tar.gz -C /opt/mvnd --strip-components=1; \
    rm -f /tmp/mvnd.tar.gz; \
    echo "Verifying mvnd installation (mvnd --version):"; \
    mvnd --version; \
    echo "mvnd installation complete."

# 切换回 jenkins 用户
USER jenkins

# 验证安装
RUN echo "Java version:" && java -version && \
    echo "javac version:" && javac -version && \
    echo "mvnd version:" && mvnd --version && \
    echo "Default JAVA_HOME (from base image): ${JAVA_HOME}" && \
    echo "JDK8_HOME: ${JDK8_HOME}" && \
    echo "PATH: ${PATH}"