pipeline {
    agent {
        docker {
            image 'node:18-alpine'
            args '-v /root/.npm:/root/.npm -v /tmp:/tmp'
            reuseNode true
        }
    }

    environment {
        AUTOTEST_JOB_NAME = 'playwright-pr-check'
        NODE_ENV = 'production'
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
                    echo "📋 Environment Information:"
                    sh 'node --version'
                    sh 'npm --version'
                    sh 'pwd'
                    sh 'ls -la'
                }
            }
        }

        stage('Install Dependencies') {
            steps {
                script {
                    echo "📦 Installing dependencies..."
                    sh 'npm ci --prefer-offline --no-audit'
                }
            }
        }

        stage('Lint') {
            steps {
                script {
                    echo "🔍 Running linter..."
                    sh 'npm run lint || true'
                }
            }
        }

        stage('Build FE') {
            steps {
                script {
                    echo "🔨 Building application..."
                    sh 'npm run build'
                }
            }
        }

        stage('Trigger Automation Test') {
            when {
                expression { env.CHANGE_ID != null }
            }
            steps {
                script {
                    def prNumber = env.CHANGE_ID
                    def prBranch = env.CHANGE_BRANCH
                    
                    echo "🚀 Triggering automation test for PR #${prNumber} (branch: ${prBranch})"
                    
                    def testJob = Jenkins.instance.getItem(env.AUTOTEST_JOB_NAME)
                    if (testJob == null) {
                        echo "⚠️ Warning: Automation test job '${env.AUTOTEST_JOB_NAME}' not found. Skipping..."
                    } else {
                        def buildParams = [
                            new hudson.model.StringParameterValue('PR_NUMBER', prNumber.toString()),
                            new hudson.model.StringParameterValue('PR_BRANCH', prBranch)
                        ]
                        def paramAction = new hudson.model.ParametersAction(buildParams)
                        
                        def cause = new hudson.model.Cause.UpstreamCause(currentBuild)
                        def scheduled = testJob.scheduleBuild(0, cause, paramAction)
                        
                        if (scheduled) {
                            echo "✅ Successfully triggered automation test job"
                        } else {
                            echo "⚠️ Automation test job may already be in queue"
                        }
                    }
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