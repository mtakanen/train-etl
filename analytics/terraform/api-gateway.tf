resource "aws_api_gateway_rest_api" "prediction_api" {
  name        = "TrainPredictionApi"
  description = "Api gateway for Train Prediction"
}

resource "aws_api_gateway_resource" "prediction" {
  path_part   = "prediction"
  parent_id   = "${aws_api_gateway_rest_api.prediction_api.root_resource_id}"
  rest_api_id = "${aws_api_gateway_rest_api.prediction_api.id}"
}

resource "aws_api_gateway_method" "prediction" {
  rest_api_id   = "${aws_api_gateway_rest_api.prediction_api.id}"
  resource_id   = "${aws_api_gateway_resource.prediction.id}"
  http_method   = "GET"
  authorization = "NONE"
}

