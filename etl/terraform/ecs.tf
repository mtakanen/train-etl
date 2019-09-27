

variable "cluster-name" {
  default = "TrainETL"
  type    = "string"
}

variable "region" {
  default = "eu-west-1"
  type    = "string"
}

provider "aws" {
    region = "${var.region}"
}

# Networking
data "aws_availability_zones" "available" {}

resource "aws_vpc" "vpc" {
    cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "subnet" {
  count = 1
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  cidr_block        = "10.0.${count.index}.0/24"
  vpc_id            = "${aws_vpc.vpc.id}"

  tags = "${
    map(
     "Name", "train-etl",
     "ecs/cluster/${var.cluster-name}", "shared",
    )
  }"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags = {
    Name = "train-etl"
  }
}

resource "aws_route_table" "route-table" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }
}

resource "aws_route_table_association" "route-association" {
  count = 1
  subnet_id      = "${aws_subnet.subnet.*.id[count.index]}"
  route_table_id = "${aws_route_table.route-table.id}"
}

resource "aws_vpc_endpoint" "vpc-dynamo-db" {
  vpc_id       = "${aws_vpc.vpc.id}"
  service_name = "com.amazonaws.${var.region}.dynamodb"
}

resource "aws_vpc_endpoint_route_table_association" "vpc-route-table-assocication" {
  route_table_id  = "${aws_route_table.route-table.id}"
  vpc_endpoint_id = "${aws_vpc_endpoint.vpc-dynamo-db.id}"
}


resource "aws_ecr_repository" "erc_repo" {
  name = "train-etl"
}

# ECS Cluster
resource "aws_ecs_cluster" "ecs-train-etl" {
    name = "${var.cluster-name}"
}

resource "aws_ecs_task_definition" "etl_task_definition" {
    family = "train-etl"
    cpu = "256"
    memory = "512"
    network_mode = "awsvpc"
    requires_compatibilities = ["FARGATE"]
    container_definitions = "${file("container-definitions.json")}"
    execution_role_arn = "${aws_iam_role.ecs_exec_role.arn}"
    task_role_arn = "${aws_iam_role.ecs_task_role.arn}"
}
