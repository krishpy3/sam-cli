import json
import boto3
import os
import numpy

codedeploy = boto3.client('codedeploy')
lambda_client = boto3.client('lambda')


def handler(event, context):
    print("Entering PostTraffic Hook!")
    print(event)
    print(context)
    return {"abe": "csd"}
