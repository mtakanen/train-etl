# Train arrival time predictions

Lambda function reads historical train arrival data from a DynamoDB table and makes simple prediction of arrival time for given train and station. 

AWS services used:

- API Gateway
- Lambda
- DynamoDB

Infrastructure is defined with Terraform.

## Setup

Set the following environment variables `AWS_REGION`, `BUCKET_ARTIFACTS` and `BUCKET_DEPENDENCIES`.

### Upload lambda function and dependies to S3

Make S3 buckets where lambda function artifacts and dependencies are uploaded:

```bash
$ aws s3 mb s3://$BUCKET_ARTIFACTS
$ aws s3 mb s3://$BUCKET_DEPENDENCIES
```

Compress lambda function code:

```bash
$ cd app/service
$ zip function.zip -r *
```

Copy artifacts to s3 bucket:

```bash
$ aws s3 cp function.zip s3://$BUCKET_ARTIFACTS
```

### Python dependencies

Lambda function depends on Pandas library that is compute optimized with cPython code compiled to runtime platform. AWS Lambda runs on Linux (AMI 2). Download binaries *-manylinux1_x86_64.whl from <pypi.org> and extract files to directory `python/`. E.g.

```bash
$ mkdir dependencies/python
$ unzip ~/Downloads/pandas-0.25.1-cp37-cp37m-manylinux1_x86_64.whl -d dependencies/python
```

Pandas depends on `numpy` and `pytz`. In addition, prediction.py depends on `dateutil`. Download those as well. When all dependencies are unzipped in direcotory `python` compress directory:

```bash
$ zip dependencies-37m-x86_64-linux-gnu.zip -r python/
```

Finally, copy depencies to s3:

```bash
$ aws s3 cp dependencies/dependencies-37m-x86_64-linux-gnu.zip s3://$BUCKET_DEPENDENCIES
```

### Build AWS Infra with Terraform

```bash
$ cd terraform
$ terraform init 
$ terraform apply -var="region=$AWS_REGION" -var="s3_bucket_artifacts=$BUCKET_ARTIFACTS" -var="s3_bucket_dependencies=$BUCKET_DEPENDENCIES"
```

Altenatively, build infra with Cloudformation. See [cfn/README.md](cfn/README.md) for details.

## Test prediction

Terraform will print service_url when infra stack is created.

Request url with query parameters `train_number` and `station`, e.g.

```bash
$ curl "https://22lnyrpbci.execute-api.eu-west-1.amazonaws.com/test/prediction?train_number=8574&station=HKI"
```

Remember to run ETL task to load the data into DynamoDB.

## Visualization with Jupyter Notebook

Jupyter Notebook `scratch.ipynb` contains visualization of arrival time variation with `matplotlib`.

## Tear down

```bash
$ terraform destroy
$ aws dynamodb delete-table --table-name TrainArrival
```
