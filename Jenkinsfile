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
                echo 'Push stage simulated because no registry is configured.'
            }
        }

        stage('Deploy') {
            steps {
                sh """
                    docker cp app-hotfix ${APP_CONTAINER}:/app/app
                    docker restart ${APP_CONTAINER}
                """
            }
        }

        stage('Verify') {
            steps {
                sh 'sleep 2'
                sh 'curl -f http://host.docker.internal:8080'
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully.'
        }

        failure {
            echo 'Pipeline FAILED.'
        }
    }
}