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

ENV JAVA_HOME=/opt/java
ENV PATH=$JAVA_HOME/bin:/opt/mvnd/bin:$PATH

# 安装必要的工具 (wget, tar, etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    tar \
    gzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 安装 Adoptium JDK 1.8
RUN set -eux; \
    mkdir -p /opt/java; \
    wget -O /tmp/openjdk.tar.gz ${JDK_URL}; \
    echo "${JDK_CHECKSUM} /tmp/openjdk.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/openjdk.tar.gz -C /opt/java --strip-components=1; \
    rm -f /tmp/openjdk.tar.gz; \
    # 确保 java 命令可用
    update-alternatives --install /usr/bin/java java ${JAVA_HOME}/bin/java 100; \
    update-alternatives --install /usr/bin/javac javac ${JAVA_HOME}/bin/javac 100; \
    # 验证安装
    java -version; \
    javac -version

# 安装 mvnd
RUN set -eux; \
    mkdir -p /opt/mvnd; \
    wget -O /tmp/mvnd.tar.gz ${MVND_URL}; \
    echo "${MVND_CHECKSUM} /tmp/mvnd.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/mvnd.tar.gz -C /opt/mvnd --strip-components=1; \
    rm -f /tmp/mvnd.tar.gz; \
    # 验证安装
    mvnd --version

# 切换回 jenkins 用户
USER jenkins

# 验证安装
RUN echo "Java version:" && java -version && \
    echo "javac version:" && javac -version && \
    echo "mvnd version:" && mvnd --version && \
    echo "JAVA_HOME: ${JAVA_HOME}" && \
    echo "PATH: ${PATH}"