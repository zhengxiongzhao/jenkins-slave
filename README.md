# Custom Jenkins Inbound Agent with JDK 8 and mvnd

[![Publish Docker image to Docker Hub](https://github.com/<YOUR_USERNAME>/<YOUR_REPOSITORY_NAME>/actions/workflows/publish-docker-image.yml/badge.svg?event=push)](https://github.com/<YOUR_USERNAME>/<YOUR_REPOSITORY_NAME>/actions/workflows/publish-docker-image.yml)

This repository provides a `Dockerfile` to build a custom Jenkins inbound agent. The agent is based on the official `jenkins/inbound-agent` and includes:

*   **Adoptium Temurin JDK 8u412-b08** (OpenJDK 8)
*   **Apache Maven Daemon (mvnd) 1.0.2**

This setup is ideal for Jenkins jobs that require Java 8 and can benefit from the faster build times provided by mvnd.

## Features

*   Based on the official `jenkins/inbound-agent`.
*   Includes specific versions of Adoptium JDK 8 and mvnd.
*   Automated builds and publishing to Docker Hub via GitHub Actions.

## Image Contents

*   **Base Image**: `jenkins/inbound-agent:latest-jdk17` (Note: JDK 17 from base is not the default, JDK 8 is installed and set as default)
*   **Java Development Kit**: Adoptium Temurin JDK `8u412-b08` (Set as default `java` and `javac`)
    *   `JAVA_HOME` is set to `/opt/java/openjdk`
*   **Maven Daemon**: mvnd `1.0.2`
    *   `mvnd` is available in the `PATH`

## Getting Started

### Prerequisites

*   Docker installed on your local machine.

### Local Build

To build the Docker image locally:

1.  Clone this repository:
    ```bash
    git clone https://github.com/<YOUR_USERNAME>/<YOUR_REPOSITORY_NAME>.git
    cd <YOUR_REPOSITORY_NAME>
    ```
2.  Build the image:
    ```bash
    docker build -t custom-jenkins-agent:latest .
    ```
    You can also specify the versions during build if needed (though they are ARG in Dockerfile):
    ```bash
    docker build \
      --build-arg JDK_VERSION=8u412-b08 \
      --build-arg MVND_VERSION=1.0.2 \
      -t custom-jenkins-agent:custom .
    ```

### Using with Jenkins

You can configure this image as a Jenkins agent in a few ways:

**1. Docker Plugin in Jenkins:**

*   Install the "Docker" plugin in Jenkins.
*   Go to `Manage Jenkins` -> `Nodes and Clouds` -> `Configure Clouds`.
*   Add a new Cloud of type "Docker".
*   Configure Docker Host URI.
*   Add a "Docker Agent Template":
    *   **Label**: e.g., `jdk8-mvnd-agent` (use this label in your Jenkins jobs)
    *   **Docker Image**: `<YOUR_DOCKERHUB_USERNAME>/<YOUR_REPOSITORY_NAME>:latest` (or your locally built tag if not using Docker Hub)
    *   **Remote File System Root**: `/home/jenkins/agent`
    *   **Connect method**: `Attach Docker container` or `Connect with JNLP`

**2. Kubernetes Plugin (if Jenkins runs on Kubernetes):**

*   Define a Pod Template in Jenkins configuration:
    ```yaml
    apiVersion: v1
    kind: Pod
    spec:
      containers:
      - name: jnlp
        image: <YOUR_DOCKERHUB_USERNAME>/<YOUR_REPOSITORY_NAME>:latest
        args: ['$(JENKINS_SECRET)', '$(JENKINS_NAME)']
        # You might need to configure volume mounts for workspace, Maven cache, etc.
        # volumeMounts:
        # - name: workspace-volume
        #   mountPath: /home/jenkins/agent/workspace
        # - name: m2-cache
        #   mountPath: /home/jenkins/.m2
      # volumes:
      # - name: workspace-volume
      #   emptyDir: {}
      # - name: m2-cache
      #   emptyDir: {} # Or a persistent volume
    ```
    *   Set the **Label** for this Pod Template (e.g., `jdk8-mvnd-k8s-agent`).
    *   Use this label in your Jenkins jobs.

## Automated Publishing with GitHub Actions

This repository is configured with a GitHub Actions workflow (`.github/workflows/publish-docker-image.yml`) that automatically:

1.  Builds the Docker image whenever changes are pushed to the `main` branch.
2.  Tags the image with the commit SHA and `latest` (for the default branch).
3.  Publishes the image to Docker Hub.

You can find the published images on Docker Hub at:
`https://hub.docker.com/r/<YOUR_DOCKERHUB_USERNAME>/<YOUR_REPOSITORY_NAME>`

The image will be tagged as:
*   `<YOUR_DOCKERHUB_USERNAME>/<YOUR_REPOSITORY_NAME>:latest` (for pushes to the default branch)
*   `<YOUR_DOCKERHUB_USERNAME>/<YOUR_REPOSITORY_NAME>:<short_commit_sha>`

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request or open an Issue.
(Further details on contributing can be added here, e.g., coding standards, commit message conventions.)

## License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.
(You can choose a different license if you prefer. If so, create a `LICENSE` file with the chosen license text.)

---

**Note**: Replace `<YOUR_USERNAME>`, `<YOUR_REPOSITORY_NAME>`, and `<YOUR_DOCKERHUB_USERNAME>` with your actual GitHub and Docker Hub information in the URLs and image paths above.