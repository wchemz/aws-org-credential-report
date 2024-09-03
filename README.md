# AWS Organization Credential Report Automation

## Overview

This repository contains a Bash script (`OrganizationCredentialReport.sh`) and an AWS CloudFormation template (`OrganizationCredentialReportRole.yaml`) designed to automate the process of generating and retrieving IAM credential reports across all accounts within an AWS Organization. The CloudFormation template is used to create an IAM role in each account, which is then assumed by the script to generate and download credential reports.

## Files

- **OrganizationCredentialReport.sh**: 
  - The main Bash script that automates the deployment of the IAM roles and the collection of IAM credential reports from each AWS account in the organization.

- **OrganizationCredentialReportRole.yaml**: 
  - The CloudFormation template used to create the IAM role in each account within the AWS Organization. This role allows the script to assume the necessary permissions to generate and download the IAM credential report.

## Prerequisites

- **AWS CLI**: Ensure that the AWS CLI is installed and configured with sufficient permissions to create StackSets and assume roles across the organization.
- **jq**: The script uses `jq` for JSON processing. Make sure `jq` is installed on your system.
- **AWS Organization**: The script assumes that you are using AWS Organizations and that you have the necessary permissions to manage roles across all member accounts.

## Usage

1. **Customize the CloudFormation Template**:
   - Modify `OrganizationCredentialReportRole.yaml` as needed to fit your organization's security and compliance policies.

2. **Run the Script**:
   - Execute the `OrganizationCredentialReport.sh` script. This script will:
     - Deploy the IAM role to all accounts using AWS CloudFormation StackSets.
     - Assume the created role in each account to generate and retrieve the IAM credential report.
     - Save the credential report as a CSV file for each account.

3. **Monitor Execution**:
   - The script includes logging and error handling to help you monitor the progress of the operations. You can adjust settings such as concurrency and failure tolerance based on the size and requirements of your organization.

## Customization

- **Concurrency and Failure Tolerance**:
  - The script includes options to adjust the concurrency of operations and the failure tolerance. This can be configured by modifying the script's `--operation-preferences` settings.

- **Role Name**:
  - The IAM role name is defined in both the script and the CloudFormation template. Ensure that they match if you modify the role name.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- This automation process leverages AWS CloudFormation, AWS Organizations, and the AWS CLI to manage resources efficiently across multiple AWS accounts.
