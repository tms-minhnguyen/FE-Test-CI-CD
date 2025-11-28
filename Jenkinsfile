pipeline {
    agent any

    environment {
        AUTOTEST_JOB_NAME = 'playwright-pr-check'
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

        stage('Build FE') {
            steps {
                script {
                    echo "📦 Installing dependencies..."
                    sh 'npm install'
                    
                    echo "🔨 Building application..."
                    sh 'npm run build'
                    
                    // Note: npm start chạy server, thường không cần trong CI
                    // Chỉ dùng nếu cần server để chạy tests
                    // sh 'npm start &'
                    // sh 'sleep 5'
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
                        error("Automation test job '${env.AUTOTEST_JOB_NAME}' not found!")
                    }
                    
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
    
    post {
        always {
            echo "🏁 Build completed for ${env.CHANGE_ID ? "PR #${env.CHANGE_ID}" : "branch ${env.BRANCH_NAME}"}"
        }
        success {
            echo "✅ Build successful!"
        }
        failure {
            echo "❌ Build failed!"
        }
    }
}