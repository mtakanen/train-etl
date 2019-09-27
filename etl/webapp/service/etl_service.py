import json
from datetime import datetime, timedelta
from flask import Flask, make_response
from flask_cors import CORS

from etl import ETL

DEFAULT_REGION = 'eu-west-1'
app = Flask(__name__)


# The service basepath has a short response just to ensure that healthchecks
# sent to the service root will receive a healthy response.
@app.route("/")
def healthCheckResponse():
    status_code = 200
    return json.dumps({"message" : "Nothing here, used for health check. Try /etl instead."}), status_code

@app.route('/etl/<n_weeks>', methods=['GET'])
def do_etl(n_weeks):
    status_code = 200
    from_date = datetime.today()
    e = ETL(region_name=DEFAULT_REGION)
    count = e.etl(train_number, from_date, parse_int_arg(n_weeks))
    return json.dumps({'status': 'ok', 'count': count}), status_code


@app.after_request
def add_headers(response):
    response.headers = {'Content-Type': 'application/json',
                        'Accept': 'application/json'}
    return response


def parse_int_arg(arg):
    try:
        val = int(arg)
        if val < 1:
            raise ValueError
    except ValueError:
        raise ValueError('Invalid value for positive integer argument')
    return val

# Run the service on the local server it has been deployed to,
# listening on port 8080.
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)