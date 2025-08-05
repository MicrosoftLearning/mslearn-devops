---
lab:
  topic: Basic
  title: "Implement Real-Time Monitoring with Azure Monitor"
  description: "Learn how to implement comprehensive monitoring and observability for applications using Azure Monitor and Application Insights."
---

# Implement Real-Time Monitoring with Azure Monitor

In this lab, you will implement real-time monitoring for a web application using Azure Monitor and Application Insights. This will help you gain insights into application performance, detect anomalies, and ensure the reliability of your services.

You will learn how to:

- Create a sample web app.
- Enable and configure Azure Monitor and Application Insights.
- Create custom dashboards to visualize application metrics.
- Set up alerts to notify stakeholders of performance anomalies.
- Analyze performance data for potential improvements.

This lab takes approximately **20** minutes to complete.

## Before you start

To complete the lab, you need:

- An active Azure subscription. If you don't have one, you can create a free account at [Azure Free Account](https://azure.microsoft.com/free).
- Basic knowledge of monitoring and observability concepts.
- Basic understanding of Azure services.

## Create a sample web application

In this exercise, you will create a sample web application in Azure App Service and enable Application Insights for monitoring.

### Create an Azure Web App

1. Open the Azure portal.
1. In the Search bar, type App Services and select it.
1. Select + Create and select Web App.
1. In the Basics tab:
   - Subscription: Select your Azure subscription.
   - Resource Group: Select Create new, enter **`monitoringlab-rg`**, and select OK.
   - Name: Enter a unique name, such as **`monitoringlab-webapp`**.
   - Publish: Select Code.
   - Runtime stack: Choose .NET 8 (LTS).
   - Region: Select a region close to you.
1. Select Review + create, then select Create.
1. Wait for deployment to complete, then select "Go to resource".
1. In the Overview tab, select the URL to verify the web app is running.

### Verify Application Insights

1. In the Web App resource, in the left panel, expand the Monitoring section and select Application Insights.
1. Application Insights is already enabled for this web app. Select the link to open the Application Insights resource.
1. In the Application Insights resource, select **Application Dashboard** to view the performance data the default dashboard provided.

   > **Note:** The dashboard may take a few moments to fully load and display all performance data. Wait for the dashboard to completely render before proceeding to ensure optimal experience in subsequent exercises.

## Configure Azure Monitor and dashboards

### Access Azure Monitor

1. In the Azure portal, search for Monitor and select **Monitor**.
1. Select Metrics in the left panel.
1. In the Scope section, select the web app under the subscription and resource group where you deployed the web app.
1. Select Apply and observe the metrics available for the web app.

### Add key metrics to the dashboard

1. In the Scope section, select your Web App (monitoringlab-webapp).
1. Under Metric, choose Response Time.
1. Set the Aggregation to Average and select + Add metric.
1. Repeat the process for additional metrics:
   - CPU Time (Count)
   - Requests (Average)
1. In the metrics chart area, select the **Pin to dashboard** button (pin icon) in the top-right corner of the chart.
1. In the **Pin to dashboard** dialog that appears:
   - Select **New** to create a new dashboard
   - Enter a dashboard name: **`MonitoringLab Dashboard`**
   - Choose **Shared** for dashboard type
   - Select the appropriate subscription
   - Select **Create and pin**
1. After the dashboard is created and the metrics are pinned, select **Save** in the top menu to save the dashboard.
1. Navigate to the dashboard by selecting the **Dashboard** icon in the left panel of the Azure portal, or search for "Dashboard" in the top search bar.
1. Select your newly created **MonitoringLab Dashboard** from the dashboard list.
1. Verify the metrics are displayed on the dashboard and are updating in real-time.

## Create alerts

### Define alert conditions and actions

1. In Azure Monitor, select Alerts.
1. Select + Create and select Alert rule.
1. Under Scope, select your Web App (monitoringlab-webapp) and select Apply.
1. Under Condition, select in the Signal name field and select Response Time.
1. Configure the alert rule:
   - Threshold type: Dynamic
   - Aggregation type: Average
   - Value is: Greater or Less than
   - Threshold Sensitivity: High
   - When to evaluate: Check every 1 minutes and look back at 5 minutes.
1. Under Actions, select Use quick actions.
1. Enter:
   - Action group name: WebAppMonitoringAlerts
   - Display name: WebAlert
   - Email: Enter your email address.
1. Select Save.
1. Select Next: Details.
1. Enter a Name `WebAppResponseTimeAlert` and select a Severity level Verbose.
1. Select Review + create and then Create.

   > **Note:** Your alert rule is now created and will trigger an email notification when the response time exceeds the threshold. You can force the alert to trigger by sending a large number of requests to the web app. For example, you can use Azure Load testing or a tool like Apache JMeter.

1. Go back to the Azure Monitor > Alerts.
1. Select **Alert rules** and you should see the alert rule you created.

## Analyze performance data

### Review Collected Metrics

1. Go to Application Insights in the Azure portal.
1. Select **Application Dashboard**.
1. Select the **Performance** tile to analyze server response times and load. You can also view the number of requests and failed requests.
1. Select **Analyze with Workbooks** and select **Performance Counter Analysis**.
1. Select **Workbooks**.
1. Select the workbook **Performance Analysis** under Performance.
1. You can see the performance data for the web app.

> **Note:** You can customize the workbook to include additional metrics and filters.

## Clean up resources

Now that you finished the exercise, you should delete the cloud resources you created to avoid unnecessary resource usage.

1. In your browser navigate to the Azure portal [https://portal.azure.com](https://portal.azure.com); signing in with your Azure credentials if prompted.
1. Navigate to the resource group you created and view the contents of the resources used in this exercise.
1. On the toolbar, select **Delete resource group**.
1. Enter the resource group name and confirm that you want to delete it.

> **CAUTION:** Deleting a resource group deletes all resources contained within it. If you chose an existing resource group for this exercise, any existing resources outside the scope of this exercise will also be deleted.
