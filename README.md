# README: ThousandEyes Metrics Integration for AppDynamics

This repository contains two scripts for integrating ThousandEyes metrics with AppDynamics Machine Agent:
1. **HTTP Listener Version:** Utilizes the AppDynamics HTTP Listener for metrics ingestion.
2. **Extension Version:** Deploys as an extension within the Machine Agent’s `monitors` folder.

---

## Prerequisites
### General Requirements
- **ThousandEyes Account:** Ensure you have access to the ThousandEyes API.
- **AppDynamics Machine Agent:** Installed and running.
- **PowerShell 7 or higher** (for running the scripts).

### HTTP Listener Version
- Ensure the AppDynamics Machine Agent HTTP Listener is enabled. The listener must be active on the desired port (default: `8293`).

### Extension Version
- Create a folder on the `monitors`directory of the Machine Agent.
- The script, monitor.xml and the .bat file must be placed in the Machine Agent’s `monitors` directory.

---

## HTTP Listener Version

### Environment Variables
Set the following environment variables before running the script:

| Variable               | Description                                      |
|------------------------|--------------------------------------------------|
| `THOUSANDEYES_TOKEN`   | ThousandEyes API Bearer token                   |
| `THOUSANDEYES_AID`     | ThousandEyes Account Group ID                   |



### Machine Agent Command
Run the Machine Agent with the HTTP Listener enabled:

java -jar machineagent.jar -Dmetric.http.listener=true -Dmetric.http.listener.port=8293


Ensure the `machineagent.jar` is accessible from the working directory.

### Running the Script
Execute the script via PowerShell:

.\ThousandEyes_Metrics_HTTP_Listener.ps1

To execute it periodically, you must set a schedule task on windows or the equivalent on another OS

### Script Configuration
#### Variables:
- **`selectedTests`:** Define specific ThousandEyes tests to monitor (e.g., `@("Cnet")`). Leave blank (`@()`) to monitor all available tests.
- **`selectedMetrics`:** Define specific metrics to monitor (e.g., `@("totalTime", "responseTime")`). Leave blank to monitor all available metrics.
- **`allAvailableMetrics`:** Lists common metrics:
  - `totalTime`
  - `responseTime`
  - `dnsTime`
  - `connectTime`
  - `sslTime`
  - `waitTime`
  - `receiveTime`
  - `wireSize`

#### Notes:
- If `selectedMetrics` is left blank, the script will monitor metrics listed in `allAvailableMetrics`. However, if you specify a metric not in `allAvailableMetrics` but present in the ThousandEyes API response, it will still be monitored.

---

## Extension Version

### Placement
1. Place the script in the Machine Agent’s `monitors` folder:
   ```
   <MachineAgent_Directory>/monitors/ThousandEyesExtension/
   ```
2. Ensure the directory structure:
   ```
   monitors/
     <Folder you created>/
       ThousandEyes_Metrics_Extension.ps1
       monitor.xml
       run_thousandeyes_metrics.bat

   ```

### Environment Variables
Set the following variables:

| Variable               | Description                                      |
|------------------------|--------------------------------------------------|
| `THOUSANDEYES_TOKEN`   | ThousandEyes API Bearer token                   |
| `THOUSANDEYES_AID`     | ThousandEyes Account Group ID                   |




### Running the Script Automatically
The Machine Agent will automatically pick up and execute scripts placed in the `monitors` folder.

### Script Configuration
#### Variables:
- **`selectedTests`:** Define specific ThousandEyes tests to monitor (e.g., `@("Cnet")`). Leave blank (`@()`) to monitor all available tests.
- **`selectedMetrics`:** Define specific metrics to monitor (e.g., `@("totalTime", "responseTime")`). Leave blank to monitor all available metrics.
- **`allAvailableMetrics`:** Lists common metrics:
  - `totalTime`
  - `responseTime`
  - `dnsTime`
  - `connectTime`
  - `sslTime`
  - `waitTime`
  - `receiveTime`
  - `wireSize`

#### Notes:
- If `selectedMetrics` is left blank, the script will monitor metrics listed in `allAvailableMetrics`. However, if you specify a metric not in `allAvailableMetrics` but present in the ThousandEyes API response, it will still be monitored.

---

## Monitoring Behavior
- **Blank Selections:** If `selectedTests` or `selectedMetrics` are left blank, the script monitors all available tests and metrics from `allAvailableMetrics`.
- **Custom Metrics:** Metrics are sent to AppDynamics under the custom metric path on the Controller Servers tab:
  ```
  Application Infrastructure Performance|Root|Individual Nodes|<Server-name>|Custom Metrics|ThousandEyes|Tests|<TestName>
  ```
  Averages appear under:
  ```
  Application Infrastructure Performance|Root|Individual Nodes|<Server-name>|Custom Metrics|ThousandEyes|AverageTests|<TestName>
  ```

---

## Troubleshooting
1. **HTTP Listener Errors:**
   - Ensure the HTTP Listener is running by sending a test request:
     ```
     curl -X POST http://localhost:8293/api/v1/metrics -d '{}'
     ```

2. **Script Errors:**
   - Check PowerShell error logs for issues.
   - Ensure API credentials and test configurations are correct.

3. **Metrics Not Showing in AppDynamics:**
   - Verify the `machine-agent.log` file for any errors.
   - Ensure the custom metric paths match AppDynamics configuration.

---

