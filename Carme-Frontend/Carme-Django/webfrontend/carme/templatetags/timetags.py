from django import template
import datetime
register = template.Library()

def print_timestamp(timestamp):
    try:
        #assume, that timestamp is given in seconds with decimal point
        #ts = float(timestamp)
        ts = datetime.datetime.fromtimestamp(float(timestamp))
    except ValueError:
        return None
    #return datetime.datetime.fromtimestamp(ts)
    return ts.strftime('%b %d, %Y, %H:%M')

register.filter(print_timestamp)

def print_timestamp_small(timestamp):
    try:
        #assume, that timestamp is given in seconds with decimal point
        ts = datetime.datetime.fromtimestamp(float(timestamp))
    except ValueError:
        return None
    return ts.strftime('%b %d, %Y')

register.filter(print_timestamp_small)


@register.filter
def index(indexable, i):
    return indexable[i]
