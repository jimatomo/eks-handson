terraform {
  backend "s3" {
    bucket         = "tf_backend_s3_will_be_overwritten"
    dynamodb_table = "tf_backend_dynamodb_will_be_overwritten"
    key            = "prd/terraform.tfstate"
    region         = "ap-northeast-1" # S3やDynamoDBが作成されているリージョン
  }
}