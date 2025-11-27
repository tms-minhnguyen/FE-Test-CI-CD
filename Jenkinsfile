pipeline {
    agent any

    environment {
        AUTOTEST_JOB_NAME = 'playwright-pr-check'
    }

    stages {
        stage('Checkout FE') {
            steps {
                script {
                    echo "Building FE for PR: ${env.CHANGE_ID}"
                    echo "Branch: ${env.CHANGE_BRANCH}"
                }
                checkout scm
            }
        }

        stage('Build FE') {
            steps {
                script {
                    echo "Building FE application..."
                    // Thêm các bước build FE của bạn ở đây
                    // Ví dụ: npm install, npm run build, etc.
                    sh 'npm install'
                    sh 'npm run build'
                    sh 'npm start'
                }
            }
        }

        stage('Trigger Automation Test') {
            when {
                // Chỉ trigger khi có PR
                expression { env.CHANGE_ID != null }
            }
            steps {
                script {
                    def prNumber = env.CHANGE_ID
                    def prBranch = env.CHANGE_BRANCH
                    
                    echo "🚀 Triggering automation test for PR #${prNumber} (branch: ${prBranch})"
                    
                    // Trigger automation test job
                    def testJob = Jenkins.instance.getItem(env.AUTOTEST_JOB_NAME)
                    if (testJob == null) {
                        error("Automation test job '${env.AUTOTEST_JOB_NAME}' not found!")
                    }
                    
                    // Tạo parameters
                    def buildParams = [
                        new hudson.model.StringParameterValue('PR_NUMBER', prNumber.toString()),
                        new hudson.model.StringParameterValue('PR_BRANCH', prBranch)
                    ]
                    def paramAction = new hudson.model.ParametersAction(buildParams)
                    
                    // Trigger build
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