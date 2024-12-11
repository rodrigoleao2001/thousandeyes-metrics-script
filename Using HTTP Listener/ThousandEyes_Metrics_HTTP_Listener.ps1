# Set your ThousandEyes Bearer token
$token = $Env:THOUSANDEYES_TOKEN  # Define the environment variable for your token
$aid = $Env:THOUSANDEYES_AID    # Define the environment variable for your Account Group ID

$endPointTestUrl = "https://api.thousandeyes.com/v7/endpoint/tests/scheduled-tests/http-server?aid=$aid"

# Define metrics and test selection criteria
$selectedTests = @("Cnet")     # Replace with your preferred test names or IDs
$selectedMetrics = @("totalTime", "responseTime") # Replace with metrics you want to monitor

# Define how many test results to retrieve (0 = retrieve all available results)
$testResultsToRetrieve = 5

# Default metrics if none are selected
$allAvailableMetrics = @("totalTime", "responseTime", "dnsTime", "connectTime", "sslTime", "waitTime", "receiveTime", "wireSize")

Write-Output "Retrieving ThousandEyes tests..."
try {
    $headers = @{
        Authorization = "Bearer $token"
        Accept = "application/json"
        "User-Agent" = "PowerShell/7.0"
        "Content-Type" = "application/x-www-form-urlencoded"
    }
    $endpointTestResponse = Invoke-RestMethod -Uri $endPointTestUrl -Method Get -Headers $headers
    Write-Output "ThousandEyes tests retrieved successfully."
} catch {
    Write-Output "Error retrieving ThousandEyes tests: $_"
    exit 1
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

# Function to post metrics to AppDynamics
function PostMetricToAppD {
    param(
        [string]$metricPath,    # Metric path in AppDynamics
        [string]$metricName,    # Metric name
        [double]$metricValue    # Metric value
    )

    $metricFullName = "$metricPath|$metricName"
    $metricData = @(
        @{
            "metricName"     = $metricFullName
            "aggregatorType" = "OBSERVATION"
            "value"          = $metricValue
        }
    )

    $json = '[ ' + ($metricData | ConvertTo-Json -Depth 4) + ' ]'

    Write-Output "Sending metric '$metricFullName' with value $metricValue to the Machine Agent HTTP Listener..."

    try {
        $response = Invoke-WebRequest -Uri 'http://localhost:8293/api/v1/metrics' -Method POST -Body $json -ContentType 'application/json'
        if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 204) {
            Write-Output "Metric '$metricFullName' sent successfully."
        } else {
            Write-Output "Failed to send metric '$metricFullName'. Status Code: $($response.StatusCode)"
        }
    } catch {
        Write-Output "Error sending metric '$metricFullName': $_"
    }
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

    # Retrieve the specified number of results or all results if $testResultsToRetrieve -eq 0
    $resultsToProcess = if ($testResultsToRetrieve -eq 0) {
        $testResultResponse.results
    } else {
        $testResultResponse.results | Select-Object -First $testResultsToRetrieve
    }

    # Initialize a dictionary to calculate averages
    $metricAverages = @{}
    foreach ($metric in $selectedMetrics) {
        $metricAverages[$metric] = 0
    }

    foreach ($result in $resultsToProcess) {
        foreach ($metric in $selectedMetrics) {
            if ($result.PSObject.Properties.Name -contains $metric) {
                $metricValue = $result.$metric
                if ($metricValue -is [int] -or $metricValue -is [double] -or $metricValue -is [float]) {
                    # Post individual metrics to AppDynamics
                    PostMetricToAppD -metricPath "Custom Metrics|ThousandEyes|Tests|$($testName)" -metricName $metric -metricValue $metricValue

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

    # Calculate and post averages to AppDynamics
    foreach ($metric in $selectedMetrics) {
        if ($resultsToProcess.Count -gt 0) {
            $averageValue = $metricAverages[$metric] / $resultsToProcess.Count
            $averageValue = [math]::Round($averageValue, 2) # Round to 2 decimal places

            PostMetricToAppD -metricPath "Custom Metrics|ThousandEyes|AverageTests|$($testName)" -metricName "avg$($metric)" -metricValue $averageValue
        }
    }
}
