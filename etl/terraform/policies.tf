# policy documents
data "aws_iam_policy_document" "ecs_task_policy" {
    statement {
        sid = "AmazonECSTaskPolicy"
        actions = [
            "sts:AssumeRole",
            "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
            # logging
            "logs:CreateLogStream",
            "logs:CreateLogGroup",
            "logs:PutLogEvents"
        ]
        resources = [ "*" ]
    }

    statement {
        sid = "AmazonDynamoDbAccessPolicy"
        actions = [
            "dynamodb:Scan",
            "dynamodb:Query",
            "dynamodb:BatchWriteItem"
        ]
        resources = [
            "arn:aws:dynamodb:*:*:table/TrainArrivals*"
        ]
    }
}

data "aws_iam_policy_document" "ecs_exec_policy"{
    statement {
        sid = "AmazonECSExecutionPolicy"
        actions = [
            "sts:AssumeRole",
            # allow ECS to attach network interfaces to instances
            # on your behalf in order for awsvpc networking mode to work right
            "ec2:AttachNetworkInterface",
            "ec2:CreateNetworkInterface",
            "ec2:CreateNetworkInterfacePermission",
            "ec2:DeleteNetworkInterface",
            "ec2:DeleteNetworkInterfacePermission",
            "ec2:Describe*",
            "ec2:DetachNetworkInterface",

            # allows ECS to run tasks that have IAM roles assigned to them
            "iam:PassRole",

            # allow ECS interact with container images
            "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",

            # allow ECS create and push logs to CloudWatch
            "logs:DescribeLogStreams",
            "logs:CreateLogStream",
            "logs:CreateLogGroup",
            "logs:PutLogEvents"
        ]
        resources = [ "*" ]
    }
}

resource "aws_iam_policy" "ecs_task_policy" {
  policy = "${data.aws_iam_policy_document.ecs_task_policy.json}"
}

resource "aws_iam_policy" "ecs_exec_policy" {
  policy = "${data.aws_iam_policy_document.ecs_exec_policy.json}"
}

data "aws_iam_policy_document" "ecs_assume_task_role_policy" {
    statement {
        actions = ["sts:AssumeRole"]
        principals {
            type        = "Service"
            identifiers = ["ecs-tasks.amazonaws.com"]
        }
    }
}

data "aws_iam_policy_document" "ecs_assume_exec_role_policy" {
    statement {
        actions = ["sts:AssumeRole"]
        principals {
            type        = "Service"
            identifiers = [
                "ecs.amazonaws.com", 
                "ecs-tasks.amazonaws.com"
            ]
        }
    }
}

resource "aws_iam_role" "ecs_task_role" {
    name = "ECSTaskRole"
    path = "/"
    assume_role_policy = "${data.aws_iam_policy_document.ecs_assume_task_role_policy.json}"
}

resource "aws_iam_role" "ecs_exec_role" {
    name = "ECSExecutionRole"
    path = "/"
    assume_role_policy = "${data.aws_iam_policy_document.ecs_assume_exec_role_policy.json}"
}

resource "aws_iam_role_policy_attachment" "ecs_task_attach" {
  role       = "${aws_iam_role.ecs_task_role.name}"
  policy_arn = "${aws_iam_policy.ecs_task_policy.arn}"
}

resource "aws_iam_role_policy_attachment" "ecs_exec_attach" {
  role       = "${aws_iam_role.ecs_exec_role.name}"
  policy_arn = "${aws_iam_policy.ecs_exec_policy.arn}"
}

