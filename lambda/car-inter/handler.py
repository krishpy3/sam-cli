import json
import boto3
import os

codedeploy = boto3.client('codedeploy')
lambda_client = boto3.client('lambda')


def handler(event, context):
    print("Entering PostTraffic Hook!")
    print(event)
    print(context)
    # Read t DeploymentId and LifecycleEventHookExecutionId from the event payload
    deployment_id = event['DeploymentId']
    lifecycle_event_hook_execution_id = event['LifecycleEventHookExecutionId']

    function_to_test = os.environ.get('NewVersion')
    print(
        f"AfterAllowTraffic hook tests started\nTesting new function version: {function_to_test}")

    # Create parameters to pass to the updated Lambda function that
    # include the original "date" parameter. If the function did not
    # update as expected, then the "date" option might be invalid. If
    # the parameter is invalid, the function returns
    # a statusCode of 400 indicating it failed..
    lambda_params = {
        'FunctionName': function_to_test,
        'Payload': json.dumps({'option': 'date', 'period': 'today'}),
        'InvocationType': 'RequestResponse'
    }

    try:
        # Invoke the updated Lambda function
        response = lambda_client.invoke(**lambda_params)
        result = json.loads(response['Payload'].read())
        print(f"Result1: {json.dumps(result)}")
        print(f"statusCode: {result['statusCode']}")

        # Check if the status code returned by the updated function is400
        if result['statusCode'] != 400:
            print("Validation of time parameter succeeded.")
            lambda_result = "Succeeded"
        else:
            print("Validation failed")
            lambda_result = "Failed"

        # Complete the PostTraffic Hook by sendingCodeDeploy the validation status
        params = {
            'deploymentId': deployment_id,
            'lifecycleEventHookExecutionId': lifecycle_event_hook_execution_id,
            'status': lambda_result  # status can be 'Succeeded' or 'Failed'
        }

        # Pass CodeDeploy the prepared validation test results
        response = codedeploy.put_lifecycle_event_hook_execution_status(
            **params)
        print("CodeDeploy status updated successfully")
        return "CodeDeploy status updated successfully"

    except Exception as e:
        print(f"CodeDeploy Status update failed\n{str(e)}")
        raise e
