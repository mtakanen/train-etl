## Build AWS infra with Cloudformation

```bash
aws cloudformation create-stack --stack-name TrainETLStack --capabilities CAPABILITY_NAMED_IAM --template-body file://core-infra.yml
```

### Create log group

```bash
aws logs create-log-group --log-group-name trainetl-logs
```

### Create service linked role for ECS

```bash
aws iam create-service-linked-role --aws-service-name ecs.amazonaws.com
```

### Create ECR repository

```bash
aws ecr create-repository --repository-name TrainETL
```

### Create ECS cluster

```bash
aws ecs create-cluster --cluster-name TrainETL
```