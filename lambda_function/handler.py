import boto3
cloudwatch = boto3.client('cloudwatch')



def lambda_handler (event, context):
    instance_id = event['responseElements']['instancesSet']['items'][0]['instanceId']

    create_cpu_alert = cloudwatch.put_metric_alarm(
        AlarmName = f'{instance_id}-cpu-critical-alert',
        MetricName = "CPUUtilization",
        Namespace = 'AWS/EC2',
        Dimensions = [
            {
                "Name" : "InstanceId",
                "Value" : instance_id

            }
        ],
        Statistic = "Average",
        Threshold = 80,
        ComparisonOperator = "GreaterThanThreshold",
        Period = 5

    )
    
    return {
        'statusCode': 200,
        'body': f"Alarm created for {instance_id}"
    }
