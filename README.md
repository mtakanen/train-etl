# Serverless train arrival ETL and predictions

Do trains in Finland run on schudule? Application predicts arrival time of a train at a station based on historical data available via <https://www.digitraffic.fi/rautatieliikenne/>.

AWS services used:

- ECS
- Fargate
- DynamoDB
- API Gateway
- Lambda

See [etl/README.md](etl/README.md) and [analytics/README.md](analytics/README.md) for details.
