import argparse
import sys
import json
import logging
from urllib.request import urlopen
from datetime import datetime, timedelta
import boto3

TRAINS_API_URL = 'https://rata.digitraffic.fi/api/v1/trains/'
API_DATE_FORMAT = '%Y-%m-%d'
CANCELLED_PENALTY = 30
DEFAULT_REGION = 'eu-west-1'

logger = logging.getLogger(__name__)


class DynamoDB():

    def __init__(self, region_name=DEFAULT_REGION):
        self.db = boto3.resource('dynamodb', region_name=region_name)

    def batch_write(self, table_name, items):
        """
        Batch write items to given table name
        """
        table = self.db.Table(table_name)
        with table.batch_writer() as batch:
            for item in items:
                batch.put_item(Item=item)

    
class ETL():
    
    def __init__(self, region_name):
        self.region_name = region_name

    def etl(self, train_number, from_date, n_weeks=10):
        timetables = self.extract(train_number, from_date, n_weeks)
        timetables = map(lambda tt: self.transform(tt), timetables)
        return self.load(train_number, list(timetables))

    def extract(self, train_number, from_date, n_weeks):
        arrivals = []
        for date in get_n_weeks_weekday_dates_from_date(from_date, n_weeks):
            arrivals_date = extract_arrivals(train_number, date)
            if arrivals_date:
                arrivals.extend(arrivals_date)
        return arrivals

    def transform(self, arrival):
        at = {
            'StationShortCode': arrival['stationShortCode'],
            'Type': arrival['type'],
            'ScheduledTime': arrival['scheduledTime'],
            'ScheduledDate': arrival['scheduledTime'][:10], 
            'ActualTime': arrival.get('actualTime'),
            'DifferenceInMinutes': arrival.get('differenceInMinutes')
            }
        # transforms cancelled train to differenceInMinutes
        if arrival.get('cancelled'):
            at['DifferenceInMinutes'] = CANCELLED_PENALTY
        return at

    def load(self, train_number, items):
        db = DynamoDB()
        for item in items:
            pk = f"{train_number}-{item['StationShortCode']}"
            item['TrainStation'] = pk

        db.batch_write('TrainArrival', items)
        return len(list(items))


def get_n_weeks_weekday_dates_from_date(from_date, n_weeks):
    dates = []
    delta_days = 0
    wd = from_date.weekday()
    if wd < 4:
        delta_days = 3 + wd
    elif wd > 4:
        delta_days = wd - 4
    from_date_friday = from_date - timedelta(days=delta_days)

    for week in range(0, n_weeks):
        for weekday in range(0, 5):
            dates.append(subtract_date(from_date_friday, (7*week + weekday)))
    return dates


def subtract_date(date, delta_days):
    return (date - timedelta(days=delta_days)).strftime(API_DATE_FORMAT)


def extract_arrivals(train_number, date):
    arrivals = []
    extract_keys = ['stationShortCode', 'type', 'scheduledTime', 'actualTime', 
        'differenceInMinutes']
    url = TRAINS_API_URL+date+'/'+train_number
    with urlopen(url) as response:
        resp = json.load(response)
        if not resp:
            logger.debug('timetable not found: {0}'.format(url))
            return []
        timetables = resp[0]['timeTableRows']
        timetables = filter(
            lambda tt: (tt['type'] == 'ARRIVAL') & tt['trainStopping'], timetables)
        for tt in timetables:
            arrivals.append(dict((k, tt[k]) for k in extract_keys if k in tt))

    return arrivals


def parse_args(args):
    parser = argparse.ArgumentParser(description='Serverless ETL')
    parser.add_argument('--train_number', required=True, help='Train number')
    parser.add_argument('--weeks', help='Number of weeks to extract')
    args = parser.parse_args(args)
    try:
        args.weeks = int(args.weeks)
    except:
        args.weeks = 1
    return args


def main(args):
    args = parse_args(args)
    from_date = datetime.today()
    e = ETL(region_name=DEFAULT_REGION)
    print(e.etl(args.train_number, from_date, args.weeks))


if __name__ == '__main__':
    main(sys.argv[1:])
