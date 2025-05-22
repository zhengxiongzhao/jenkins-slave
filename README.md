# Custom Jenkins Inbound Agent with Docker CLI, Buildx, and Pre-configured Caches/Mirrors

[![Publish Docker image to Docker Hub](https://github.com/zhengxiongzhao/jenkins-slave/actions/workflows/publish-docker-image.yml/badge.svg?event=push)](https://github.com/zhengxiongzhao/jenkins-slave/actions/workflows/publish-docker-image.yml)

This repository provides a `Dockerfile` to build a custom Jenkins inbound agent. The agent is based on the official `jenkins/inbound-agent:latest-jdk17` and comes pre-installed with:

*   **Docker CLI**: Version `28.1.1` (customizable via `DOCKER_CLI_VERSION` build argument).
*   **Docker Buildx**: Version `v0.14.0` (customizable via `BUILDX_VERSION` build argument).
*   **Common Build Tools**: Includes `wget`, `tar`, `zip`, `curl`, `bash`, `gnupg`, `expect`, etc.
*   **Pre-configured Caches**: Dedicated cache directories for NPM, Yarn, Go, and Maven to speed up builds.
*   **Pre-configured Mirrors**: NPM, Yarn, Go, and Maven are configured to use popular Chinese mirrors.

This setup is ideal for Jenkins jobs that require Docker build capabilities and benefit from pre-configured caches and mirrors for faster dependency resolution. The system's default Java is JDK 17 (from the base image).

## Features

*   Based on the official `jenkins/inbound-agent:latest-jdk17`.
*   Includes Docker CLI and Docker Buildx.
*   Includes a set of common command-line utilities.
*   Pre-configured cache directories for NPM (`/data/cache/npm`), Yarn (`/data/cache/yarn`), Go (`/data/cache/go`), and Maven (`/data/cache/mvn`).
*   NPM, Yarn, and Go are configured to use Chinese mirrors (`registry.npmmirror.com/` for NPM/Yarn, `goproxy.cn` for Go).
*   Maven `settings.xml` for the `jenkins` user is pre-configured with Aliyun mirror.
*   Automated builds and publishing to Docker Hub via GitHub Actions.

## Image Contents

*   **Base Image**: `jenkins/inbound-agent:latest-jdk17` (Provides default JDK 17, which is the system default `java` and `JAVA_HOME`).
*   **Docker CLI**: Version `28.1.1` (or as specified by `DOCKER_CLI_VERSION` build-arg) installed in `/usr/local/bin/docker`.
*   **Docker Buildx**: Version `v0.14.0` (or as specified by `BUILDX_VERSION` build-arg) installed in `/usr/local/lib/docker/cli-plugins/docker-buildx`.
*   **Common Utilities**: `wget`, `vim`, `tar`, `zip`, `gzip`, `grep`, `coreutils`, `ca-certificates`, `apt-transport-https`, `iputils-ping`, `telnet`, `netcat-openbsd`, `iproute2`, `curl`, `bash`, `gnupg`, `expect`, `lsb-release`, `software-properties-common`.
*   **Cache Directories**:
    *   NPM: `${CACHE_BASE_DIR}/npm` (defaults to `/data/cache/npm`)
    *   Yarn: `${CACHE_BASE_DIR}/yarn` (defaults to `/data/cache/yarn`)
    *   Go Mod: `${CACHE_BASE_DIR}/go/mod-cache` (defaults to `/data/cache/go/mod-cache`)
    *   Go Build: `${CACHE_BASE_DIR}/go/cache` (defaults to `/data/cache/go/cache`)
    *   Maven: `${CACHE_BASE_DIR}/mvn` (defaults to `/data/cache/mvn`)
*   **Mirror Configurations**:
    *   **NPM**: `~/.npmrc` configured for `registry.npmmirror.com/`.
    *   **Yarn**: `~/.yarnrc` and `~/.yarnrc.yml` configured for `registry.npmmirror.com/`.
    *   **Go**: `~/.config/go/env` configured for `goproxy.cn`.
    *   **Maven**: `~/.m2/settings.xml` configured to use Aliyun public repository as a mirror.
*   **User**: Runs as `jenkins` user (UID 1000). `jenkins` user is added to the `docker` group.

## Getting Started

### Prerequisites

*   Docker installed on your local machine.

## Quick Usage / Standalone Agent Setup

This section describes how to run the agent container directly using Docker CLI or Docker Compose, typically for manual connections or local Jenkins setups.

**Key Considerations for Standalone Usage:**
*   **Docker Socket**: To enable Docker commands within the agent (DooD - Docker-outside-of-Docker), mount the host's Docker socket: `-v /var/run/docker.sock:/var/run/docker.sock`.
*   **Persistent Caches**: To persist build caches (NPM, Yarn, Go, Maven), mount the `/data/cache` directory from the host: `-v /path/on/host/jenkins_cache:/data/cache`.
*   **Workspace**: Mount a directory for the agent's workspace: `-v /path/on/host/jenkins_agent_workspace:/home/jenkins/agent`.

### Option 1: Using Docker CLI for Manual Connection

You can manually connect this agent to your Jenkins master using `docker run`. This is useful for testing or specific setups where you don't use a Jenkins plugin to manage agent lifecycles.

First, create a new permanent agent node in Jenkins (Manage Jenkins -> Nodes and Clouds -> New Node). Set the Launch method to "Launch agent by connecting it to the master". Note the agent name and the secret provided by Jenkins.

Then, run the agent container:
```bash
docker run -d --name my-custom-agent \
  -e JENKINS_AGENT_NAME="<your-agent-name-in-jenkins>" \
  -e JENKINS_SECRET="<jenkins-provided-secret>" \
  -e JENKINS_JNLP_URL="<http://your-jenkins-master-url:port>/computer/<your-agent-name-in-jenkins>/slave-agent.jnlp" \
  -e JENKINS_AGENT_WORKDIR="/home/jenkins/agent/workspace" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /path/to/your/host/workspace:/home/jenkins/agent/workspace \
  -v /path/to/your/host/cache:/data/cache \
  zhengxiongzhao/jenkins-slave:latest
```
Replace placeholders like `<your-agent-name-in-jenkins>`, `<jenkins-provided-secret>`, and `<http://your-jenkins-master-url:port>` with your actual values. The `JENKINS_JNLP_URL` is often constructed this way. Adjust volume mounts as needed.
Make sure your Jenkins master's JNLP port (usually 50000) is accessible from the agent container.

### Option 2: Using Docker Compose for Jenkins Master & Agent

You can manage a local Jenkins master and this agent using Docker Compose. This is useful for local development or testing a complete Jenkins environment.

Here's an example `docker-compose.yml`:
```yaml
version: '3.8'
services:
  jenkins:
    image: jenkins/jenkins:lts-jdk17
    container_name: jenkins-master
    ports:
      - "8080:8080"
      - "50000:50000" # JNLP port
    volumes:
      - jenkins_home:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock # Allow Jenkins master to access Docker for Docker Plugin
    environment:
      - JENKINS_OPTS="--prefix=/jenkins" # Optional: if running Jenkins behind a reverse proxy with a path
      # For Docker Cloud configuration in Jenkins (if master launches other agents):
      - JENKINS_DOCKER_HOST=unix:///var/run/docker.sock

  # This agent service in Docker Compose is for a manually configured permanent agent.
  jenkins-agent:
    image: zhengxiongzhao/jenkins-slave:latest # Or your custom-built image tag
    container_name: custom-jenkins-agent-manual-compose
    # depends_on: [jenkins] # Ensures jenkins master starts first if this agent auto-connects
    # restart: unless-stopped
    environment:
      # For manual JNLP connection to the 'jenkins' service defined above:
      - JENKINS_AGENT_NAME=manual-compose-agent # Must match the node name in Jenkins
      - JENKINS_JNLP_URL=http://jenkins:8080/jenkins/computer/manual-compose-agent/slave-agent.jnlp # Assumes jenkins service name and prefix
      - JENKINS_SECRET=<secret_from_jenkins_node_config>
      - JENKINS_AGENT_WORKDIR=/home/jenkins/agent/workspace
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock # For DooD
      - ./agent_workspace_compose:/home/jenkins/agent/workspace # Example host path for workspace
      - ./agent_cache_compose:/data/cache # Example host path for cache
    # Note: For this agent to connect, you'd need to:
    # 1. Create a permanent node in Jenkins master named 'manual-compose-agent'.
    # 2. Set its launch method to "Launch agent by connecting it to the master".
    # 3. Copy the secret from Jenkins node configuration into JENKINS_SECRET above.
    # 4. Ensure network connectivity from this agent container to jenkins:50000 (JNLP port).

volumes:
  jenkins_home:
```

**To use this Docker Compose setup:**
1.  Save the content above as `docker-compose.yml`.
2.  Replace `<secret_from_jenkins_node_config>` with the actual secret from the Jenkins node configuration.
3.  Create necessary local directories for volumes if using host paths (e.g., `./agent_workspace_compose`, `./agent_cache_compose`).
4.  Run `docker-compose up -d`.
5.  Access Jenkins at `http://localhost:8080` (or with `/jenkins` prefix if configured).
6.  **For the `jenkins-agent` service (manual permanent agent):**
    *   In Jenkins: Manage Jenkins -> Nodes and Clouds -> New Node.
    *   Node name: `manual-compose-agent` (or as in `JENKINS_AGENT_NAME`).
    *   Select "Permanent Agent".
    *   Remote root directory: `/home/jenkins/agent`.
    *   Launch method: "Launch agent by connecting it to the master".
    *   After saving, view the agent's configuration to get the `secret` and update `JENKINS_SECRET` in `docker-compose.yml` if it was a placeholder.
    *   Restart the agent if you updated the secret: `docker-compose up -d --force-recreate jenkins-agent`.
7.  **Note**: The `jenkins` service in this Docker Compose setup can also be configured with the Docker Plugin (see next section) to dynamically launch other agents using this same `zhengxiongzhao/jenkins-slave:latest` image, separate from the manually defined `jenkins-agent` service.

## Usage with Jenkins Plugins

This section describes how to integrate the agent with Jenkins using common plugins, where Jenkins manages the agent's lifecycle.

**Key Considerations for Plugin-Managed Agents:**
*   **Docker Socket Access**: The Jenkins master (or the entity launching the agent, like a Kubernetes pod definition) needs access to the Docker daemon to start this agent container. This often means mounting `/var/run/docker.sock`.
*   **Persistent Caches**: Configure volume mounts for `/data/cache` in the plugin's agent template to persist caches.
*   **Docker Group ID (GID)**: The `jenkins` user in the image is part of a `docker` group. If using DooD, ensure the GID of the host's Docker socket matches the `docker` group GID inside the container (configurable via `DOCKER_HOST_GID` build-arg, defaults to `2375`) or manage permissions appropriately.

### Option 1: Jenkins Docker Plugin

*   Install the "Docker" plugin in Jenkins.
*   Go to `Manage Jenkins` -> `Nodes and Clouds` -> `Configure Clouds`.
*   Add a new Cloud of type "Docker".
*   Configure Docker Host URI (e.g., `unix:///var/run/docker.sock` if Jenkins master has direct access, or `tcp://<docker_host_ip>:2375` if remote).
*   Add a "Docker Agent Template":
    *   **Label**: e.g., `docker-build-agent` (use this label in your Jenkins jobs).
    *   **Docker Image**: `zhengxiongzhao/jenkins-slave:latest` (or your locally built tag).
    *   **Remote File System Root**: `/home/jenkins/agent`.
    *   **Connect method**: `Attach Docker container` or `Connect with JNLP`.
    *   **Docker Run Arguments (Example for Docker Socket & Cache)**:
        ```
        -v /var/run/docker.sock:/var/run/docker.sock
        -v /path/on/host/jenkins_plugin_cache:/data/cache
        ```
        Ensure `/path/on/host/jenkins_plugin_cache` directory exists and has appropriate permissions.

### Option 2: Jenkins Kubernetes Plugin

If your Jenkins master runs on Kubernetes, you can use the Kubernetes plugin to dynamically provision this agent as a pod.

*   Define a Pod Template in Jenkins configuration (Manage Jenkins -> Nodes and Clouds -> Configure Clouds -> Add new cloud -> Kubernetes):
    ```yaml
    apiVersion: v1
    kind: Pod
    spec:
      containers:
      - name: jnlp # The main JNLP container
        image: zhengxiongzhao/jenkins-slave:latest
        args: ['$(JENKINS_SECRET)', '$(JENKINS_NAME)']
        volumeMounts:
        - name: workspace-volume
          mountPath: /home/jenkins/agent # Jenkins agent root
        - name: app-cache # Consolidated cache volume
          mountPath: /data/cache
        - name: docker-sock # If running Docker-outside-of-Docker
          mountPath: /var/run/docker.sock
      volumes:
      - name: workspace-volume
        emptyDir: {} # Or a persistent volume claim
      - name: app-cache # Consolidated cache volume
        hostPath: # Example: using hostPath, consider persistentVolumeClaim for production
          path: /mnt/k8s_jenkins_cache # Ensure this path exists on K8s nodes
          type: DirectoryOrCreate
      - name: docker-sock # If running Docker-outside-of-Docker
        hostPath:
          path: /var/run/docker.sock
          type: Socket
    ```
    *   Set the **Label** for this Pod Template (e.g., `docker-build-k8s-agent`).
    *   Use this label in your Jenkins jobs.

## Automated Publishing with GitHub Actions

This repository is configured with a GitHub Actions workflow (`.github/workflows/publish-docker-image.yml`) that automatically:

1.  Builds the Docker image whenever changes are pushed to the `main` branch.
2.  Tags the image with the commit SHA and `latest` (for the default branch).
3.  Publishes the image to Docker Hub.

You can find the published images on Docker Hub at:
`https://hub.docker.com/r/zhengxiongzhao/jenkins-slave`

The image will be tagged as:
*   `zhengxiongzhao/jenkins-slave:latest` (for pushes to the default branch)
*   `zhengxiongzhao/jenkins-slave:<short_commit_sha>`

### Building the Image Locally

To build the Docker image locally if you prefer not to use the pre-built images from Docker Hub or want to customize it:

1.  Clone this repository:
    ```bash
    git clone https://github.com/zhengxiongzhao/jenkins-slave.git
    cd jenkins-slave
    ```
2.  Build the image:
    ```bash
    docker build -t custom-jenkins-agent:latest .
    ```
    You can also specify versions and cache locations during build using `ARG`s defined in the `Dockerfile`:
    ```bash
    docker build \
      --build-arg DOCKER_CLI_VERSION="28.1.1" \
      --build-arg BUILDX_VERSION="v0.14.0" \
      --build-arg CACHE_BASE_DIR_ARG="/custom/cache/path" \
      -t my-custom-jenkins-agent:custom .
    ```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request or open an Issue.
(Further details on contributing can be added here, e.g., coding standards, commit message conventions.)

## License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.
(You can choose a different license if you prefer. If so, create a `LICENSE` file with the chosen license text.)
