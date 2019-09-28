# Serverless ETL

ETL task reads train arrival data from <https://www.digitraffic.fi/rautatieliikenne/> API and stores records to a DynamoDB table. ETL application is written in Python, packaged as Docker image and run with AWS Fargate. AWS infra was inspired by [this article](https://www.lewuathe.com/simple-etl-running-on-docker-and-ecs.html).

AWS services used:

- ECS
- Fargate
- DynamoDB

Infrastructure is defined with Terraform.

## Setup 

Set the following environment variables: `AWS_REGION`, `AWS_ACCOUNT_ID`.

### Build AWS Infra with Terraform

```bash
$ cd terraform
$ terraform init
$ terraform apply -var="region=$AWS_REGION"
```

### Create DynamoDB table

```bash
$ aws dynamodb create-table --cli-input-json file://aws-cli/dynamodb-table.json
```

### Build Docker image

```bash
$ cd app
$ docker build . -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/train-etl:latest
```

### Test local (optional)

Set the following environment variables: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`.

```bash
$ docker run -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -p 8080:8080 AWS_ACCOUNT_ID.dkr.ecr.AWS_REGION.amazonaws.com/train-etl:latest --train_number=8322 --weeks=1
```

### Push image to ECR

Login to ECR:

```bash
$ $(aws ecr get-login --no-include-email)
```

and push image:

```bash
$ docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/train-etl:latest
```

## Run ETL task

```bash
$ aws ecs run-task --cli-input-json file://aws-cli/task-run.json
```
