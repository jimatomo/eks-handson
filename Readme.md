# EKS Handson - AWS Load Balancer Controller (Terraform)

deploy
```
# Change PROJECT_HOME for your environment
export PROJECT_HOME='/workspaces/eks_tutorial'
echo $PROJECT_HOME

cd ${PROJECT_HOME}/presettings

# Deploy Terraform Backend S3 and DynamoDB
./presettings.sh

# Deploy VPC and EKS cluster
cd ${PROJECT_HOME}/terraform

terraform init
terraform plan
terraform apply

# Update kubeconfig
aws eks update-kubeconfig --name eksHandson

# Varidate kubectl Configuration to master node
kubectl get svc

# Add AWS Load Balancer Controller Helm chart
helm repo add eks https://aws.github.io/eks-charts

kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"

# Get VPC ID from Terraform output
export EKS_VPC_ID=`terraform output --raw eks_vpc_id`

echo $EKS_VPC_ID

# Install AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    --set clusterName=eksHandson \
    --set serviceAccount.create=false \
    --set region=ap-northeast-1 \
    --set vpcId=${EKS_VPC_ID} \
    --set serviceAccount.name=aws-load-balancer-controller \
    -n kube-system

# Check deployment
kubectl get deployment -n kube-system aws-load-balancer-controller

# Deploy 2048 game
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.4/docs/examples/2048/2048_full.yaml

# Check Ingress and Pod
kubectl get ingress/ingress-2048 -n game-2048
kubectl get pod -n game-2048
```


# Destory

```
kubectl delete -f https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.4/docs/examples/2048/2048_full.yaml

terraform destroy
```
