#!/bin/bash
# Get the org id
ORG_ID=$(aws organizations list-roots --query 'Roots[0].Id' --output text)
echo "Organization ID: $ORG_ID"

MANAGEMENT_ACCOUNT_ID=$(aws organizations describe-organization --query 'Organization.MasterAccountId' --output text)
echo "Management Account ID: $MANAGEMENT_ACCOUNT_ID"

aws cloudformation create-stack-set \
  --stack-set-name OrganizationCredentialReportRoleStackSet \
  --template-body file://OrganizationCredentialReportRole.yaml \
  --parameters ParameterKey=ManagementAccountId,ParameterValue=$MANAGEMENT_ACCOUNT_ID \
  --capabilities CAPABILITY_NAMED_IAM \
  --permission-model SERVICE_MANAGED \
  --auto-deployment Enabled=true,RetainStacksOnAccountRemoval=false

# Create stack instances with MaxConcurrentCount and get the OperationId
CREATE_OPERATION_ID=$(aws cloudformation create-stack-instances \
  --stack-set-name OrganizationCredentialReportRoleStackSet \
  --regions us-east-1 \
  --deployment-targets OrganizationalUnitIds=$ORG_ID \
  --operation-preferences FailureToleranceCount=10,MaxConcurrentCount=10,ConcurrencyMode=SOFT_FAILURE_TOLERANCE \
  --query 'OperationId' --output text)

# Wait for the stack instances to be created by checking the operation status
while true; do
  OPERATION_STATUS=$(aws cloudformation describe-stack-set-operation \
    --stack-set-name OrganizationCredentialReportRoleStackSet \
    --operation-id $CREATE_OPERATION_ID \
    --query 'StackSetOperation.Status' --output text)

  echo "Current operation status: $OPERATION_STATUS"

  if [ "$OPERATION_STATUS" == "SUCCEEDED" ]; then
    echo "Stack instances created successfully."
    break
  elif [ "$OPERATION_STATUS" == "FAILED" ]; then
    echo "Failed to create stack instances. Exiting."
    exit 1
  else
    echo "Waiting for stack instances creation to complete..."
    sleep 15
  fi
done

# Define the role name to be assumed in each account
ROLE_NAME="OrganizationCredentialReportRole"

# Get the list of account IDs in the organization
ACCOUNTS=$(aws organizations list-accounts --query 'Accounts[*].Id' --output text)

for ACCOUNT_ID in $ACCOUNTS; do
  echo "Processing account: $ACCOUNT_ID"

  if [ "$ACCOUNT_ID" == "$MANAGEMENT_ACCOUNT_ID" ]; then
    echo "Account ID is the same as Management Account ID. Generate the credential report."
    
    # Generate the credential report directly
    aws iam generate-credential-report
    
    # Wait for the report to be generated (this can take a few seconds)
    sleep 5

    # Get the credential report and save it to a CSV file
    aws iam get-credential-report --query 'Content' --output text | base64 --decode > credential_report_$ACCOUNT_ID.csv
  else
    # Assume the created role in the member account
    CREDS=$(aws sts assume-role --role-arn arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME --role-session-name "GetCredentialReportSession")

    export AWS_ACCESS_KEY_ID=$(echo $CREDS | jq -r '.Credentials.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | jq -r '.Credentials.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo $CREDS | jq -r '.Credentials.SessionToken')

    # Generate the credential report
    aws iam generate-credential-report
    
    # Wait for the report to be generated (this can take a few seconds)
    sleep 5

    # Get the credential report and save it to a CSV file
    aws iam get-credential-report --query 'Content' --output text | base64 --decode > credential_report_$ACCOUNT_ID.csv

    # Unset the temporary credentials
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_TOKEN
  fi

  echo "Credential report saved for account: $ACCOUNT_ID"
done

echo "All reports have been generated and saved."

# Delete stack instances with MaxConcurrentCount and get the OperationId
DELETE_OPERATION_ID=$(aws cloudformation delete-stack-instances \
  --stack-set-name OrganizationCredentialReportRoleStackSet \
  --regions us-east-1 \
  --deployment-targets OrganizationalUnitIds=$ORG_ID \
  --no-retain-stacks \
  --operation-preferences FailureToleranceCount=10,MaxConcurrentCount=10,ConcurrencyMode=SOFT_FAILURE_TOLERANCE \
  --query 'OperationId' --output text)

# Wait for the stack instances to be deleted by checking the operation status
while true; do
  OPERATION_STATUS=$(aws cloudformation describe-stack-set-operation \
    --stack-set-name OrganizationCredentialReportRoleStackSet \
    --operation-id $DELETE_OPERATION_ID \
    --query 'StackSetOperation.Status' --output text)

  echo "Current operation status: $OPERATION_STATUS"

  if [ "$OPERATION_STATUS" == "SUCCEEDED" ]; then
    echo "Stack instances deleted successfully."
    break
  elif [ "$OPERATION_STATUS" == "FAILED" ]; then
    echo "Failed to delete stack instances. Exiting."
    exit 1
  else
    echo "Waiting for stack instances deletion to complete..."
    sleep 15
  fi
done

# Attempt to delete the StackSet
while true; do
  echo "Attempting to delete the StackSet..."
  
  aws cloudformation delete-stack-set --stack-set-name OrganizationCredentialReportRoleStackSet
  
  if [ $? -eq 0 ]; then
    echo "StackSet deleted successfully."
    break
  else
    echo "Failed to delete StackSet. Waiting 10 seconds before retrying..."
    sleep 15
  fi
done

echo "StackSet and its instances have been deleted."