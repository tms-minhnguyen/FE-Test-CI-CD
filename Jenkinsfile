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
                        
                        // Create GitHub Check Run with "in_progress" status
                        createGitHubCheckRun('in_progress', null, 'CI/CD pipeline started')
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
                            
                            // Store test job info for later stages
                            env.AUTOMATION_TEST_JOB_BUILD_NUMBER = "${testJob.number}"
                            env.AUTOMATION_TEST_JOB_NAME = "${testJob.fullProjectName}"
                            
                            if (testResult == 'FAILURE' || testResult == 'UNSTABLE') {
                                echo "❌ Automation tests failed or unstable!"
                                echo "   Test Result: ${testResult}"
                                echo "   Test Job URL: ${testUrl}"
                                echo "   Continuing to fetch and publish results before failing build..."
                                
                                // Store failure status for later stages
                                env.AUTOMATION_TEST_FAILED = 'true'
                            } else if (testResult == 'SUCCESS') {
                                echo "✅ Automation tests passed!"
                                env.AUTOMATION_TEST_FAILED = 'false'
                            } else {
                                echo "⚠️ Automation test result is unknown: ${testResult}"
                                env.AUTOMATION_TEST_FAILED = 'false'
                            }
                            
                        } catch (Exception e) {
                            def errorMessage = "❌ Failed to trigger automation tests: ${e.getMessage()}"
                            echo errorMessage
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

        stage('Fetch Automation Test Results') {
            when {
                expression { 
                    return env.CHANGE_ID != null && env.AUTOMATION_TEST_JOB_BUILD_NUMBER != null
                }
            }
            steps {
                script {
                    echo "📥 Fetching test results from Automation Test job..."
                    
                    try {
                        def jobName = env.AUTOMATION_TEST_JOB_NAME ?: env.AUTOMATION_TEST_JOB
                        def buildNumber = env.AUTOMATION_TEST_JOB_BUILD_NUMBER
                        
                        echo "   Copying artifacts from: ${jobName} #${buildNumber}"
                        
                        // Create test-results directory
                        sh 'mkdir -p test-results'
                        
                        // Copy both JSON and JUnit XML files from Automation job
                        copyArtifacts(
                            projectName: jobName,
                            selector: [$class: 'SpecificBuildSelector', buildNumber: "${buildNumber}"],
                            filter: 'test-results/**/*',
                            target: 'test-results/',
                            flatten: false,
                            optional: true
                        )
                        
                        // Check if JSON file exists (preferred for full test names)
                        def jsonFile = null
                        def jsonFiles = [
                            'test-results/results.json',
                            'test-results.json'
                        ]
                        
                        for (def file : jsonFiles) {
                            if (fileExists(file)) {
                                jsonFile = file
                                echo "✅ Found JSON results file: ${file}"
                                break
                            }
                        }
                        
                        // If JSON exists, convert to JUnit XML with full test names
                        if (jsonFile) {
                            echo "🔄 Converting JSON results to JUnit XML with full test names..."
                            convertJsonToJUnitXml(jsonFile, 'test-results/junit.xml')
                            echo "✅ Created JUnit XML with full test descriptions"
                        } else if (fileExists('test-results/junit.xml')) {
                            echo "✅ Found existing JUnit XML file"
                            echo "   Note: Test names may be shortened. For full names, ensure JSON results are available."
                        } else {
                            echo "⚠️ Neither JSON nor JUnit XML files found"
                            echo "   Listing test-results directory:"
                            sh 'ls -la test-results/ || echo "Directory is empty"'
                        }
                        
                    } catch (Exception e) {
                        echo "❌ Error copying artifacts: ${e.getMessage()}"
                        echo "   This may be because the Automation job did not produce test results"
                        echo "   Continuing anyway..."
                    }
                }
            }
        }

        stage('Publish Test Results to GitHub Checks') {
            when {
                expression { 
                    return env.CHANGE_ID != null
                }
            }
            steps {
                script {
                    echo "📤 Publishing test results to GitHub Checks..."
                    
                    try {
                        def hasFailures = false
                        def testSummary = "No test results found"
                        
                        // Check if automation test job failed (from previous stage)
                        if (env.AUTOMATION_TEST_FAILED == 'true') {
                            hasFailures = true
                            testSummary = "Automation test job failed"
                        }
                        
                        if (fileExists('test-results/junit.xml')) {
                            echo "✅ Found JUnit XML file, publishing to GitHub Checks..."
                            
                            // Parse JUnit XML to get test results
                            def testResults = parseJUnitXml('test-results/junit.xml')
                            if (testResults.failures > 0) {
                                hasFailures = true
                            }
                            testSummary = "Total: ${testResults.total}, Passed: ${testResults.passed}, Failed: ${testResults.failures}"
                            
                            // Use Warnings Plugin to parse JUnit XML and publish to GitHub Checks
                            recordIssues(
                                enabledForFailure: true,
                                tools: [
                                    jUnitParser(
                                        pattern: 'test-results/junit.xml',
                                        id: 'automation-tests',
                                        name: 'Automation Tests'
                                    )
                                ],
                                publishChecks: true,
                                qualityGates: [
                                    [
                                        threshold: 1,
                                        type: 'TOTAL',
                                        unstable: false
                                    ]
                                ]
                            )
                            
                            echo "✅ Test results published to GitHub Checks"
                        } else {
                            echo "⚠️ JUnit XML file not found at test-results/junit.xml"
                            if (env.AUTOMATION_TEST_FAILED == 'true') {
                                echo "   Automation test job failed and no results file found"
                                testSummary = "Automation test job failed - no test results available"
                            } else {
                                echo "   Skipping GitHub Checks publication"
                                echo "   Make sure Automation job generates JUnit XML file"
                            }
                        }
                        
                        // Update GitHub Check Run with final status
                        def conclusion = hasFailures ? 'failure' : 'success'
                        def statusText = hasFailures ? 'Some tests failed' : 'All checks passed'
                        updateGitHubCheckRun(conclusion, statusText, testSummary)
                        
                        // Store test failure status
                        if (hasFailures) {
                            env.AUTOMATION_TEST_FAILED = 'true'
                        }
                        
                    } catch (Exception e) {
                        echo "❌ Error publishing test results to GitHub Checks: ${e.getMessage()}"
                        echo "   Stack trace: ${e.getStackTrace().take(3).join('\n')}"
                        echo "   Continuing build..."
                        
                        // Update check run with error status
                        updateGitHubCheckRun('failure', 'Error publishing test results', e.getMessage())
                    }
                }
            }
        }

        stage('Validate Automation Test Results') {
            when {
                expression { 
                    return env.CHANGE_ID != null && env.AUTOMATION_TEST_JOB_BUILD_NUMBER != null
                }
            }
            steps {
                script {
                    echo "🔍 Validating automation test results..."
                    
                    def testFailed = env.AUTOMATION_TEST_FAILED == 'true'
                    
                    if (testFailed) {
                        def testJobName = env.AUTOMATION_TEST_JOB_NAME ?: env.AUTOMATION_TEST_JOB
                        def testBuildNumber = env.AUTOMATION_TEST_JOB_BUILD_NUMBER
                        def testUrl = "${env.JENKINS_URL}job/${testJobName}/${testBuildNumber}/"
                        
                        echo "❌ Automation tests failed!"
                        echo "   Test Job: ${testJobName} #${testBuildNumber}"
                        echo "   Test Job URL: ${testUrl}"
                        echo "   Build will be marked as FAILURE"
                        
                        // Fail the build
                        currentBuild.result = 'FAILURE'
                        error("❌ Automation tests failed. Please check the test results and fix the issues before merging.")
                    } else {
                        echo "✅ Automation tests passed successfully!"
                        echo "   Build can continue"
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
                    
                    // Update GitHub Check Run with final build status if not already updated
                    if (!env.GITHUB_CHECK_UPDATED) {
                        def conclusion = (status == 'SUCCESS') ? 'success' : 'failure'
                        def statusText = (status == 'SUCCESS') ? 'Build completed successfully' : 'Build failed'
                        updateGitHubCheckRun(conclusion, statusText, "Build status: ${status}")
                    }
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

def createGitHubCheckRuns(testResults, testTag, testUrl, buildNumber) {
    if (!env.CHANGE_ID || !env.GITHUB_TOKEN) {
        echo "⚠️ Missing PR info or GitHub token. Skipping check runs creation."
        return
    }
    
    try {
        def repoOwner = env.GITHUB_REPO_OWNER
        def repoName = env.GITHUB_REPO_NAME
        def prSha = getPRHeadSha(env.CHANGE_ID)
        
        if (!prSha) {
            echo "⚠️ Could not get PR head SHA. Skipping check runs."
            return
        }
        
        echo "   Creating GitHub Check Runs for ${testResults.testCases?.size() ?: 0} test cases..."
        
        if (testResults.testCases && !testResults.testCases.isEmpty()) {
            def successCount = 0
            def failureCount = 0
            
            testResults.testCases.each { test ->
                def checkName = "${testTag} - ${test.title}"
                def conclusion = test.status == 'passed' ? 'success' : 
                                test.status == 'failed' ? 'failure' : 
                                'neutral'
                
                def title = test.status == 'passed' ? 
                    "${test.title} passed" : 
                    "${test.title} failed. Investigate!"
                
                def summary = test.status == 'passed' ? 
                    "Test passed successfully" : 
                    "Test failed: ${test.error ?: 'Unknown error'}"
                
                def outputText = "**Test:** ${test.title}\n"
                outputText += "**Status:** ${test.status}\n"
                if (test.duration > 0) {
                    outputText += "**Duration:** ${String.format("%.2f", test.duration / 1000)}s\n"
                }
                if (test.error) {
                    def errorMsg = test.error.replaceAll(/`/, "'").replaceAll(/\n/, ' ').take(500)
                    outputText += "\n**Error:**\n```\n${errorMsg}\n```\n"
                }
                
                def checkRunData = [
                    name: checkName,
                    head_sha: prSha,
                    status: 'completed',
                    conclusion: conclusion,
                    output: [
                        title: title,
                        summary: summary,
                        text: outputText
                    ],
                    details_url: testUrl
                ]
                
                def jsonBody = groovy.json.JsonOutput.toJson(checkRunData)
                
                def response = sh(
                    script: """
                        curl -s -w "\\nHTTP_CODE:%{http_code}" -X POST \
                            -H "Authorization: token ${env.GITHUB_TOKEN}" \
                            -H "Accept: application/vnd.github.v3+json" \
                            -H "Content-Type: application/json" \
                            https://api.github.com/repos/${repoOwner}/${repoName}/check-runs \
                            -d '${jsonBody}'
                    """,
                    returnStdout: true
                ).trim()
                
                def httpCode = response.split('HTTP_CODE:')[1] ?: 'unknown'
                
                if (httpCode == '201') {
                    if (test.status == 'passed') {
                        successCount++
                    } else if (test.status == 'failed') {
                        failureCount++
                    }
                } else {
                    echo "   ⚠️ Failed to create check run for ${test.title}: HTTP ${httpCode}"
                }
            }
            
            echo "   ✅ Created ${testResults.testCases.size()} check runs (${successCount} passed, ${failureCount} failed)"
        } else {
            echo "   ⚠️ No test cases to create check runs for"
        }
        
    } catch (Exception e) {
        echo "❌ Failed to create check runs: ${e.getMessage()}"
        echo "   Stack trace: ${e.getStackTrace().take(3).join('\n')}"
    }
}

def getPRHeadSha(prNumber) {
    try {
        def repoOwner = env.GITHUB_REPO_OWNER
        def repoName = env.GITHUB_REPO_NAME
        
        def response = sh(
            script: """
                curl -s -H "Authorization: token ${env.GITHUB_TOKEN}" \
                    -H "Accept: application/vnd.github.v3+json" \
                    https://api.github.com/repos/${repoOwner}/${repoName}/pulls/${prNumber}
            """,
            returnStdout: true
        ).trim()
        
        def prData = new groovy.json.JsonSlurper().parseText(response)
        def headSha = prData.head?.sha
        
        if (headSha) {
            echo "   ✅ Got PR head SHA: ${headSha.take(7)}..."
            return headSha
        } else {
            echo "   ⚠️ Could not extract head SHA from PR data"
            return null
        }
    } catch (Exception e) {
        echo "   ⚠️ Error getting PR head SHA: ${e.getMessage()}"
        return null
    }
}

def convertJsonToJUnitXml(jsonFilePath, outputXmlPath) {
    try {
        echo "   Reading JSON results from: ${jsonFilePath}"
        def jsonContent = readFile(jsonFilePath).trim()
        
        // Extract JSON if file contains noise
        def jsonStart = jsonContent.indexOf('[')
        def jsonStartBrace = jsonContent.indexOf('{')
        if (jsonStart >= 0 || jsonStartBrace >= 0) {
            def actualStart = (jsonStart >= 0 && jsonStartBrace >= 0) ? 
                Math.min(jsonStart, jsonStartBrace) : 
                (jsonStart >= 0 ? jsonStart : jsonStartBrace)
            if (actualStart > 0) {
                jsonContent = jsonContent.substring(actualStart)
            }
        }
        
        def jsonData = new groovy.json.JsonSlurper().parseText(jsonContent)
        def suites = []
        if (jsonData instanceof List) {
            suites = jsonData
        } else if (jsonData instanceof Map && jsonData.suites) {
            suites = jsonData.suites
        }
        
        if (!suites || suites.isEmpty()) {
            echo "   ⚠️ No suites found in JSON data"
            return
        }
        
        // Build JUnit XML
        def xmlBuilder = new StringBuilder()
        xmlBuilder.append('<?xml version="1.0" encoding="UTF-8"?>\n')
        
        def totalTests = 0
        def totalFailures = 0
        def totalErrors = 0
        def totalTime = 0
        def testSuites = []
        
        suites.each { suite ->
            if (suite.specs) {
                suite.specs.each { spec ->
                    def suiteName = spec.title ?: spec.file ?: 'Unknown Suite'
                    def suiteTests = 0
                    def suiteFailures = 0
                    def suiteErrors = 0
                    def suiteTime = 0
                    def testCases = []
                    
                    if (spec.tests) {
                        spec.tests.each { test ->
                            suiteTests++
                            totalTests++
                            
                            // Get test result (last result after retries)
                            def testResult = null
                            if (test.results && !test.results.isEmpty()) {
                                testResult = test.results[test.results.size() - 1]
                            }
                            
                            def status = testResult?.status ?: (test.ok == false ? 'failed' : (test.ok == true ? 'passed' : 'skipped'))
                            def duration = testResult?.duration ?: 0
                            suiteTime += duration
                            totalTime += duration
                            
                            // Get full test name (description) - this is what we want!
                            def testName = test.title ?: 'Unknown test'
                            
                            // Build testcase XML
                            def testCaseXml = new StringBuilder()
                            testCaseXml.append('    <testcase classname="').append(escapeXml(suiteName)).append('" ')
                            testCaseXml.append('name="').append(escapeXml(testName)).append('" ')
                            testCaseXml.append('time="').append(String.format("%.3f", duration / 1000)).append('">')
                            
                            if (status == 'failed') {
                                suiteFailures++
                                totalFailures++
                                
                                def errorObj = testResult?.error
                                def errorMessage = 'Test failed'
                                def errorDetails = ''
                                
                                if (errorObj) {
                                    if (errorObj instanceof Map) {
                                        errorMessage = errorObj.message ?: errorObj.toString()
                                        errorDetails = errorObj.stack ?: errorObj.toString()
                                    } else {
                                        errorMessage = errorObj.toString()
                                        errorDetails = errorObj.toString()
                                    }
                                }
                                
                                testCaseXml.append('\n      <failure message="').append(escapeXml(errorMessage.take(500))).append('">')
                                testCaseXml.append(escapeXml(errorDetails.take(2000)))
                                testCaseXml.append('</failure>\n    ')
                            } else if (status == 'skipped') {
                                testCaseXml.append('\n      <skipped/>\n    ')
                            }
                            
                            testCaseXml.append('</testcase>')
                            testCases.add(testCaseXml.toString())
                        }
                    }
                    
                    if (suiteTests > 0) {
                        def suiteXml = new StringBuilder()
                        suiteXml.append('  <testsuite name="').append(escapeXml(suiteName)).append('" ')
                        suiteXml.append('tests="').append(suiteTests).append('" ')
                        suiteXml.append('failures="').append(suiteFailures).append('" ')
                        suiteXml.append('errors="').append(suiteErrors).append('" ')
                        suiteXml.append('time="').append(String.format("%.3f", suiteTime / 1000)).append('">\n')
                        testCases.each { testCase ->
                            suiteXml.append(testCase).append('\n')
                        }
                        suiteXml.append('  </testsuite>')
                        testSuites.add(suiteXml.toString())
                    }
                }
            }
        }
        
        // Build final XML
        xmlBuilder.append('<testsuites tests="').append(totalTests).append('" ')
        xmlBuilder.append('failures="').append(totalFailures).append('" ')
        xmlBuilder.append('errors="').append(totalErrors).append('" ')
        xmlBuilder.append('time="').append(String.format("%.3f", totalTime / 1000)).append('">\n')
        
        testSuites.each { suiteXml ->
            xmlBuilder.append(suiteXml).append('\n')
        }
        
        xmlBuilder.append('</testsuites>')
        
        // Write to file
        writeFile file: outputXmlPath, text: xmlBuilder.toString()
        echo "   ✅ Created JUnit XML with ${totalTests} test cases"
        echo "   📝 Test names include full descriptions (e.g., 'should login successfully when providing valid credentials')"
        
    } catch (Exception e) {
        echo "   ❌ Error converting JSON to JUnit XML: ${e.getMessage()}"
        echo "   Stack trace: ${e.getStackTrace().take(3).join('\n')}"
    }
}

def escapeXml(String text) {
    if (!text) return ''
    return text
        .replace('&', '&amp;')
        .replace('<', '&lt;')
        .replace('>', '&gt;')
        .replace('"', '&quot;')
        .replace("'", '&apos;')
}

def createGitHubCheckRun(String status, String conclusion, String summary) {
    if (!env.CHANGE_ID || !env.GITHUB_TOKEN) {
        echo "⚠️ Missing PR info or GitHub token. Skipping GitHub Check creation."
        return null
    }
    
    try {
        def repoOwner = env.GITHUB_REPO_OWNER
        def repoName = env.GITHUB_REPO_NAME
        def prSha = getPRHeadSha(env.CHANGE_ID)
        
        if (!prSha) {
            echo "⚠️ Could not get PR head SHA. Skipping check run creation."
            return null
        }
        
        def checkRunData = [
            name: 'continuous-integration/jenkins/pr-merge',
            head_sha: prSha,
            status: status,
            output: [
                title: status == 'in_progress' ? 'CI/CD pipeline is running' : 'CI/CD pipeline completed',
                summary: summary ?: 'Checking code quality and running tests...'
            ]
        ]
        
        if (conclusion) {
            checkRunData.conclusion = conclusion
        }
        
        def jsonBody = groovy.json.JsonOutput.toJson(checkRunData)
        
        def response = sh(
            script: """
                curl -s -w "\\nHTTP_CODE:%{http_code}" -X POST \
                    -H "Authorization: token ${env.GITHUB_TOKEN}" \
                    -H "Accept: application/vnd.github.v3+json" \
                    -H "Content-Type: application/json" \
                    https://api.github.com/repos/${repoOwner}/${repoName}/check-runs \
                    -d '${jsonBody}'
            """,
            returnStdout: true
        ).trim()
        
        def httpCode = response.split('HTTP_CODE:')[1] ?: 'unknown'
        def responseBody = response.split('HTTP_CODE:')[0] ?: ''
        
        if (httpCode == '201') {
            def checkRun = new groovy.json.JsonSlurper().parseText(responseBody)
            env.GITHUB_CHECK_RUN_ID = checkRun.id.toString()
            echo "✅ GitHub Check Run created: ${checkRun.id}"
            return checkRun.id
        } else {
            echo "⚠️ Failed to create check run: HTTP ${httpCode}"
            echo "   Response: ${responseBody.take(500)}"
            return null
        }
    } catch (Exception e) {
        echo "❌ Error creating GitHub Check Run: ${e.getMessage()}"
        return null
    }
}

def updateGitHubCheckRun(String conclusion, String title, String summary) {
    if (!env.CHANGE_ID || !env.GITHUB_TOKEN) {
        echo "⚠️ Missing PR info or GitHub token. Skipping GitHub Check update."
        return
    }
    
    try {
        def repoOwner = env.GITHUB_REPO_OWNER
        def repoName = env.GITHUB_REPO_NAME
        def prSha = getPRHeadSha(env.CHANGE_ID)
        def checkRunId = env.GITHUB_CHECK_RUN_ID
        
        if (!prSha) {
            echo "⚠️ Could not get PR head SHA. Skipping check run update."
            return
        }
        
        // If we don't have check run ID, try to find it by name
        if (!checkRunId) {
            checkRunId = findCheckRunId(prSha, 'continuous-integration/jenkins/pr-merge')
        }
        
        if (!checkRunId) {
            echo "⚠️ Could not find check run ID. Creating new check run..."
            createGitHubCheckRun('completed', conclusion, summary)
            env.GITHUB_CHECK_UPDATED = 'true'
            return
        }
        
        def checkRunData = [
            status: 'completed',
            conclusion: conclusion,
            output: [
                title: title,
                summary: summary ?: 'CI/CD pipeline completed'
            ]
        ]
        
        def jsonBody = groovy.json.JsonOutput.toJson(checkRunData)
        
        def response = sh(
            script: """
                curl -s -w "\\nHTTP_CODE:%{http_code}" -X PATCH \
                    -H "Authorization: token ${env.GITHUB_TOKEN}" \
                    -H "Accept: application/vnd.github.v3+json" \
                    -H "Content-Type: application/json" \
                    https://api.github.com/repos/${repoOwner}/${repoName}/check-runs/${checkRunId} \
                    -d '${jsonBody}'
            """,
            returnStdout: true
        ).trim()
        
        def httpCode = response.split('HTTP_CODE:')[1] ?: 'unknown'
        
        if (httpCode == '200') {
            echo "✅ GitHub Check Run updated: ${checkRunId} - ${conclusion}"
            env.GITHUB_CHECK_UPDATED = 'true'
        } else {
            echo "⚠️ Failed to update check run: HTTP ${httpCode}"
        }
    } catch (Exception e) {
        echo "❌ Error updating GitHub Check Run: ${e.getMessage()}"
    }
}

def findCheckRunId(String sha, String checkName) {
    try {
        def repoOwner = env.GITHUB_REPO_OWNER
        def repoName = env.GITHUB_REPO_NAME
        
        def response = sh(
            script: """
                curl -s -H "Authorization: token ${env.GITHUB_TOKEN}" \
                    -H "Accept: application/vnd.github.v3+json" \
                    https://api.github.com/repos/${repoOwner}/${repoName}/commits/${sha}/check-runs
            """,
            returnStdout: true
        ).trim()
        
        def checkRuns = new groovy.json.JsonSlurper().parseText(response)
        
        if (checkRuns.check_runs) {
            def checkRun = checkRuns.check_runs.find { it.name == checkName }
            if (checkRun) {
                return checkRun.id.toString()
            }
        }
        
        return null
    } catch (Exception e) {
        echo "⚠️ Error finding check run ID: ${e.getMessage()}"
        return null
    }
}

def parseJUnitXml(String xmlPath) {
    def results = [
        total: 0,
        passed: 0,
        failures: 0,
        errors: 0
    ]
    
    try {
        if (!fileExists(xmlPath)) {
            return results
        }
        
        def xmlContent = readFile(xmlPath)
        def xml = new XmlSlurper().parseText(xmlContent)
        
        xml.testsuite.each { suite ->
            def tests = suite.@tests.toInteger() ?: 0
            def failures = suite.@failures.toInteger() ?: 0
            def errors = suite.@errors.toInteger() ?: 0
            
            results.total += tests
            results.failures += failures
            results.errors += errors
            results.passed += (tests - failures - errors)
        }
        
        // Also check testsuites level
        if (xml.@tests) {
            results.total = xml.@tests.toInteger() ?: results.total
            results.failures = xml.@failures.toInteger() ?: results.failures
            results.errors = xml.@errors.toInteger() ?: results.errors
            results.passed = results.total - results.failures - results.errors
        }
        
    } catch (Exception e) {
        echo "⚠️ Error parsing JUnit XML: ${e.getMessage()}"
    }
    
    return results
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