import json
import boto3
import os
import numpy


def handler(event, context):
    print("Entering PostTraffic Hook!")
    print(event)
    print(context)
    return {"abe": "csd"}
