pipeline {
    agent any

    environment {
        NODE_ENV = 'production'
        NODE_BIN = '/Users/phinguyen/.nvm/versions/node/v20.19.6/bin'
        PATH = "/Users/phinguyen/.nvm/versions/node/v20.19.6/bin:${env.PATH}"
    }

    stages {
        stage('Checkout FE') {
            steps {
                script {
                    if (env.CHANGE_ID) {
                        echo "🔵 Building FE for PR #${env.CHANGE_ID}"
                        echo "   PR Branch: ${env.CHANGE_BRANCH}"
                        echo "   Target Branch: ${env.CHANGE_TARGET}"
                        echo "   PR URL: ${env.CHANGE_URL}"
                    } else {
                        echo "🔵 Building FE for branch: ${env.BRANCH_NAME}"
                    }
                }
                checkout scm
            }
        }

        stage('Verify Environment') {
            steps {
                script {
                    echo "📋 Verifying Node.js environment..."
                    sh """
                        echo "Node.js version:"
                        ${env.NODE_BIN}/node --version
                        echo "NPM version:"
                        ${env.NODE_BIN}/npm --version
                    """
                }
            }
        }

        stage('Install Dependencies') {
            steps {
                script {
                    echo "📦 Installing dependencies..."
                    sh "${env.NODE_BIN}/npm install --legacy-peer-deps --prefer-offline --no-audit"
                }
            }
        }

        stage('Lint') {
            steps {
                script {
                    echo "🔍 Running linter..."
                    sh "${env.NODE_BIN}/npm run lint || echo 'Lint completed with warnings'"
                }
            }
        }

        stage('Build FE') {
            steps {
                script {
                    echo "🔨 Building application..."
                    sh "${env.NODE_BIN}/npm run build"
                    echo "✅ Build completed successfully!"
                }
            }
        }
    }
    
    post {
        always {
            script {
                def status = currentBuild.result ?: 'SUCCESS'
                echo "🏁 Build completed with status: ${status}"
                if (env.CHANGE_ID) {
                    echo "   PR #${env.CHANGE_ID} - Branch: ${env.CHANGE_BRANCH}"
                } else {
                    echo "   Branch: ${env.BRANCH_NAME}"
                }
            }
        }
        success {
            echo "✅ Build successful!"
        }
        failure {
            echo "❌ Build failed!"
            script {
                echo "📝 Check the logs above for error details"
            }
        }
        cleanup {
            echo "🧹 Cleaning up..."
        }
    }
}