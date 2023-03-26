terraform {
  backend "s3" {
    bucket         = "tf-backend-eks-handson-20230326"
    dynamodb_table = "tf-backend-eks-handson-20230326"
    key            = "prd/terraform.tfstate"
    region         = "ap-northeast-1" # S3やDynamoDBが作成されているリージョン
  }
}