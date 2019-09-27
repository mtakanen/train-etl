variable "region" {
  default = "eu-west-1"
  type    = "string"
}

variable "s3_bucket_artifacts" {
  type = "string"
}

variable "s3_bucket_dependencies" {
  type = "string"
}

provider "aws" {
  region = "${var.region}"
}

resource "aws_lambda_layer_version" "lambda_layer_pandas" {
  s3_bucket   = "${var.s3_bucket_dependencies}"
  s3_key = "dependencies-37m-x86_64-linux-gnu.zip"
  layer_name = "Python-pandas"

  compatible_runtimes = ["python3.7"]
}
resource "aws_lambda_function" "lambda_function" {
  function_name = "TrainPredictionLambda"

  # The bucket name as created earlier with "aws s3api create-bucket"
  s3_bucket = "${var.s3_bucket_artifacts}"
  s3_key    = "function.zip"
  handler = "prediction.predict"
  runtime = "python3.7"

  role = "${aws_iam_role.lambda_exec.arn}"

  layers = ["${aws_lambda_layer_version.lambda_layer_pandas.arn}"]
}

# IAM role which dictates what other AWS services the Lambda function
# may access.
resource "aws_iam_role" "lambda_exec" {
  name = "LambdaServiceRole"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "1",
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        },
        "Effect": "Allow"
      }
    ]
}
EOF
}

resource "aws_iam_policy" "dynamo_read_policy" {
  name        = "DynamoReadPolicy"
  description = "Allow read DynamoDB table"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "dynamodb:Scan",
        "dynamodb:Query",
        "dynamodb:DescribeTable"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:dynamodb:*:*:table/TrainArrival*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda-policy-attach" {
  role       = "${aws_iam_role.lambda_exec.name}"
  policy_arn = "${aws_iam_policy.dynamo_read_policy.arn}"
}

# must be POST
resource "aws_api_gateway_integration" "apigw_lambda" {
  rest_api_id = "${aws_api_gateway_rest_api.prediction_api.id}"
  resource_id = "${aws_api_gateway_method.prediction.resource_id}"
  http_method = "${aws_api_gateway_method.prediction.http_method}"

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.lambda_function.invoke_arn}"
}


resource "aws_api_gateway_deployment" "apigw_deployment" {
  depends_on = [
    "aws_api_gateway_integration.apigw_lambda"
  ]

  rest_api_id = "${aws_api_gateway_rest_api.prediction_api.id}"
  stage_name  = "test"
}

resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.lambda_function.function_name}"
  principal     = "apigateway.amazonaws.com"

  # The "/*/*" portion grants access from any method on any resource
  # within the API Gateway REST API.
  source_arn = "${aws_api_gateway_rest_api.prediction_api.execution_arn}/${aws_api_gateway_deployment.apigw_deployment.stage_name}/${aws_api_gateway_method.prediction.http_method}${aws_api_gateway_resource.prediction.path}"
}

output "service_url" {
  value = "${aws_api_gateway_deployment.apigw_deployment.invoke_url}${aws_api_gateway_resource.prediction.path}"
}

