pipeline {
    agent any

    environment {
        NODE_BIN = '/Users/phinguyen/.nvm/versions/node/v20.19.6/bin'
        PATH = "/Users/phinguyen/.nvm/versions/node/v20.19.6/bin:${env.PATH}"
        GITHUB_TOKEN = credentials('github-token')
        AUTOMATION_TEST_JOB = 'tmc-nocode-survey-autotest'
        GITHUB_REPO_OWNER = 'tms-minhnguyen'
        GITHUB_REPO_NAME = 'FE-Test-CI-CD'
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

        stage('Create GitHub Check (In Progress)') {
            when {
                expression { 
                    return env.CHANGE_ID != null
                }
            }
            steps {
                script {
                    echo "🔄 Creating GitHub Check with 'in_progress' status..."
                    echo "   This will disable merge button while tests are running"
                    
                    try {
                        def owner = env.GITHUB_REPO_OWNER
                        def repo = env.GITHUB_REPO_NAME
                        def sha = sh(
                            script: 'git rev-parse HEAD',
                            returnStdout: true
                        ).trim()
                        
                        def checkRunData = [
                            name: 'Automation Tests',
                            head_sha: sha,
                            status: 'in_progress',
                            started_at: new Date().format("yyyy-MM-dd'T'HH:mm:ss'Z'", TimeZone.getTimeZone('UTC')),
                            output: [
                                title: 'Running automation tests...',
                                summary: 'Waiting for test results to complete.'
                            ]
                        ]
                        
                        def apiUrl = "https://api.github.com/repos/${owner}/${repo}/check-runs"
                        def jsonBody = groovy.json.JsonOutput.toJson(checkRunData)
                        
                        writeFile file: 'github-check-in-progress.json', text: jsonBody
                        
                        def response = sh(
                            script: """
                                curl -s -w "\\nHTTP_CODE:%{http_code}" \
                                    -X POST \
                                    -H "Authorization: token ${env.GITHUB_TOKEN}" \
                                    -H "Accept: application/vnd.github.v3+json" \
                                    -H "Content-Type: application/json" \
                                    -d @github-check-in-progress.json \
                                    ${apiUrl}
                            """,
                            returnStdout: true
                        )
                        
                        def httpCode = response.split('HTTP_CODE:')[1]?.trim()
                        def responseBody = response.split('HTTP_CODE:')[0]?.trim()
                        
                        if (httpCode == '201' || httpCode == '200') {
                            def checkRun = new groovy.json.JsonSlurper().parseText(responseBody)
                            env.GITHUB_CHECK_RUN_ID = "${checkRun.id}"
                            echo "✅ GitHub Check created with ID: ${checkRun.id}"
                            echo "   Status: in_progress"
                            echo "   Merge button is now disabled until tests complete"
                        } else {
                            echo "⚠️ Failed to create GitHub Check. HTTP ${httpCode}"
                            echo "   Response: ${responseBody.take(500)}"
                            echo "   Continuing build anyway..."
                        }
                    } catch (Exception e) {
                        echo "⚠️ Error creating GitHub Check: ${e.getMessage()}"
                        echo "   Continuing build anyway..."
                    }
                }
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
                            
                            if (testResult == 'FAILURE') {
                                echo "❌ Automation tests failed!"
                                echo "   Test Job: ${testUrl}"
                                echo "   This build will be marked as FAILURE"
                                currentBuild.result = 'FAILURE'
                            } else if (testResult == 'UNSTABLE') {
                                echo "⚠️ Automation tests completed with warnings"
                            } else if (testResult == 'SUCCESS') {
                                echo "✅ All automation tests passed"
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
                    
                    // Check if automation test job failed
                    def automationTestFailed = false
                    if (env.AUTOMATION_TEST_JOB_BUILD_NUMBER) {
                        try {
                            def testJobName = env.AUTOMATION_TEST_JOB_NAME ?: env.AUTOMATION_TEST_JOB
                            def testBuildNumber = env.AUTOMATION_TEST_JOB_BUILD_NUMBER
                            def testJob = Jenkins.instance.getItemByFullName(testJobName)
                            if (testJob) {
                                def testBuild = testJob.getBuildByNumber(testBuildNumber.toInteger())
                                if (testBuild && testBuild.result == hudson.model.Result.FAILURE) {
                                    automationTestFailed = true
                                    echo "❌ Automation test job failed - this build will be marked as FAILURE"
                                }
                            }
                        } catch (Exception e) {
                            echo "⚠️ Could not check automation test job status: ${e.getMessage()}"
                        }
                    }
                    
                    try {
                        if (fileExists('test-results/junit.xml')) {
                            echo "✅ Found JUnit XML file, publishing to GitHub Checks..."
                            
                            // If we created a check earlier, update it; otherwise let Warnings Plugin create one
                            if (env.GITHUB_CHECK_RUN_ID) {
                                echo "   Updating existing GitHub Check (ID: ${env.GITHUB_CHECK_RUN_ID})"
                                // Warnings Plugin will update the check automatically when publishChecks is true
                                // But we need to ensure it uses the same check run ID
                            }
                            
                            // Use Warnings Plugin to parse JUnit XML and publish to GitHub Checks
                            // qualityGates will ensure check status is "failure" if any test fails
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
                            
                            // If automation test failed, ensure build fails (this will also fail the GitHub Check)
                            if (automationTestFailed) {
                                echo "❌ Failing build due to automation test failures"
                                echo "   This will mark the GitHub Check as 'failure' and disable merge button"
                                
                                // Update the check to failure status if we created it earlier
                                if (env.GITHUB_CHECK_RUN_ID) {
                                    updateGitHubCheckStatus('failure', 'Automation tests failed')
                                }
                                
                                currentBuild.result = 'FAILURE'
                                error("Automation tests failed - see ${env.JENKINS_URL}job/${env.AUTOMATION_TEST_JOB_NAME}/${env.AUTOMATION_TEST_JOB_BUILD_NUMBER}/")
                            } else {
                                // Update check to success if we created it earlier
                                if (env.GITHUB_CHECK_RUN_ID) {
                                    updateGitHubCheckStatus('success', 'All automation tests passed')
                                }
                            }
                        } else {
                            echo "⚠️ JUnit XML file not found at test-results/junit.xml"
                            
                            // If automation test failed but no JUnit XML, still fail
                            if (automationTestFailed) {
                                echo "❌ Automation tests failed but no JUnit XML found"
                                echo "   Failing build to prevent merge"
                                currentBuild.result = 'FAILURE'
                                error("Automation tests failed - see ${env.JENKINS_URL}job/${env.AUTOMATION_TEST_JOB_NAME}/${env.AUTOMATION_TEST_JOB_BUILD_NUMBER}/")
                            } else {
                                echo "   Skipping GitHub Checks publication"
                                echo "   Make sure Automation job generates JUnit XML file"
                            }
                        }
                        
                    } catch (Exception e) {
                        echo "❌ Error publishing test results to GitHub Checks: ${e.getMessage()}"
                        echo "   Stack trace: ${e.getStackTrace().take(3).join('\n')}"
                        
                        // If automation test failed, still fail the build
                        if (automationTestFailed) {
                            echo "❌ Failing build due to automation test failures"
                            currentBuild.result = 'FAILURE'
                            error("Automation tests failed - see ${env.JENKINS_URL}job/${env.AUTOMATION_TEST_JOB_NAME}/${env.AUTOMATION_TEST_JOB_BUILD_NUMBER}/")
                        } else {
                            echo "   Continuing build..."
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
            // Handle nested suites structure
            def specsToProcess = []
            if (suite.specs) {
                if (suite.specs instanceof List) {
                    specsToProcess = suite.specs
                } else {
                    specsToProcess = [suite.specs]
                }
            } else if (suite.suites) {
                // Try nested suites
                def nestedSuites = suite.suites instanceof List ? suite.suites : [suite.suites]
                nestedSuites.each { nestedSuite ->
                    if (nestedSuite.specs) {
                        if (nestedSuite.specs instanceof List) {
                            specsToProcess.addAll(nestedSuite.specs)
                        } else {
                            specsToProcess.add(nestedSuite.specs)
                        }
                    }
                }
            }
            
            if (specsToProcess && !specsToProcess.isEmpty()) {
                specsToProcess.each { spec ->
                    def suiteName = spec.title ?: spec.file ?: 'Unknown Suite'
                    def suiteTests = 0
                    def suiteFailures = 0
                    def suiteErrors = 0
                    def suiteTime = 0
                    def testCases = []
                    
                    def testsToProcess = []
                    if (spec.tests) {
                        if (spec.tests instanceof List) {
                            testsToProcess = spec.tests
                        } else {
                            testsToProcess = [spec.tests]
                        }
                    }
                    
                    if (testsToProcess && !testsToProcess.isEmpty()) {
                        testsToProcess.each { test ->
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
                            
                            // Get full test name (description) - try multiple sources
                            def testName = test.title
                            if (!testName && test.titlePath) {
                                // titlePath is array, get last element
                                if (test.titlePath instanceof List && !test.titlePath.isEmpty()) {
                                    testName = test.titlePath[test.titlePath.size() - 1]
                                } else if (test.titlePath instanceof String) {
                                    // Parse titlePath string like " > frontend-chromium > ... > Test Name"
                                    def parts = test.titlePath.split(' > ')
                                    if (parts.length > 0) {
                                        testName = parts[parts.length - 1].trim()
                                    }
                                }
                            }
                            if (!testName) {
                                testName = 'Unknown test'
                            }
                            
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

def updateGitHubCheckStatus(String conclusion, String summary) {
    if (!env.GITHUB_CHECK_RUN_ID) {
        echo "⚠️ No GitHub Check Run ID found, skipping update"
        return
    }
    
    try {
        def owner = env.GITHUB_REPO_OWNER
        def repo = env.GITHUB_REPO_NAME
        def checkRunId = env.GITHUB_CHECK_RUN_ID
        def sha = sh(
            script: 'git rev-parse HEAD',
            returnStdout: true
        ).trim()
        
        def checkRunData = [
            status: 'completed',
            conclusion: conclusion,
            completed_at: new Date().format("yyyy-MM-dd'T'HH:mm:ss'Z'", TimeZone.getTimeZone('UTC')),
            output: [
                title: conclusion == 'success' ? 'All automation tests passed' : 'Automation tests failed',
                summary: summary
            ]
        ]
        
        def apiUrl = "https://api.github.com/repos/${owner}/${repo}/check-runs/${checkRunId}"
        def jsonBody = groovy.json.JsonOutput.toJson(checkRunData)
        
        writeFile file: 'github-check-update.json', text: jsonBody
        
        def response = sh(
            script: """
                curl -s -w "\\nHTTP_CODE:%{http_code}" \
                    -X PATCH \
                    -H "Authorization: token ${env.GITHUB_TOKEN}" \
                    -H "Accept: application/vnd.github.v3+json" \
                    -H "Content-Type: application/json" \
                    -d @github-check-update.json \
                    ${apiUrl}
            """,
            returnStdout: true
        )
        
        def httpCode = response.split('HTTP_CODE:')[1]?.trim()
        def responseBody = response.split('HTTP_CODE:')[0]?.trim()
        
        if (httpCode == '200') {
            echo "✅ GitHub Check updated to status: ${conclusion}"
        } else {
            echo "⚠️ Failed to update GitHub Check. HTTP ${httpCode}"
            echo "   Response: ${responseBody.take(200)}"
        }
    } catch (Exception e) {
        echo "⚠️ Error updating GitHub Check: ${e.getMessage()}"
    }
}

