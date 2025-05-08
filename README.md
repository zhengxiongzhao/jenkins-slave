# Custom Jenkins Inbound Agent with JDK 8, mvnd, Docker CE, and kubectl

[![Publish Docker image to Docker Hub](https://github.com/zhengxiongzhao/jenkins-slave/actions/workflows/publish-docker-image.yml/badge.svg?event=push)](https://github.com/zhengxiongzhao/jenkins-slave/actions/workflows/publish-docker-image.yml)

This repository provides a `Dockerfile` to build a custom Jenkins inbound agent. The agent is based on the official `jenkins/inbound-agent` and comes pre-installed with:

*   **Adoptium Temurin JDK 8u452-b09** (OpenJDK 8), available via `JDK8_HOME` environment variable.
*   **Apache Maven Daemon (mvnd) 1.0.2**, available in `PATH`.
*   **Docker CE (Community Edition)** client and engine.
*   **kubectl v1.18.20** (Kubernetes command-line tool).

This setup is ideal for Jenkins jobs that require a specific Java 8 version, faster Maven builds with mvnd, and the ability to interact with Docker or Kubernetes.
The system's default Java remains JDK 17 (from the base image).

## Features

*   Based on the official `jenkins/inbound-agent`.
*   Includes specific versions of Adoptium JDK 8 (via `JDK8_HOME`) and mvnd (in `PATH`).
*   Includes Docker CE and a specific version of kubectl.
*   Maven `settings.xml` for the `jenkins` user is pre-configured with Aliyun mirror.
*   Automated builds and publishing to Docker Hub via GitHub Actions.

## Image Contents

*   **Base Image**: `jenkins/inbound-agent:latest-jdk17` (Provides default JDK 17, which remains the system default `java` and `JAVA_HOME`).
*   **Adoptium Temurin JDK 8**: Version `8u452-b09` installed in `/opt/jdk-1.8`.
    *   Accessible via the `JDK8_HOME` environment variable (e.g., `${JDK8_HOME}/bin/java`).
    *   **Not** the system default Java.
*   **Apache Maven Daemon (mvnd)**: Version `1.0.2` installed in `/opt/mvnd`.
    *   `mvnd` command is available in the `PATH`.
*   **Docker CE**: Docker client and engine are installed.
*   **kubectl**: Version `v1.18.20` (from `KUBECTL_VERSION` ARG) installed to `/usr/local/bin/kubectl`.
*   **Maven Configuration**: The `jenkins` user's `settings.xml` (`/home/jenkins/.m2/settings.xml`) is configured to use Aliyun public repository as a mirror for all requests.

## Getting Started

### Prerequisites

*   Docker installed on your local machine.

### Local Build

To build the Docker image locally:

1.  Clone this repository:
    ```bash
    git clone https://github.com/<YOUR_USERNAME>/jenkins-slave.git
    cd jenkins-slave
    ```
2.  Build the image:
    ```bash
    docker build -t custom-jenkins-agent:latest .
    ```
    You can also specify the versions during build if needed (though they are ARG in Dockerfile):
    ```bash
    docker build \
      --build-arg JDK_VERSION=8u452-b09 \
      --build-arg MVND_VERSION=1.0.2 \
      # --build-arg KUBECTL_VERSION=v1.18.20 # Example if you need to override kubectl version
      -t custom-jenkins-agent:custom .
    ```

### Using with Jenkins

You can configure this image as a Jenkins agent in a few ways.

**General Notes for Usage:**

*   **JDK 8**: If your build process needs JDK 8 specifically, you'll need to ensure your scripts or Jenkins tool configurations point to `${JDK8_HOME}` (e.g., by setting `JAVA_HOME=${JDK8_HOME}` within your pipeline script or job).
*   **Docker CE**: If you intend to run Docker commands (e.g., `docker build`, `docker run`) from within this agent, you will likely need to mount the Docker socket from the host machine (e.g., by adding `-v /var/run/docker.sock:/var/run/docker.sock` to the Docker run arguments if using Docker-outside-of-Docker, or ensure appropriate setup for Docker-in-Docker if that's your approach).
*   **kubectl**: To use `kubectl` to interact with a Kubernetes cluster, the agent will need access to a valid `kubeconfig` file. This is typically managed via Jenkins credentials and loaded dynamically in your pipeline.
*   **Maven `settings.xml`**: The `jenkins` user is pre-configured to use Aliyun's Maven mirror.

**1. Docker Plugin in Jenkins:**

*   Install the "Docker" plugin in Jenkins.
*   Go to `Manage Jenkins` -> `Nodes and Clouds` -> `Configure Clouds`.
*   Add a new Cloud of type "Docker".
*   Configure Docker Host URI.
*   Add a "Docker Agent Template":
    *   **Label**: e.g., `jdk8-mvnd-docker-agent` (use this label in your Jenkins jobs)
    *   **Docker Image**: `zhengxiongzhao/jenkins-slave:latest` (or your locally built tag if not using Docker Hub)
    *   **Remote File System Root**: `/home/jenkins/agent`
    *   **Connect method**: `Attach Docker container` or `Connect with JNLP`
    *   **Docker Run Arguments (Example for Docker Socket)**: If needed, add `-v /var/run/docker.sock:/var/run/docker.sock` to allow the agent to use the host's Docker daemon.

**2. Kubernetes Plugin (if Jenkins runs on Kubernetes):**

*   Define a Pod Template in Jenkins configuration:
    ```yaml
    apiVersion: v1
    kind: Pod
    spec:
      containers:
      - name: jnlp # The main JNLP container
        image: zhengxiongzhao/jenkins-slave:latest
        args: ['$(JENKINS_SECRET)', '$(JENKINS_NAME)']
        # Example of setting JAVA_HOME to JDK8 for this container if needed for JNLP or build steps
        # env:
        # - name: JAVA_HOME
        #   value: /opt/jdk-1.8
        # You might need to configure volume mounts for workspace, Maven cache, kubeconfig, docker socket etc.
        # volumeMounts:
        # - name: workspace-volume
        #   mountPath: /home/jenkins/agent/workspace
        # - name: m2-cache # For Maven local repository
        #   mountPath: /home/jenkins/.m2/repository
        # - name: docker-sock # If running Docker-outside-of-Docker
        #   mountPath: /var/run/docker.sock
      # volumes:
      # - name: workspace-volume
      #   emptyDir: {}
      # - name: m2-cache
      #   emptyDir: {} # Or a persistent volume
      # - name: docker-sock # If running Docker-outside-of-Docker
      #   hostPath:
      #     path: /var/run/docker.sock
      #     type: Socket
    ```
    *   Set the **Label** for this Pod Template (e.g., `jdk8-mvnd-k8s-agent`).
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

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request or open an Issue.
(Further details on contributing can be added here, e.g., coding standards, commit message conventions.)

## License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.
(You can choose a different license if you prefer. If so, create a `LICENSE` file with the chosen license text.)

