# ThousandEyes Metrics Extension for AppDynamics Machine Agent
# This script retrieves metrics from the ThousandEyes API and outputs them in the format required by the AppDynamics Machine Agent.

# Environment Variables:
# Ensure the following environment variables are set:
# - THOUSANDEYES_TOKEN: ThousandEyes API Bearer token
# - THOUSANDEYES_AID: ThousandEyes Account Group ID

# Retrieve ThousandEyes credentials from environment variables
$token = $Env:THOUSANDEYES_TOKEN
$aid = $Env:THOUSANDEYES_AID

# Validate if required environment variables are set
if (-not $token -or -not $aid) {
    Write-Output "Error: Missing required environment variables. Ensure THOUSANDEYES_TOKEN and THOUSANDEYES_AID are set."
    exit 1
}

# Define API endpoints
$endPointTestUrl = "https://api.thousandeyes.com/v7/endpoint/tests/scheduled-tests/http-server?aid=$aid"

# Define available metrics
$allAvailableMetrics = @(
    "totalTime",
    "responseTime",
    "dnsTime",
    "connectTime",
    "sslTime",
    "waitTime",
    "receiveTime",
    "wireSize"
)

# Define selected metrics (leave empty to include all available metrics)
$selectedMetrics = @()

# Define selected tests (leave empty to include all available tests)
$selectedTests = @("Cnet") # Replace with your preferred test names or IDs

# Define how many test results to retrieve (0 = retrieve all available results)
$testResultsToRetrieve = 0

# Use all available metrics if none are selected
if ($selectedMetrics.Count -eq 0) {
    $metricsToProcess = $allAvailableMetrics
    Write-Output "No specific metrics selected. Processing all available metrics."
} else {
    $metricsToProcess = $selectedMetrics
    Write-Output "Processing selected metrics: $($metricsToProcess -join ', ')"
}

# Fetch ThousandEyes tests
try {
    $headers = @{
        Authorization = "Bearer $token"
        Accept = "application/json"
        "User-Agent" = "PowerShell/7.0"
    }

    $endpointTestResponse = Invoke-RestMethod -Uri $endPointTestUrl -Method Get -Headers $headers
    if ($endpointTestResponse.tests.Count -eq 0) {
        Write-Output "No tests retrieved from ThousandEyes API. Exiting."
        exit 1
    }
    Write-Output "ThousandEyes tests retrieved successfully."
} catch {
    Write-Output "Error retrieving ThousandEyes tests: $_"
    exit 1
}

# Debugging: Output all available tests
Write-Output "Available Tests:"
foreach ($test in $endpointTestResponse.tests) {
    Write-Output "Test ID: $($test.testId), Test Name: $($test.testName), Type: $($test.type)"
}

# Filter tests based on selection criteria
$filteredTests = $endpointTestResponse.tests | Where-Object {
    if ($selectedTests.Count -eq 0) {
        $true
    } else {
        ($selectedTests -contains $_.testId) -or ($selectedTests -contains $_.testName.Trim())
    }
}

if (-not $filteredTests -or $filteredTests.Count -eq 0) {
    Write-Output "No tests match the selection criteria. Exiting."
    exit 1
}

# Iterate over selected tests to retrieve and process metrics
foreach ($test in $filteredTests) {
    $testId = $test.testId
    $testName = $test.testName
    Write-Output "Retrieving metrics for Test ID: $($testId), Test Name: $($testName)..."

    $testResultUrl = "https://api.thousandeyes.com/v7/endpoint/test-results/scheduled-tests/$testId/http-server?aid=$aid"

    try {
        $testResultResponse = Invoke-RestMethod -Uri $testResultUrl -Method Get -Headers $headers
        if ($testResultResponse.results.Count -eq 0) {
            Write-Output "No recent results available for Test ID: $($testId)"
            continue
        }
    } catch {
        Write-Output "Error retrieving test results for Test ID: $($testId): $_"
        continue
    }

    # Retrieve the specified number of results or all results if $testResultsToRetrieve is 0
    $resultsToProcess = if ($testResultsToRetrieve -eq 0) {
        $testResultResponse.results
    } else {
        $testResultResponse.results | Select-Object -First $testResultsToRetrieve
    }

    # Initialize a dictionary to calculate averages
    $metricAverages = @{}
    foreach ($metric in $metricsToProcess) {
        $metricAverages[$metric] = 0
    }

foreach ($result in $resultsToProcess) {
    foreach ($metric in $metricsToProcess) {
        if ($result.PSObject.Properties.Name -contains $metric) {
            $metricValue = $result.$metric
            if ($metricValue -is [int] -or $metricValue -is [double] -or $metricValue -is [float]) {
                # Convert metric value to integer
                $metricValue = [math]::Round($metricValue)

                # Output individual metric in required format
                $metricPath = "Custom Metrics|ThousandEyes|Tests|$($testName)|$($metric)"
                $aggregator = "OBSERVATION"
                $timeRollup = "AVERAGE"
                $clusterRollup = "INDIVIDUAL"
                Write-Output "name=$metricPath,value=$metricValue,aggregator=$aggregator,time-rollup=$timeRollup,cluster-rollup=$clusterRollup"

                # Accumulate for averages
                $metricAverages[$metric] += $metricValue
            } else {
                Write-Output "Metric '$metric' for Test ID: $($testId) is non-numeric. Skipping."
            }
        } else {
            Write-Output "Metric '$metric' is missing for Test ID: $($testId). Skipping."
        }
    }
}

foreach ($metric in $metricsToProcess) {
    if ($resultsToProcess.Count -gt 0) {
        $averageValue = $metricAverages[$metric] / $resultsToProcess.Count
        # Convert average value to integer
        $averageValue = [math]::Round($averageValue)

        $metricPath = "Custom Metrics|ThousandEyes|AverageTests|$($testName)|avg$($metric)"
        $aggregator = "AVERAGE"
        $timeRollup = "AVERAGE"
        $clusterRollup = "INDIVIDUAL"
        Write-Output "name=$metricPath,value=$averageValue,aggregator=$aggregator,time-rollup=$timeRollup,cluster-rollup=$clusterRollup"
    }
}

}

exit 0
