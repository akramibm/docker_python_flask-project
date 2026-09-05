node {
    def imageName     = 'flask-app'
    def containerName = 'flask-app-service'
    def hostPort      = '5000'
    def containerPort = '5000'
    def gitCredsId    = 'token123'
    def repoUrl       = 'https://github.com/akramibm/docker_python_flask-project.git'

    
    try {
        stage('Ensure Docker Running') {
            echo 'Verifying Docker daemon connectivity...'
            sh '''
                docker info > /dev/null 2>&1 || {
                    echo "Docker daemon unreachable. Attempting socket permission adjustment..."
                    sudo chmod 666 /var/run/docker.sock || true
                    docker info > /dev/null 2>&1 || {
                        echo "ERROR: Cannot talk to Docker daemon."
                        exit 1
                    }
                }
            '''
        }

        stage('Checkout Code') {
            echo "Checking out Flask repository using credentials: ${gitCredsId}..."
            git branch: 'main',
                credentialsId: gitCredsId,
                url: repoUrl
        }

        stage('Build Docker Image') {
            echo 'Building Docker container image...'
            sh "docker build -t ${imageName}:${BUILD_NUMBER} -t ${imageName}:latest ."
        }

        stage('Run App in Background') {
            echo 'Starting container in background (-d)...'
            sh """
                if [ \$(docker ps -aq -f name=^/${containerName}\$) ]; then
                    echo "Cleaning up older container ${containerName}..."
                    docker stop ${containerName} || true
                    docker rm -f ${containerName} || true
                fi

                docker run -d \\
                    --name ${containerName} \\
                    -p ${hostPort}:${containerPort} \\
                    --restart unless-stopped \\
                    ${imageName}:latest

                docker ps -f name=^/${containerName}\$
            """
        }

        stage('Health Check') {
            echo 'Verifying background application responsiveness...'
            sh """
                sleep 5
                curl -I -s --retry 5 --retry-delay 2 http://localhost:${hostPort}/ || {
                    echo "Health check failed. Showing container logs:"
                    docker logs ${containerName}
                    exit 1
                }
            """
        }

        echo "Container '${containerName}' is up and serving traffic on port ${hostPort}."

    } catch (err) {
        echo "Pipeline failed: ${err.getMessage()}"
        sh "docker logs ${containerName} || true"
        throw err

    } finally {
        stage('Workspace Cleanup') {
            cleanWs()
        }
    }
}
