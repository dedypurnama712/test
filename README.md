DevOps Technical Test

Go application demonstrating application versioning, Docker containerization,
zero-image-rebuild binary deployment, rollback, and Jenkins CI/CD.

1. Application Overview

This project is a simple Go HTTP application.

The application exposes:

- `/` - application response and version
- `/health` - health check endpoint

Example response:

    Hello, DevOps! version=1.0.1

Application version is injected during build using Go `-ldflags`.

Part I - Application and Docker

Version Injection

The application defines:

    var version = "dev"

The version can be injected during compilation:

    go build -ldflags="-X main.version=1.0.1" -o app .

For Jenkins builds, the Git commit hash is used:

    git rev-parse --short HEAD

Example:

    460bd1a

The resulting application reports:

    Hello, DevOps! version=460bd1a

Build the Application

Run:

    go test ./...

Build a Linux binary:

    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build \
    -trimpath \
    -ldflags="-s -w -X main.version=1.0.1" \
    -o app .

Build Docker Image

Run:

    docker build --build-arg VERSION=1.0.1 -t devops-app:1.0.1 .

Run the container:

    docker run -d \
      --name devops-app \
      -p 8080:8080 \
      devops-app:1.0.1

Verify:

    curl http://localhost:8080/

    curl http://localhost:8080/health

Part II - Replace Binary Without Rebuilding the Image

The deployment mechanism replaces the running application binary inside
the existing container without rebuilding the Docker image.

The deployment script is:

    deploy.sh

The process is:

1. Check that the target container exists.
2. Back up the currently running binary.
3. Copy the new binary into `/app/app`.
4. Restart the container.
5. Perform a health check.
6. If the health check succeeds, deployment is successful.
7. If deployment fails, restore the previous binary.
8. Restart the container.
9. Perform another health check to verify rollback.

Deploy Manually

Build the deployment binary:

    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build \
    -trimpath \
    -ldflags="-s -w -X main.version=1.0.1" \
    -o app-hotfix .

Make the script executable:

    chmod +x deploy.sh

Run:

    ./deploy.sh

Rollback

Before replacing the binary, the existing `/app/app` binary is backed up.

If the new binary fails the health check, the backup is restored:

    docker cp "$BACKUP_PATH" "$CONTAINER_NAME:$BINARY_PATH"

The container is then restarted and the health endpoint is checked again.

If rollback succeeds, the previous working binary remains active.

Part III - CI/CD with Jenkins

The Jenkins pipeline is defined in:

    Jenkinsfile

The pipeline contains the following stages:

1. Checkout
2. Test
3. Build Binary
4. Build Image
5. Push
6. Deploy
7. Verify

Checkout

Jenkins checks out the source code from:

    https://github.com/dedypurnama712/test.git

The pipeline uses the `main` branch.

Test

The pipeline runs:

    go test ./...

If the tests fail, Jenkins stops the pipeline and does not continue to
Build Image or Deploy stages.

Build Binary

The pipeline obtains the Git commit hash:

    git rev-parse --short HEAD

The hash is injected into the application using:

    -ldflags="-X main.version=${VERSION}"

The resulting binary is:

    app-hotfix

Build Image

The Docker image is tagged using the Git commit hash:

    devops-app:<commit-hash>

Example:

    devops-app:460bd1a

The Docker build receives the same version through:

    --build-arg VERSION=${VERSION}

Push

No external container registry is configured for this technical test.

Therefore, the Push stage is simulated and documents that a Docker registry
credential would be used if a registry were available.

No registry password or secret is hardcoded in the Jenkinsfile.

Deploy

The Deploy stage automatically executes:

    ./deploy.sh

The deployment uses the existing `devops-app` container and replaces the
application binary without rebuilding the running container image.

Jenkins has Docker access through the Jenkins Docker environment.

Verify

After deployment Jenkins performs:

    curl -f http://host.docker.internal:8080/health

A non-zero response causes the pipeline to fail.

Jenkins Credentials

Secrets must not be hardcoded in the Jenkinsfile.

Jenkins Credentials Binding is used for deployment/registry credentials
where credentials are required.

Credential values are stored in Jenkins and injected into the pipeline
only at runtime.

Pipeline Failure Handling

The pipeline uses sequential stages.

The Test stage runs:

    go test ./...

If the command exits with a non-zero status, Jenkins marks the build as
failed and subsequent Build Image and Deploy stages are not executed.

The Deploy stage also returns a non-zero exit code when deployment fails
or when rollback is triggered.

Rollback Strategy

The deployment process protects the currently running version before
replacing it.

Deployment flow:

    Current Binary
         |
         v
      Backup
         |
         v
    New Binary
         |
         v
      Restart
         |
         v
    Health Check
       /     \
     OK       FAIL
     |          |
     v          v
  Success    Restore Backup
                 |
                 v
              Restart
                 |
                 v
           Health Check
              /    \
            OK      FAIL
            |         |
            v         v
       Rollback OK  Critical Failure

This allows the application to return to the previous working binary
without rebuilding the Docker image.

Evidence

Successful Jenkins pipeline evidence includes all required stages:

- Checkout
- Test
- Build Binary
- Build Image
- Push
- Deploy
- Verify

A successful pipeline run should show all stages as green.

Evidence screenshots are stored in:

    evidence/

Files

| File | Description |
|------|-------------|
| `main.go` | Go application |
| `main_test.go` | Go unit tests |
| `Dockerfile` | Multi-stage Docker build |
| `Dockerfile.jenkins` | Jenkins build environment |
| `Jenkinsfile` | Jenkins CI/CD pipeline |
| `deploy.sh` | Binary deployment and rollback script |
| `go.mod` | Go module definition |
| `README.md` | Project documentation |

Quick Start

Run tests:

    go test ./...

Build Docker image:

    docker build --build-arg VERSION=1.0.1 -t devops-app:1.0.1 .

Run:

    docker run -d --name devops-app -p 8080:8080 devops-app:1.0.1

Verify:

    curl http://localhost:8080/

    curl http://localhost:8080/health

Deploy a new binary:

    chmod +x deploy.sh
    ./deploy.sh

Technical Test Result

The project demonstrates:

- Go application versioning using `ldflags`
- Docker multi-stage build
- Automated Go testing
- Docker image versioning using Git commit hash
- Jenkins CI/CD
- Binary replacement without image rebuild
- Health-check based deployment validation
- Automatic rollback
- Jenkins credentials handling
- End-to-end pipeline verification