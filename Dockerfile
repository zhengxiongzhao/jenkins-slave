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

ARG KUBECTL_VERSION=v1.18.20
ARG KUBECTL_URL=https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl

# ENV JAVA_HOME is inherited from base image (JDK 17)
ENV JDK8_HOME=/opt/jdk-1.8
# Add mvnd to PATH
ENV PATH=/opt/mvnd/bin:$PATH

# 安装必要的工具 (wget, tar, etc.)
# This layer installs tools required for downloading and extracting JDK and mvnd.
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    vim \
    tar \
    gzip \
    ca-certificates \
    apt-transport-https \
    curl \
    bash \
    gnupg \
    expect \
    lsb-release \
    software-properties-common

# Install Docker CE (ensure this is compatible with Debian Bullseye)
# Install Docker CE using recommended method
RUN apt-get update && apt-get install -y ca-certificates curl gnupg lsb-release && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get -y update && \
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin && \
    rm -rf /var/lib/apt/lists/*

# Install kubectl
RUN curl -L ${KUBECTL_URL} -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

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


# stat -c '%g' /var/run/docker.sock
ARG DOCKER_HOST_GID=2375
RUN groupadd -g ${DOCKER_HOST_GID} docker || true # 如果组已存在则忽略错误

# Add jenkins user to docker group for DinD
RUN usermod -aG docker jenkins

# 切换回 jenkins 用户
USER jenkins

RUN mkdir .docker .yarn .npm 

RUN /bin/bash -c "mkdir -p /data/cache/{docker,npm,yarn,go,mvn}"
RUN /bin/bash -c "mkdir -p /data/cache/go/{mod-cache,cache}"

# Config docker data.
RUN printf '%s\n' \
    '{' \
    '   "data-root": "/data/cache/docker",' \
    '   "registry-mirrors": [' \
    '       "https://docker.1ms.run",' \
    '       "https://docker.m.daocloud.io"' \
    '    ]' \
    '}' \
    > /data/cache/docker/daemon.json

# Config NPM env configured with cn mirror for user jenkins.
RUN printf '%s\n' \
    'registry=https://registry.npmmirror.com/'\
    'strict-ssl=false' \
    'cache=/data/cache/npm' \
    > /home/jenkins/.npmrc

# Config YARN env configured with cn mirror for user jenkins.
RUN printf '%s\n' \
    'registry "https://registry.npmmirror.com/"'\
    'strict-ssl false' \
    'cache-folder "/data/cache/yarn"' \
    > /home/jenkins/.yarnrc 

# Config YARN 2.0 env configured with cn mirror for user jenkins.
RUN printf '%s\n' \
    'npmRegistryServer: "https://registry.npmmirror.com/"'\
    'strictSsl: false' \
    'cache-folder: "/data/cache/yarn"' \
    > /home/jenkins/.yarnrc.yml

# Config Go env configured with cn mirror for user jenkins.
RUN mkdir -p .config/go/ && \
    printf '%s\n' \
    'GO111MODULE=on'\
    'GOPROXY=https://goproxy.cn' \
    'GOMODCACHE=/data/cache/go/mod-cache' \
    'GOCACHE=/data/cache/go/cache' \
    > /home/jenkins/.config/go/env && \
    echo "Go env configured with cn mirror for user jenkins."

# Configure Maven settings.xml for Aliyun mirror for the jenkins user
RUN mkdir -p /home/jenkins/.m2 && \
    printf '%s\n' \
    '<settings xmlns="http://maven.apache.org/SETTINGS/1.2.0"' \
    '          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"' \
    '          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.2.0 https://maven.apache.org/xsd/settings-1.2.0.xsd">' \
    '  <localRepository>/data/cache/mvn</localRepository>' \
    '  <mirrors>' \
    '    <mirror>' \
    '      <id>aliyunmaven</id>' \
    '      <mirrorOf>*</mirrorOf>' \
    '      <name>阿里云公共仓库</name>' \
    '      <url>https://maven.aliyun.com/repository/public</url>' \
    '    </mirror>' \
    '  </mirrors>' \
    '</settings>' > /home/jenkins/.m2/settings.xml && \
    echo "Maven settings.xml configured with Aliyun mirror for user jenkins."

# 验证安装
RUN echo "Java version:" && java -version && \
    echo "javac version:" && javac -version && \
    echo "mvnd version:" && mvnd --version && \
    echo "docker version:" && docker --version && \
    echo "kubectl version:" &&  kubectl version --client && \
    echo "Default JAVA_HOME (from base image): ${JAVA_HOME}" && \
    echo "JDK8_HOME: ${JDK8_HOME}" && \
    echo "PATH: ${PATH}"