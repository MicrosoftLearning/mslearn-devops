---
lab:
  topic: Intermediate
  title: "Set up and run functional tests"
  description: "Learn how to configure a CI pipeline for a .NET application that includes unit tests, integration tests, and functional tests."
---

# Set up and run functional tests

**Estimated time:** 20 minutes

You will learn how to configure a CI pipeline for a .NET application that includes unit tests, integration tests, and functional tests. You'll understand the different types of automated testing and how they fit into a continuous integration strategy.

## Before you start

You need:

- **Microsoft Edge** or an [Azure DevOps supported browser](https://docs.microsoft.com/azure/devops/server/compatibility)
- **Azure DevOps organization:** Create one at [Create an organization or project collection](https://docs.microsoft.com/azure/devops/organizations/accounts/create-organization) if you don't have one

## About software testing

Software of any complexity can fail in unexpected ways in response to changes. Testing after making changes is required for all but the most trivial applications. Manual testing is the slowest, least reliable, most expensive way to test software.

There are many kinds of automated tests for software applications:

- **Unit Tests:** Test a single part of your application's logic. They don't test how your code works with dependencies or infrastructure
- **Integration Tests:** Test how your code works with dependencies or infrastructure. They verify that your code's layers interact as expected when dependencies are fully resolved
- **Functional Tests:** Written from the user's perspective, they verify the correctness of the system based on its requirements

For more information about testing types, see [Test ASP.NET Core MVC apps](https://learn.microsoft.com/dotnet/architecture/modern-web-apps-azure/test-asp-net-core-mvc-apps).

## Create and configure the team project

First, you'll create an Azure DevOps project for this lab.

1. In your browser, open your Azure DevOps organization
2. Click **New Project**
3. Give your project the name **eShopOnWeb**
4. Leave other fields with defaults
5. Click **Create**

## Import the eShopOnWeb Git Repository

Next, you'll import the sample repository that contains the application code and test projects.

1. In your Azure DevOps organization, open the **eShopOnWeb** project
2. Click **Repos > Files**
3. Click **Import a Repository**
4. Select **Import**
5. In the **Import a Git Repository** window, paste this URL: `https://github.com/MicrosoftLearning/eShopOnWeb.git`
6. Click **Import**

The repository is organized this way:

- **.ado** folder contains Azure DevOps YAML pipelines
- **.devcontainer** folder contains setup to develop using containers
- **infra** folder contains Bicep & ARM infrastructure as code templates
- **.github** folder contains YAML GitHub workflow definitions
- **src** folder contains the .NET website used in the lab scenarios
- **tests** folder contains the different test projects (Unit, Integration, Functional)

7. Go to **Repos > Branches**
8. Hover on the **main** branch then click the ellipsis on the right
9. Click **Set as default branch**

## Setup Tests in CI pipeline

You'll configure a CI pipeline that includes different types of tests.

### Import the YAML build definition for CI

You'll add the YAML build definition that implements Continuous Integration.

1. Go to **Pipelines > Pipelines**
2. Click **New Pipeline** (or **Create Pipeline** if you don't have any pipelines)
3. Select **Azure Repos Git (YAML)**
4. Select the **eShopOnWeb** repository
5. Select **Existing Azure Pipelines YAML File**
6. Select the **main** branch and the **/.ado/eshoponweb-ci.yml** file
7. Click **Continue**

The CI definition consists of these tasks:

- **DotNet Restore:** Installs all project dependencies without storing them in source control
- **DotNet Build:** Builds a project and all its dependencies
- **DotNet Test:** .Net test driver used to execute unit tests
- **DotNet Publish:** Publishes the application and its dependencies to a folder for deployment
- **Publish Artifact - Website:** Publishes the app artifact and makes it available as a pipeline artifact
- **Publish Artifact - Bicep:** Publishes the infrastructure artifact and makes it available as a pipeline artifact

8. Click the **Save** button (not **Save and run**) to save the pipeline definition

You can find the **Save** button by clicking on the arrow to the right of the **Save and Run** button.

### Add tests to the CI pipeline

You'll add integration and functional tests to the CI Pipeline. Notice that Unit Tests are already part of the pipeline.

1. Edit the pipeline by pressing the **Edit** button
2. Add the Integration Tests task after the Unit Tests task:

   ```yaml
   - task: DotNetCoreCLI@2
     displayName: Integration Tests
     inputs:
       command: "test"
       projects: "tests/IntegrationTests/*.csproj"
   ```

   **Integration Tests** test how your code works with dependencies or infrastructure. Although it's good to encapsulate code that interacts with infrastructure like databases and file systems, you'll still have some of that code, and you'll want to test it. Additionally, you should verify that your code's layers interact as expected when your application's dependencies are fully resolved.

3. Add the Functional tests task after the Integration Tests task:

   ```yaml
   - task: DotNetCoreCLI@2
     displayName: Functional Tests
     inputs:
       command: "test"
       projects: "tests/FunctionalTests/*.csproj"
   ```

   **Functional Tests** are written from the user's perspective and verify the correctness of the system based on its requirements. Unlike integration tests that are written from the developer's perspective to verify that components work correctly together, functional tests validate the system's behavior from an end-user standpoint.

4. Click **Validate and Save**
5. If validation is successful, click **Save** again to commit the changes directly to the main branch

### Check the tests summary

Now you'll run the pipeline and examine the test results.

1. Click **Run**
2. From the **Run pipeline** tab, click **Run** again
3. Wait for the pipeline to start and complete the Build Stage successfully
4. Once completed, the **Tests** tab will appear as part of the pipeline run
5. Click on it to check the summary

   ![Screenshot of the tests summary](media/AZ400_M05_L09_Tests_Summary.png)

6. For more details, at the bottom of the page, the table shows a list of the different run tests

   ![Screenshot of the tests table](media/AZ400_M05_L09_Tests_Table.png)

> **Note**: If the table is empty, you need to reset the filters to see all the details about the tests run.

## Summary

In this lab, you learned how to set up and run different test types using Azure Pipelines and .NET. You configured a CI pipeline that includes:

- **Unit Tests:** Testing individual components in isolation
- **Integration Tests:** Testing how components work together with dependencies
- **Functional Tests:** Testing the system from the user's perspective

These different testing layers provide comprehensive coverage and help ensure code quality throughout your development lifecycle. Automated testing in CI/CD pipelines helps catch issues early and maintains confidence in your deployments.
