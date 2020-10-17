import argparse
import yaml
from influxdb import InfluxDBClient
from datetime import datetime
import dateparser
import sys

def str_to_bool(value):
    if value.lower() in {'false', 'f', '0', 'no', 'n'}:
        return False
    elif value.lower() in {'true', 't', '1', 'yes', 'y'}:
        return True
    raise ValueError(f'{value} is not a valid boolean value')
# parser = argparse.ArgumentParser(description='Process some integers.')
parser = argparse.ArgumentParser()
parser.add_argument('-C', '--config', default="/root/.influx",
                    help='The configuration file to connect to your influxDB')
parser.add_argument('-w', '--warning', type=float,
                    help='Set the warning value for your check')
parser.add_argument('-c', '--critical', type=float,
                    help='Set the critical value for your check')
parser.add_argument('-s', '--sql', help='Sql query returned your value')

parser.add_argument('-i', '--invert', 
                    default=False, help='Invert result calculation' , type=str_to_bool, nargs='?', const=True)
parser.add_argument('-e', '--expired', type=int,
                    default=300, help='ime of expired, if result time plus NUMBER more than now get CRITICAL status')



args = parser.parse_args()
# print(args)
# print(args.accumulate(args.integers))

# print(args.config)


with open(args.config, 'r') as stream:
    try:
        config = yaml.safe_load(stream)
    except yaml.YAMLError as exc:
        print(exc)
        sys.exit(1)

# print(config['influx'])

influx = InfluxDBClient(**config['influx'])

q = influx.query(args.sql)
val = list(q.get_points())[0]
for i in val:
    if i != "time":
        value = val[i]
        break
event_time = dateparser.parse(val['time'])

# print("value:", value,"time:", event_time)
# print(datetime.utcnow())
diff = datetime.utcnow().replace(tzinfo=None) - event_time.replace(tzinfo=None) 
# print(diff.seconds)

code = 0
description = f"value:{value}"


if args.invert == True:
    if value < args.warning:
        description = f"{value} < {args.warning}"
        code = 1
    if value < args.critical:
        description = f"{value} < {args.critical}"
        code = 2

else:
    if value > args.warning:
        description = f"{value} > {args.warning}"
        code = 1
    if value > args.critical:
        description = f"{value} > {args.critical}"
        code = 2

if diff.seconds > args.expired:
    code = 2
    description = f"time too old,time: {event_time}, value:{value}"
    

if code == 0:
    status = "OK"

if code == 1:
    status = "WARNING"

if code == 2:
    status = "CRITICAL"

if code == 3:
    status = "UNKNOWN"


print(f"{status}:{description}, sql: {args.sql}")
sys.exit(code)