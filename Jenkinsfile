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
                                error("❌ Automation tests failed. Build cannot proceed.")
                            }
                            
                            echo "📥 Reading test results from Automation Test job..."
                            def testResults = readTestResultsFromJob(testJob)
                            
                            if (testResults) {
                                echo "✅ Successfully read test results: ${testResults.total} tests"
                                echo "   Passed: ${testResults.passed}, Failed: ${testResults.failed}, Skipped: ${testResults.skipped}"
                                
                                echo "💬 Commenting test results to PR..."
                                commentTestResultsToPR(testResults, testTag, testUrl, testJob.number)
                            } else {
                                echo "⚠️ Could not read test results from Automation Test job"
                                echo "   Commenting basic result to PR..."
                                def basicComment = """
## 🤖 Automation Test Results

**Test Tag:** `${testTag}`
**Status:** ${testResult == 'SUCCESS' ? '✅ PASSED' : '❌ FAILED'}
**Test Job:** [View Details #${testJob.number}](${testUrl})

---
*This comment was automatically generated by Jenkins FE Job*
"""
                                commentToPR(basicComment)
                            }
                            
                            echo "✅ Test results processed and commented to PR."
                            
                        } catch (Exception e) {
                            def errorMessage = "❌ Failed to trigger or verify automation tests: ${e.getMessage()}"
                            echo errorMessage
                            
                            def errorComment = """
## 🤖 Automation Test Error

**Feature Tag:** `${testTag}`
**Status:** ❌ FAILED TO TRIGGER OR VERIFY
**Error:** ${e.getMessage()}

**Branch:** `${branchName}`

---
*This comment was automatically generated by Jenkins*
"""
                            commentToPR(errorComment)
                            error(errorMessage)
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

def readTestResultsFromJob(testJob) {
    try {
        def jobName = testJob.fullProjectName
        def buildNumber = testJob.number
        
        echo "   Reading test results from job: ${jobName} #${buildNumber}"
        
        def workspacePath = "${env.JENKINS_HOME}/workspace/${jobName}"
        def resultsFile = "${workspacePath}/test-results-summary.json"
        
        echo "   Looking for file: ${resultsFile}"
        
        if (fileExists(resultsFile)) {
            def jsonContent = readFile(resultsFile)
            def testResults = new groovy.json.JsonSlurper().parseText(jsonContent)
            echo "   ✅ Successfully read test results file"
            return testResults
        } else {
            echo "   ⚠️ Test results file not found at: ${resultsFile}"
            echo "   Trying alternative path..."
            
            def altPath = "${env.JENKINS_HOME}/jobs/${jobName}/builds/${buildNumber}/archive/test-results-summary.json"
            if (fileExists(altPath)) {
                def jsonContent = readFile(altPath)
                def testResults = new groovy.json.JsonSlurper().parseText(jsonContent)
                echo "   ✅ Successfully read test results from archive"
                return testResults
            }
            
            echo "   ⚠️ Test results file not found in alternative path either"
            echo "   Automation Test job should save test-results-summary.json file"
        }
        
        return null
    } catch (Exception e) {
        echo "   ❌ Error reading test results: ${e.getMessage()}"
        echo "   Stack trace: ${e.getStackTrace().take(3).join('\n')}"
        return null
    }
}

def commentTestResultsToPR(testResults, testTag, testUrl, buildNumber) {
    if (!env.CHANGE_ID || !env.GITHUB_TOKEN) {
        echo "⚠️ Missing PR info or GitHub token. Skipping PR comment."
        return
    }
    
    def result = testResults.failed > 0 ? 'FAILED' : 'PASSED'
    def statusEmoji = result == 'PASSED' ? '✅' : '❌'
    
    def total = testResults.total ?: 0
    def passed = testResults.passed ?: 0
    def failed = testResults.failed ?: 0
    def skipped = testResults.skipped ?: 0
    def duration = testResults.duration ?: 0
    def durationSeconds = duration > 0 ? String.format("%.2f", duration / 1000) : "0.00"
    
    def comment = """## 🤖 Automation Test Results

**Test Tag:** `${testTag}`
**Status:** ${statusEmoji} **${result}**
**Test Job:** [View Details #${buildNumber}](${testUrl})
**Duration:** ${durationSeconds}s

### 📊 Test Summary

| Metric | Count |
|--------|-------|
| **Total Tests** | ${total} |
| **✅ Passed** | ${passed} |
| **❌ Failed** | ${failed} |
| **⏭️ Skipped** | ${skipped} |

"""
    
    if (testResults.testCases && !testResults.testCases.isEmpty()) {
        comment += "### 📝 Test Cases Details\n\n"
        
        def passedTests = testResults.testCases.findAll { it.status == 'passed' }
        def failedTests = testResults.testCases.findAll { it.status == 'failed' }
        def skippedTests = testResults.testCases.findAll { it.status == 'skipped' }
        
        if (passedTests && !passedTests.isEmpty()) {
            comment += "#### ✅ Passed Tests (${passedTests.size()})\n\n"
            passedTests.each { test ->
                def durationStr = test.duration > 0 ? " (${String.format("%.2f", test.duration / 1000)}s)" : ""
                comment += "- ✅ `${test.title}`${durationStr}\n"
            }
            comment += "\n"
        }
        
        if (failedTests && !failedTests.isEmpty()) {
            comment += "#### ❌ Failed Tests (${failedTests.size()})\n\n"
            failedTests.each { test ->
                comment += "- ❌ `${test.title}`\n"
                if (test.error) {
                    def errorMsg = test.error.replaceAll(/`/, "'").replaceAll(/\n/, ' ').take(300)
                    comment += "  ```\n${errorMsg}\n```\n"
                }
            }
            comment += "\n"
        }
        
        if (skippedTests && !skippedTests.isEmpty()) {
            comment += "#### ⏭️ Skipped Tests (${skippedTests.size()})\n\n"
            skippedTests.each { test ->
                comment += "- ⏭️ `${test.title}`\n"
            }
            comment += "\n"
        }
    } else {
        comment += "### ⚠️ No test cases found\n\n"
        comment += "No test cases were executed or parsed.\n"
    }
    
    comment += """---
*This comment was automatically generated by Jenkins FE Job*
"""
    
    commentToPR(comment)
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
        echo "   This is not a critical error, pipeline will continue"
    }
}