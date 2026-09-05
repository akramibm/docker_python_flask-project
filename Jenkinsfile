node {
    def imageName     = 'flask-app'
    def containerName = 'flask-app-service'
    def hostPort      = '5000'
    def gitCredsId    = 'token123'
    def repoUrl       = 'https://github.com/akramibm/docker_python_flask-project.git'

    try {
        stage('Checkout Code') {
            echo "Checking out repo using credentials: ${gitCredsId}..."
            git branch: 'main',
                credentialsId: gitCredsId,
                url: repoUrl
        }

        stage('Build Docker Image') {
            echo 'Building Docker container image from Dockerfile...'
            // Uses your repo Dockerfile and requirements.txt
            sh "docker build -t ${imageName}:${BUILD_NUMBER} -t ${imageName}:latest ."
        }

        stage('Run App in Background') {
            echo 'Launching Flask container in detached background mode (-d)...'
            sh """
                # Clean existing container
                if [ \$(docker ps -aq -f name=^/${containerName}\$) ]; then
                    docker stop ${containerName} || true
                    docker rm -f ${containerName} || true
                fi

                # Run detached in background
                docker run -d \\
                    --name ${containerName} \\
                    -p ${hostPort}:5000 \\
                    --restart unless-stopped \\
                    ${imageName}:latest

                docker ps -f name=^/${containerName}\$
            """
        }

        stage('Health Check') {
            echo 'Testing Flask container background status...'
            sh """
                sleep 5
                curl -I -s --retry 3 --retry-delay 2 http://localhost:${hostPort}/ || {
                    echo "Container failed to respond. Checking logs:"
                    docker logs ${containerName}
                    exit 1
                }
            """
        }

        echo "Flask container is up and running in background on port ${hostPort}!"

    } catch (err) {
        echo "Build failed: ${err.getMessage()}"
        sh "docker logs ${containerName} || true"
        throw err

    } finally {
        stage('Cleanup Workspace') {
            cleanWs()
        }
    }
}
