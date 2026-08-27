# DevOps Shift Engineer Technical Test - PT Simple Journey Indonesia

This repository contains a complete implementation of the Shift Engineer technical test, demonstrating containerized Go application deployment with Docker and Jenkins CI/CD automation.

## Overview

The project implements a simple Go HTTP server (`version=dev` by default) that:
- Serves a `/` endpoint returning `Hello, DevOps! version={VERSION}`
- Listens on port 8080
- Supports version injection at build time via Go `ldflags`
- Runs in a minimal scratch container (no dependencies)

---

## I. BUILD - Docker Multi-Stage Build

### Dockerfile Structure

The `Dockerfile` uses a multi-stage build approach:

1. **Builder Stage** (`golang:1.27-alpine`):
   - Produces a statically-linked binary with `CGO_ENABLED=0`
   - Version is injected via the `VERSION` build argument using `-ldflags="-X main.version=${VERSION}"`
   - Binary is stripped (`-s -w` flags) for minimal size
   - Trimpath removes absolute file paths for reproducibility

2. **Runtime Stage** (`scratch`):
   - Uses the `scratch` base image (empty container, 0 bytes base)
   - Only copies the compiled binary—no OS, libraries, or shell included
   - Minimal attack surface and maximum portability

### Why `scratch`?

- **Smallest possible image**: No OS overhead, no shell, no package managers
- **Security**: Minimal dependencies = minimal vulnerability surface
- **Performance**: Instant startup, minimal memory footprint
- **Portability**: Works on any Docker-capable system (Linux, Windows, macOS)

*Trade-off*: Cannot debug inside the container (no shell), but acceptable for production binaries. Alternative: `distroless` (slightly larger, adds debugging tools); or `alpine` (more utility, ~5MB base).

### Build Command

```bash
docker build \
  --build-arg VERSION=1.0.0 \
  -t devops-app:1.0.0 .
```

### Final Image Size

```
devops-app   1.0.0   4.2 MB
```

**Explanation**:
- Go statically-linked binary: ~3.5–4.0 MB
- No OS dependencies (scratch base)
- Stripped binary (`-s -w` flags): Removes debug symbols, saving ~1–2 MB
- Small delta for container metadata: ~0.2 MB

If using `alpine` instead, size would be ~12–15 MB; with `distroless`, ~6–8 MB.

---

## II. DEPLOY - Binary Swap Without Image Rebuild

### Quick Start: Run the Container

```bash
docker run -d \
  --name devops-app \
  --restart unless-stopped \
  -p 8080:8080 \
  devops-app:1.0.0
```

**Flags**:
- `--restart unless-stopped`: Auto-restart on crash (unless explicitly stopped)
- `-p 8080:8080`: Expose port 8080 on the host

### Scenario: Hot Fix Without Rebuild

**Problem**: A bug fix is ready, but rebuilding the entire Docker image is slow. How do we swap the binary without downtime?

**Chosen Approach: `docker cp` + Restart**

1. **Build the new binary on the host/CI** (fast):
   ```bash
   VERSION=1.0.1
   CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
   go build \
     -trimpath \
     -ldflags="-s -w -X main.version=${VERSION}" \
     -o app-hotfix .
   ```

2. **Copy the binary into the running container**:
   ```bash
   docker cp app-hotfix devops-app:/app/app
   ```

3. **Restart the container** to apply the new binary:
   ```bash
   docker restart devops-app
   ```

### Why This Approach?

- **Speed**: No full Docker image rebuild (saves 30–60 seconds)
- **Minimal Downtime**: `docker restart` is fast (~1–2 seconds)
- **No Image Rebuild**: Reuses the existing image, reducing CI/CD load
- **Production-Ready**: Used by major platforms (Kubernetes rolling restarts work similarly)

### Alternative Approaches Considered

| Approach | Pros | Cons |
|----------|------|------|
| **`docker cp` + restart** (chosen) | Fast, simple, no rebuild | Requires running container access |
| **Volume Mount** | Binary swaps instantly (no restart needed) | Adds volume management overhead; requires mount path upfront |
| **Sidecar/Init Container** | Elegant for Kubernetes | Overkill for single-container deployment; adds latency |

### Proof of Concept: Before and After

**Before swap** (version 1.0.0):
```bash
$ curl http://localhost:8080
Hello, DevOps! version=1.0.0
```

**After swap** (version 1.0.1):
```bash
$ curl http://localhost:8080
Hello, DevOps! version=1.0.1
```

**Downtime**: ~2 seconds (container restart time)  
**Rebuild Time**: 0 seconds (no image rebuild)  
**Evidence**: See `evidence/curl-before.txt` and `evidence/curl-after.txt`

---

## III. CI/CD with Jenkins

### Jenkinsfile Pipeline Stages

The `Jenkinsfile` implements a complete CI/CD pipeline with 7 stages:

#### 1. **Checkout**
```groovy
checkout scm
```
Pulls source code from the repository.

#### 2. **Test**
```groovy
sh 'go test ./...'
```
Runs all Go tests. **Pipeline fails if tests fail** (no build/deploy proceeds).

#### 3. **Build Binary**
Builds a statically-linked binary on the CI server:
```groovy
env.VERSION = sh(
    script: 'git rev-parse --short HEAD',
    returnStdout: true
).trim()
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
go build \
  -trimpath \
  -ldflags="-s -w -X main.version=${VERSION}" \
  -o app-hotfix .
```
Version is set to the short Git commit hash for traceability.

#### 4. **Build Image**
Builds the Docker image with the version tag:
```groovy
docker build \
  --build-arg VERSION=${VERSION} \
  -t devops-app:${VERSION} .
```

#### 5. **Push** (Optional)
Simulates pushing to a registry (no actual registry configured):
```groovy
echo 'Push stage simulated because no registry is configured.'
```
In production, this would use Jenkins credentials to securely push to Docker Hub, ECR, or GCR.

#### 6. **Deploy**
Automatically swaps the binary in the running container:
```groovy
docker cp app-hotfix ${APP_CONTAINER}:/app/app
docker restart ${APP_CONTAINER}
```

#### 7. **Verify**
Confirms the new version is running:
```groovy
sleep 2
curl -f http://host.docker.internal:8080
```

### Rollback Strategy

If the **Deploy** stage fails midway:

1. **Before `docker cp`**: No changes applied; container still runs old version → no action needed
2. **After `docker cp` but before `restart`**: New binary is in container but not active → restart with old binary first:
   ```bash
   docker cp app-hotfix-backup ${APP_CONTAINER}:/app/app  # restore old binary
   docker restart ${APP_CONTAINER}
   ```
3. **After successful `restart`**: Verify with curl; if health checks fail, manually restart:
   ```bash
   docker restart ${APP_CONTAINER}
   ```

**Key Design**: The `docker cp` + `restart` approach is atomic enough for CI/CD—if Jenkins fails, we simply re-run the Deploy stage with the last good binary. The pipeline logs capture exactly which version was deployed when.

### Security: Jenkins Credentials

No hardcoded secrets in the Jenkinsfile. In production:
- **Registry password**: Stored in Jenkins Credentials → bound to `$DOCKER_REGISTRY_PASSWORD`
- **SSH keys**: Stored in Jenkins Credentials → used for target host deployment
- **Example**:
  ```groovy
  withCredentials([usernamePassword(credentialsId: 'docker-hub', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
      sh 'docker login -u $DOCKER_USER -p $DOCKER_PASS'
  }
  ```

### Successful Pipeline Run

See `evidence/` folder for screenshots and logs:
- `01-build-image.png`: Docker image built successfully
- `02-deploy-before.png`: Container running with old version
- `03-deploy-after.png`: Container running with new version (post-swap)
- `curl-before.txt`: Response before binary swap
- `curl-after.txt`: Response after binary swap

---

## Project Structure

```
.
├── main.go                # Go HTTP server (version injectable)
├── main_test.go           # Unit tests (2 tests)
├── Dockerfile             # Multi-stage Docker build
├── Dockerfile.jenkins     # (Optional) Alternative Jenkins-specific Dockerfile
├── Jenkinsfile            # CI/CD pipeline definition
├── go.mod                 # Go module file
├── plugins.txt            # (Optional) Jenkins plugin list
├── .dockerignore           # Files excluded from Docker build
├── .gitignore             # Git ignore patterns
├── evidence/              # Screenshots and logs of successful runs
│   ├── 01-build-image.png
│   ├── 02-deploy-before.png
│   ├── 03-deploy-after.png
│   ├── curl-before.txt
│   └── curl-after.txt
└── README.md              # This file
```

---

## How to Run Locally

### Prerequisites
- Docker 20.10+
- Go 1.20+ (for local testing)
- curl (for verification)

### 1. Build the Docker Image

```bash
docker build --build-arg VERSION=1.0.0 -t devops-app:1.0.0 .
```

### 2. Run the Container

```bash
docker run -d \
  --name devops-app \
  --restart unless-stopped \
  -p 8080:8080 \
  devops-app:1.0.0
```

### 3. Verify It's Running

```bash
curl http://localhost:8080
# Output: Hello, DevOps! version=1.0.0
```

### 4. Test the Hot-Fix Scenario

Build a new binary:
```bash
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
go build \
  -trimpath \
  -ldflags="-s -w -X main.version=1.0.1" \
  -o app-hotfix .
```

Swap the binary:
```bash
docker cp app-hotfix devops-app:/app/app
docker restart devops-app
```

Verify the new version:
```bash
curl http://localhost:8080
# Output: Hello, DevOps! version=1.0.1
```

### 5. Run Tests

```bash
go test ./...
# Expected output: ok   devops-app  0.001s
```

---

## How to Run with Jenkins

### Prerequisites
- Jenkins 2.350+ with Docker plugin
- Docker daemon accessible to Jenkins agent
- Git plugin configured

### 1. Create a Jenkins Pipeline Job

1. New Item → Pipeline
2. Configure → Pipeline → Pipeline script from SCM
3. Select Git → Enter repository URL
4. Script Path: `Jenkinsfile`

### 2. Run the Pipeline

Click **Build Now** → Jenkins executes all 7 stages:
- Checkout → Test → Build Binary → Build Image → Push → Deploy → Verify

### 3. View Results

- **Blue Ocean**: Visual pipeline execution
- **Console Output**: Detailed logs
- **Evidence**: Check `evidence/` for screenshots

---

## Summary

✅ **Part I (Build)**: Multi-stage Dockerfile with version injection and scratch base image  
✅ **Part II (Deploy)**: Binary swap mechanism proven with curl before/after  
✅ **Part III (CI/CD)**: Full Jenkins pipeline with tests, build, deploy, and verification  
✅ **Security**: No hardcoded secrets; credentials bound via Jenkins  
✅ **Rollback**: Clear strategy for handling mid-deploy failures  
✅ **Documentation**: This README + evidence folder  

---

## Contact

**Repository Owner**: dedypurnama712  
**Test Organization**: PT Simple Journey Indonesia  
**Admin Email**: admin@simplejourney.co.id  

---

*Last Updated: 2026-08-27*
