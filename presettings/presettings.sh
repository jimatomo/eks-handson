#!/bin/bash
set -e

CFN_TEMPLATE=terraform_backend.yml
CFN_STACK_NAME=terraform-backend-eksHandson-`date +%Y%m%d`

# Read variables
read -p "Enter unique S3 bucket name for Terraform Backend: " TF_S3_BUCKET_NAME
read -p "Enter unique DynamoDB Table name for Terraform Backend [eg. tf-state-lock-for-dpf]: " TF_DYNAMODB_TABLE_NAME


# Create S3 Bucket and DynamoDB
echo Create S3 Bucket and DynamoDB with Cloudformation ...
aws cloudformation deploy --stack-name ${CFN_STACK_NAME} --template-file ${CFN_TEMPLATE} \
  --parameter-overrides \
    S3BucketName=${TF_S3_BUCKET_NAME} \
    DynamoDBTableName=${TF_DYNAMODB_TABLE_NAME}

# Write Variable for Terraform
echo overWrite Variable for Terraform Backend ...
sed -i -e "s/tf_backend_s3_will_be_overwritten/$TF_S3_BUCKET_NAME/g" ../terraform/backend.tf
sed -i -e "s/tf_backend_dynamodb_will_be_overwritten/$TF_DYNAMODB_TABLE_NAME/g" ../terraform/backend.tf

echo success