import json
import datetime


def handler(event, context):
    if 'body' in event:
        event = json.loads(event['body'])

    sc = None  # Status code
    result = None  # Response payload

    if event.get('option') == 'date':
        if event.get('period') == 'yesterday':
            result = set_date_result('yesterday')
            sc = 200
        elif event.get('period') == 'today':
            result = set_date_result('today')
            sc = 200
        elif event.get('period') == 'tomorrow':
            result = set_date_result('tomorrow')
            sc = 200
        else:
            result = {
                'error': "Must specify 'yesterday', 'today', or 'tomorrow'."}
            sc = 400
    # Uncomment the below section when updating the function
    elif event.get('option') == 'time':
        d = datetime.datetime.now()
        h = d.hour
        mi = d.minute
        s = d.second
        result = {
            "hour": h,
            "minute": mi,
            "second": s,
        }
        sc = 200
    else:
        result = {'error': "Must specify 'date' or 'time'."}
        sc = 400

    response = {
        'statusCode': sc,
        'headers': {'Content-type': 'application/json'},
        'body': json.dumps(result)
    }
    return response

def set_date_result(option='today'):
    d = datetime.date.today()
    if option == 'yesterday':
        d -= datetime.timedelta(days=1)
    elif option == 'tomorrow':
        d += datetime.timedelta(days=1)
    mo = d.month
    da = d.day
    y = d.year
    result = {
        'month': mo,
        'day': da,
        'year': y
    }
    return result
