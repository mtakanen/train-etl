import sys
import json
import decimal
from datetime import datetime, timedelta
import pandas as pd
import dateutil.parser
import pytz
import boto3
from boto3.dynamodb.conditions import Key
from botocore.exceptions import ClientError

DEFAULT_REGION = 'eu-west-1'
TABLE_NAME = 'TrainArrival' 

def predict(event, context):
    query = event.get('queryStringParameters')
    train_number = query.get('train_number')
    station = query.get('station')
    try:
        p = make_prediction(train_number, station)
        response_body = {
            'train_number': train_number,
            'station': station,
            'arrival_time': p.get_arrival_time('%H:%M'), 
            'median': p.median,
            'std': p.std
        }
    except RuntimeError as e:
        response_body = {
            'error': str(e)
        }
    response = {}
    response["headers"] = {"Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "*", "Access-Control-Allow-Methods": "*"}
    response["statusCode"] = 200
    response['body'] = json.dumps(response_body)

    return response

def make_prediction(train_number, target_station):
    #target_date = datetime.today()
    ddb = DynamoDB(region_name=DEFAULT_REGION)
    data_provider = DataProvider(ddb, table_name=TABLE_NAME)
    if not data_provider.table_exists():
        raise RuntimeError(f'Table {TABLE_NAME} has gone missing.')

    data = data_provider.query(train_number, target_station)
    if len(data) == 0:
        raise RuntimeError(f'No arrival data for train {train_number} at station code {target_station}')

    return Predictor(data).predict()


class Predictor():

    def __init__(self, arrivals):
        self.arrivals = arrivals

    def predict(self):
        count = len(self.arrivals)
        diff = self.arrivals['DifferenceInMinutes']
        max_diff = int(diff.max())
        min_diff = int(diff.min())
        std = float(diff.std())
        mean = float(diff.mean())
        median = float(diff.median())
        scheduled = (dateutil.parser.parse(self.arrivals['ScheduledTime'][0])
            .astimezone(pytz.timezone('Europe/Helsinki')))
        arrival_datetime = scheduled+timedelta(seconds=median*60)
        arrival_time = arrival_datetime.time()
        return Prediction(arrival_time, max_diff, min_diff, std, mean, median, count)

class Prediction():
    def __init__(self, arrival_time, max_diff, min_diff, std, mean, median, count):
        self.arrival_time = arrival_time
        self.max_diff = max_diff
        self.min_diff = min_diff
        self.std = std
        self.mean = mean 
        self.median = median 
        self.count = count

    def get_arrival_time(self, date_format):
        return self.arrival_time.strftime(date_format)

class DataProvider():
    """Prodives data via given db_engine in Pandas dataframe
    """
    def __init__(self, db_engine, table_name):
        self.db_engine = db_engine
        self.table_name = table_name
        self.decoder = DecimalDecoder()

    def table_exists(self):
        return self.db_engine.table_exists(self.table_name)

    def query(self, train_number, target_station):
        items = self.db_engine.query(self.table_name, train_number, target_station)
        return self.items_to_dataframe(items)

    def query_all(self):
        items = self.db_engine.scan_table(self.table_name)
        return self.items_to_dataframe(items)

    def items_to_dataframe(self, items):
        df = pd.DataFrame(items)
        return df.applymap(lambda x: self.decoder.deserialize(x))


class DynamoDB(object):

    def __init__(self, region_name):
        self.client = boto3.client('dynamodb')
        self.ddb = boto3.resource('dynamodb', region_name=region_name)

    def table_exists(self, table_name):
        try:
            self.client.describe_table(TableName=table_name)
            return True
        except self.client.exceptions.ResourceNotFoundException:
            return False
        
    def query(self, table_name, train_number, target_station):
        key = f'{train_number}-{target_station}'
        response = self.ddb.Table(table_name).query(
            KeyConditionExpression=Key('TrainStation').eq(key))
        return response['Items']

    def scan_table(self, table_name, batch_size=1000):
        response = self.ddb.Table(table_name).scan(Limit=batch_size)
        items = response['Items']
        while response.get('LastEvaluatedKey'):
            response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
            items.extend(response['Items'])
        return items


class DecimalDecoder():

    def deserialize(self, o):
        if isinstance(o, decimal.Decimal):
            if abs(o) % 1 > 0:
                return float(o)
            else:
                return int(o)
        return o


if __name__ == '__main__':
    train_number = '8574'
    target_station = 'HKI'
    if len(sys.argv) == 3:
        train_number = sys.argv[1]
        target_station = sys.argv[2]
    p = make_prediction(train_number, target_station)
    print(p.get_arrival_time('%H:%M'), p.median, p.std)