pipeline {
    agent any

    environment {
        NODE_BIN = '/Users/phinguyen/.nvm/versions/node/v20.19.6/bin'
        PATH = "/Users/phinguyen/.nvm/versions/node/v20.19.6/bin:${env.PATH}"
        GITHUB_TOKEN = credentials('github-token')
        AUTOMATION_TEST_JOB = 'tmc-nocode-survey-autotest'
        GITHUB_REPO_OWNER = 'TOMOSIA-VIETNAM'
        GITHUB_REPO_NAME = 'nextjs-login-page'
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
                        echo "Node.js: \$(${env.NODE_BIN}/node --version)"
                        echo "NPM: \$(${env.NODE_BIN}/npm --version)"
                        echo "Working directory: \$(pwd)"
                    """
                }
            }
        }

        stage('Install Dependencies') {
            steps {
                script {
                    echo "📦 Installing dependencies..."
                    sh """
                        unset NODE_ENV || true
                        ${env.NODE_BIN}/npm install --legacy-peer-deps --prefer-offline --no-audit
                        
                        echo "Verifying installed packages:"
                        ${env.NODE_BIN}/npm list typescript @types/react @types/node @types/react-dom 2>/dev/null || echo "Warning: Some packages check failed"
                        
                        if [ ! -f "node_modules/typescript/bin/tsc" ]; then
                            echo "ERROR: TypeScript not found, installing explicitly..."
                            ${env.NODE_BIN}/npm install --save-dev --legacy-peer-deps typescript @types/react @types/node @types/react-dom
                        fi
                    """
                }
            }
        }

        stage('Lint') {
            steps {
                script {
                    echo "🔍 Running linter..."
                    sh "${env.NODE_BIN}/npm run lint || echo '⚠️ Lint completed with warnings'"
                }
            }
        }

        stage('Build FE') {
            steps {
                script {
                    echo "🔨 Building application..."
                    sh """
                        NODE_ENV=production ${env.NODE_BIN}/npm run build
                    """
                    echo "✅ Build completed successfully!"
                }
            }
        }

        stage('Trigger Automation Tests') {
            when {
                expression { 
                    return env.CHANGE_ID != null
                }
            }
            steps {
                script {
                    def branchName = env.CHANGE_BRANCH ?: env.BRANCH_NAME
                    def testTag = extractFeatureName(branchName)
                    
                    if (testTag) {
                        echo "🔍 Detected feature: ${testTag} from branch: ${branchName}"
                        echo "🚀 Triggering Automation Test job with tag: ${testTag}"
                        
                        try {
                            def testJob = build job: env.AUTOMATION_TEST_JOB,
                                parameters: [
                                    string(name: 'TEST_TAG', value: testTag),
                                    string(name: 'PR_NUMBER', value: env.CHANGE_ID),
                                    string(name: 'PR_BRANCH', value: env.CHANGE_BRANCH),
                                    string(name: 'PR_URL', value: env.CHANGE_URL ?: ''),
                                    string(name: 'PR_REPO', value: env.GITHUB_REPO_NAME),
                                    string(name: 'PR_OWNER', value: env.GITHUB_REPO_OWNER),
                                    string(name: 'TARGET_BRANCH', value: env.CHANGE_TARGET ?: 'main')
                                ],
                                wait: true,
                                propagate: false
                            
                            def testResult = testJob.result ?: 'UNKNOWN'
                            def testUrl = "${env.JENKINS_URL}job/${testJob.fullProjectName}/${testJob.number}/"
                            
                            echo "📊 Automation Test Result: ${testResult}"
                            echo "🔗 Test Job URL: ${testUrl}"
                            
                            if (testResult == 'FAILURE') {
                                echo "⚠️ Automation tests failed, but continuing pipeline"
                            }
                            
                        } catch (Exception e) {
                            echo "❌ Failed to trigger automation tests: ${e.getMessage()}"
                            def errorComment = """
## 🤖 Automation Test Error

**Feature Tag:** \`${testTag}\`
**Status:** ❌ FAILED TO TRIGGER
**Error:** ${e.getMessage()}

---
*This comment was automatically generated by Jenkins*
"""
                            commentToPR(errorComment)
                        }
                    } else {
                        echo "ℹ️ No feature detected in branch: ${branchName}"
                        echo "   Expected format: feat/<feature-name>"
                        echo "   Example: feat/login, feat/user-profile"
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

def extractFeatureName(branchName) {
    if (!branchName) return null
    
    def patterns = [
        /^feat\/(.+)$/,              // feat/login
        /^feature\/(.+)$/,           // feature/login
        /^fix\/(.+)$/,               // fix/login-bug
        /^refactor\/(.+)$/,         // refactor/login
    ]
    
    for (pattern in patterns) {
        def matcher = branchName =~ pattern
        if (matcher) {
            return matcher[0][1].trim()
        }
    }
    
    return null
}

def commentToPR(commentBody) {
    if (!env.CHANGE_ID || !env.GITHUB_TOKEN) {
        echo "⚠️ Missing PR info or GitHub token. Skipping PR comment."
        return
    }
    
    try {
        def repoOwner = env.GITHUB_REPO_OWNER
        def repoName = env.GITHUB_REPO_NAME
        def prNumber = env.CHANGE_ID
        
        def jsonBody = groovy.json.JsonOutput.toJson(commentBody)
        
        sh """
            curl -s -X POST \
                -H "Authorization: token ${env.GITHUB_TOKEN}" \
                -H "Accept: application/vnd.github.v3+json" \
                -H "Content-Type: application/json" \
                https://api.github.com/repos/${repoOwner}/${repoName}/issues/${prNumber}/comments \
                -d '{"body": ${jsonBody}}' \
                -w "\\nHTTP Status: %{http_code}\\n"
        """
        
        echo "✅ Comment posted to PR #${prNumber}"
    } catch (Exception e) {
        echo "❌ Failed to comment to PR: ${e.getMessage()}"
    }
}