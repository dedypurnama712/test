pipeline {
    agent any

    environment {
        IMAGE_NAME = 'devops-app'
        APP_CONTAINER = 'devops-app'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Test') {
            steps {
                echo 'Running Go tests...'
                sh 'go test ./...'
            }
        }

        stage('Build Binary') {
            steps {
                script {
                    env.VERSION = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()

                    echo "Building application version: ${env.VERSION}"

                    sh """
                        CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
                        go build \
                        -trimpath \
                        -ldflags="-s -w -X main.version=${VERSION}" \
                        -o app-hotfix .
                    """
                }
            }
        }

        stage('Build Image') {
            steps {
                sh """
                    docker build \
                    --build-arg VERSION=${VERSION} \
                    -t ${IMAGE_NAME}:${VERSION} .
                """
            }
        }

        stage('Push') {
            steps {
                echo 'No container registry configured.'
                echo 'Push stage simulated as permitted by the technical test.'
                echo "Image ready: ${IMAGE_NAME}:${VERSION}"
            }
        }

        stage('Deploy') {
            steps {
                echo 'Deploying binary without rebuilding container image...'

                sh '''
                    chmod +x deploy.sh
                    ./deploy.sh
                '''
            }
        }

        stage('Verify') {
            steps {
                sh '''
                    sleep 2
                    curl -f http://host.docker.internal:8080/health
                '''
            }
        }
    }

    post {
        success {
            echo 'PIPELINE SUCCESS'
            echo 'All stages completed successfully.'
        }

        failure {
            echo 'PIPELINE FAILED'
            echo 'Build/Test/Deploy failed.'
        }

        always {
            echo "Build version: ${env.VERSION ?: 'N/A'}"
        }
    }
}
