# 使用官方的 Jenkins inbound agent 作为基础镜像
FROM jenkins/inbound-agent:latest-jdk17 AS base

ARG JENKINS_HOME=/home/jenkins

# 定义配置文件路径变量
ARG CACHE_BASE_DIR_ARG=/data/cache
ENV CACHE_BASE_DIR=${CACHE_BASE_DIR_ARG}
ARG SSH_DIR=${JENKINS_HOME}/.ssh
ARG NPM_CACHE_DIR=${CACHE_BASE_DIR}/npm
ARG YARN_CACHE_DIR=${CACHE_BASE_DIR}/yarn
ARG GO_MOD_CACHE_DIR=${CACHE_BASE_DIR}/go/mod-cache
ARG GO_CACHE_DIR=${CACHE_BASE_DIR}/go/cache
ARG MVN_CACHE_DIR=${CACHE_BASE_DIR}/mvn

# 切换到 root 用户以安装软件
USER root

# RUN sed -i -e 's/deb.debian.org/mirrors.tencent.com/g' /etc/apt/sources.list.d/debian.sources

# 安装必要的工具 (wget, tar, etc.)
# This layer installs tools required for downloading and extracting JDK and mvnd.
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    vim \
    tar \
    zip \
    gzip grep coreutils \
    ca-certificates \
    apt-transport-https \
    iputils-ping telnet netcat-openbsd iproute2 \
    curl \
    bash \
    gnupg \
    expect \
    lsb-release \
    software-properties-common

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
    chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx

# stat -c '%g' /var/run/docker.sock
ARG DOCKER_HOST_GID=2375
RUN groupadd -g ${DOCKER_HOST_GID} docker || true # 如果组已存在则忽略错误

# Add jenkins user to docker group for DinD
RUN usermod -aG docker jenkins

RUN /bin/bash -c "mkdir -p ${CACHE_BASE_DIR}/{docker,npm,yarn,go,mvn}"
RUN /bin/bash -c "mkdir -p ${CACHE_BASE_DIR}/go/{mod-cache,cache}"
RUN chown -R 1000:1000 ${CACHE_BASE_DIR}

# 切换回 jenkins 用户
USER jenkins

# COPY --chown=jenkins:jenkins .ssh/ ${SSH_DIR}/
# RUN chmod 700 ${SSH_DIR} && \
#     chmod 600 ${SSH_DIR}/id_rsa

RUN mkdir .docker .yarn .npm 

# Config NPM env configured with cn mirror for user jenkins.
RUN printf '%s\n' \
    'registry=https://registry.npmmirror.com/'\
    'strict-ssl=false' \
    "cache=${NPM_CACHE_DIR}" \
    > ${JENKINS_HOME}/.npmrc

# Config YARN env configured with cn mirror for user jenkins.
RUN printf '%s\n' \
    'registry "https://registry.npmmirror.com/"'\
    'strict-ssl false' \
    "cache-folder \"${YARN_CACHE_DIR}\"" \
    > ${JENKINS_HOME}/.yarnrc 

# Config YARN 2.0 env configured with cn mirror for user jenkins.
RUN printf '%s\n' \
    'npmRegistryServer: "https://registry.npmmirror.com/"'\
    'strictSsl: false' \
    "cache-folder: \"${YARN_CACHE_DIR}\"" \
    > ${JENKINS_HOME}/.yarnrc.yml

# Config Go env configured with cn mirror for user jenkins.
RUN mkdir -p .config/go/ && \
    printf '%s\n' \
    'GO111MODULE=on'\
    'GOPROXY=https://goproxy.cn' \
    "GOMODCACHE=${GO_MOD_CACHE_DIR}" \
    "GOCACHE=${GO_CACHE_DIR}" \
    > ${JENKINS_HOME}/.config/go/env && \
    echo "Go env configured with cn mirror for user jenkins."

# Configure Maven settings.xml for Aliyun mirror for the jenkins user
RUN mkdir -p ${JENKINS_HOME}/.m2 && \
    printf '%s\n' \
    '<settings xmlns="http://maven.apache.org/SETTINGS/1.2.0"' \
    '          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"' \
    '          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.2.0 https://maven.apache.org/xsd/settings-1.2.0.xsd">' \
    "  <localRepository>${MVN_CACHE_DIR}</localRepository>" \
    '  <mirrors>' \
    '    <mirror>' \
    '      <id>aliyunmaven</id>' \
    '      <mirrorOf>*</mirrorOf>' \
    '      <name>阿里云公共仓库</name>' \
    '      <url>https://maven.aliyun.com/repository/public</url>' \
    '    </mirror>' \
    '  </mirrors>' \
    '</settings>' > ${JENKINS_HOME}/.m2/settings.xml && \
    echo "Maven settings.xml configured with Aliyun mirror for user jenkins."

RUN echo "docker version:" && docker --version && \
    echo "Default JAVA_HOME (from base image): ${JAVA_HOME}" && \
    echo "PATH: ${PATH}"
