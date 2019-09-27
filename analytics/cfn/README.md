# AWS Infra with Cloudformation

Make S3 bucket where service artifacts and dependencies are uploaded

```bash
aws s3 mb s3://BUCKET_ARTIFACTS
aws s3 mb s3://BUCKET_DEPENDENCIES
```

Install used python dependencies into current directory:

```bash
pip install -r requirements.txt -t .
```

Package service with SAM

```bash
sam package --template-file service/cfn/prediction-service.yml --output-template-file transformed-service.yml --s3-bucket BUCKET_ARTIFACTS
```

Deploy stack:
```bash
aws cloudformation deploy --template-file transformed-service.yml --stack-name TrainPredictions --capabilities CAPABILITY_NAMED_IAM
```

Pandas library uses compiled cPython libraries that are platform specific. AWS Lambda runs on Linux (AMI 2). Compiled binaries *-manylinux1_x86_64.whl can be found from pypi.org Extract downloaded zip-files to directory `python/`. E.g.

```bash
unzip pandas-0.25.1-cp37-cp37m-manylinux1_x86_64.whl -d python/
```

Pandas depends on numpy and pytz. Download those as well!

Compress directory:

```bash
zip pandas-nympy-37m-x86_64-linux-gnu.zip -r python/
```

Copy depencies to s3 bucket:

```bash
aws s3 cp dependencies/pandas-nympy-37m-x86_64-linux-gnu.zip s3://BUCKET_DEPENDENCIES
```

Publish layer:
```bash
aws lambda publish-layer-version --layer-name Python-pandas --description "Layer provides pandas library and its dependencies" --content S3Bucket=BUCKET_DEPENDENCIES,S3Key=pandas-nympy-37m-x86_64-linux-gnu.zip --compatible-runtimes python3.7
```

Register layer to function:
```bash
aws lambda update-function-configuration --function-name TrainPredictions-TrainPredictionFunction-OJFMLTOCJEQS --layers arn:aws:lambda:AWS_REGION:AWS_ACCOUNT_ID:layer:Python-pandas:1
```

Describe cloudformation stack:

```bash
aws cloudformation describe-stacks --stack-name TrainPredictions
```

Value of key OutputValue for TrainPredictionApi contains
API endpoint url, e.g. https://ifartpxioe.execute-api.AWS_REGION.amazonaws.com/test/prediction