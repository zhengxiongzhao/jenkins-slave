# 使用官方的 Jenkins inbound agent 作为基础镜像
FROM jenkins/inbound-agent:latest-jdk17 AS base

# 切换到 root 用户以安装软件
USER root

# 定义 JDK 和 mvnd 版本及下载 URL
ARG JDK_VERSION=8u452-b09 # Updated JDK version
# ARG JDK_CHECKSUM has been removed as per user request to not check JDK checksum.
ARG JDK_URL=https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u452-b09/OpenJDK8U-jdk_x64_linux_hotspot_8u452b09.tar.gz

ARG MVND_VERSION=1.0.2
# ARG MVND_CHECKSUM has been removed as per user request to not check mvnd checksum.
ARG MVND_URL=https://github.com/apache/maven-mvnd/releases/download/${MVND_VERSION}/maven-mvnd-${MVND_VERSION}-linux-amd64.tar.gz

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

# 安装 Adoptium JDK 1.8
RUN set -eux; \
    echo "Installing Adoptium JDK ${JDK_VERSION} from ${JDK_URL} to ${JDK8_HOME}..."; \
    mkdir -p ${JDK8_HOME}; \
    wget -q -O /tmp/openjdk.tar.gz ${JDK_URL}; \
    # JDK checksum verification has been removed as per user request.
    echo "Extracting JDK to ${JDK8_HOME}..."; \
    tar -xzf /tmp/openjdk.tar.gz -C ${JDK8_HOME} --strip-components=1; \
    rm -f /tmp/openjdk.tar.gz; \
    echo "Ensuring JDK binaries in ${JDK8_HOME}/bin are executable..."; \
    chmod +x ${JDK8_HOME}/bin/java ${JDK8_HOME}/bin/javac; \
    echo "Verifying JDK installation (${JDK8_HOME}/bin/java -version):"; \
    ${JDK8_HOME}/bin/java -version; \
    echo "Verifying JDK compiler installation (${JDK8_HOME}/bin/javac -version):"; \
    ${JDK8_HOME}/bin/javac -version; \
    echo "Adoptium JDK ${JDK_VERSION} installation complete."

# 安装 Apache mvnd
RUN set -eux; \
    echo "Installing Apache mvnd ${MVND_VERSION} to /opt/mvnd..."; \
    mkdir -p /opt/mvnd; \
    wget -q -O /tmp/mvnd.tar.gz ${MVND_URL}; \
    # mvnd checksum verification has been removed as per user request.
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