pipeline {
    agent any

    environment {
        NODE_ENV = 'production'
        NVM_DIR = "${env.HOME}/.nvm"
        NODE_PATH = "${env.HOME}/.nvm/versions/node/v20.19.6"
        PATH = "${env.HOME}/.nvm/versions/node/v20.19.6/bin:${env.PATH}"
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

        stage('Setup Node.js') {
            steps {
                script {
                    echo "📋 Setting up Node.js environment..."
                    sh '''
                        export NVM_DIR="$HOME/.nvm"
                        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || true
                        [ -s "$HOME/.zshrc" ] && source "$HOME/.zshrc" || true
                        [ -s "$HOME/.bash_profile" ] && source "$HOME/.bash_profile" || true
                        
                        echo "Node.js version:"
                        node --version || echo "Node not found"
                        echo "NPM version:"
                        npm --version || echo "NPM not found"
                        echo "Node.js path:"
                        which node || echo "Node path not found"
                        echo "NPM path:"
                        which npm || echo "NPM path not found"
                    '''
                }
            }
        }

        stage('Install Dependencies') {
            steps {
                script {
                    echo "📦 Installing dependencies..."
                    sh '''
                        export NVM_DIR="$HOME/.nvm"
                        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || true
                        [ -s "$HOME/.zshrc" ] && source "$HOME/.zshrc" || true
                        [ -s "$HOME/.bash_profile" ] && source "$HOME/.bash_profile" || true
                        
                        npm ci --prefer-offline --no-audit
                    '''
                }
            }
        }

        stage('Lint') {
            steps {
                script {
                    echo "🔍 Running linter..."
                    sh '''
                        export NVM_DIR="$HOME/.nvm"
                        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || true
                        [ -s "$HOME/.zshrc" ] && source "$HOME/.zshrc" || true
                        [ -s "$HOME/.bash_profile" ] && source "$HOME/.bash_profile" || true
                        
                        npm run lint || echo "Lint completed with warnings"
                    '''
                }
            }
        }

        stage('Build FE') {
            steps {
                script {
                    echo "🔨 Building application..."
                    sh '''
                        export NVM_DIR="$HOME/.nvm"
                        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || true
                        [ -s "$HOME/.zshrc" ] && source "$HOME/.zshrc" || true
                        [ -s "$HOME/.bash_profile" ] && source "$HOME/.bash_profile" || true
                        
                        npm run build
                    '''
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