resource "aws_cloudwatch_event_bus" "eventbus" {
    name = "ec2-cloudwatch-alarm-event-bus"
    description = "This event bus stores all instance launch and terminate events"
}

resource "aws_cloudwatch_event_rule" "eventruleforec2alarm" {
    name = "capture-instance-termination-launch-event"
    description = "This event captures ec2 instance launch and termination events"
    event_bus_name = aws_cloudwatch_event_bus.eventbus.arn
    event_pattern = jsonencode(
        {
           "source" : ["aws.ec2"],
           "detail-type" : ["AWS API Call via CloudTrail"],
           "detail" : {
            "eventSource" : ["ec2.amazonaws.com"],
            "eventName" : ["RunInstances"],
            "awsRegion" : ["us-east-1"],
           "responseElements": {
             "instancesSet": {
                "items": {
                    "currentState": {
                        "name": ["running"]
                    },
                    "previousState": {
                        "name": ["pending"]
                    }
                }
            }
        }
    }
    )

}

resource "aws_cloudwatch_event_target" "alerttarget" {
    arn = aws_lambda_function.alert_lambda.arn
    rule = aws_cloudwatch_event_rule.eventruleforec2alarm.name
}

resource "aws_iam_policy" "iam_policy_for_alert_lambda" {
    name = "iam-alert-policy"
    path = "/"
    policy = jsonencode({
        "Version" : "2012-10-17",
        "Statement" : [
            {
                "Action" : "cloudwatch:*",
                "Effect" : "Allow",
                "Resource" : "*"
            }
        ]

    })
}

resource "aws_iam_role" "lambda_assume_role" {
    name = "cloudwatch-alert-automation-lambda"
    assume_role_policy = jsonencode({
        "Version" : "2012-10-17",
        "Statement" : [
            {
                "Action" : "sts:AssumeRole",
                "Effect" : "Allow",
                "Principal" : {
                    "Service" = "lambda.amazonaws.com"
                }
            }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "lambda_permission_policy_attachement"{
    role = aws_iam_role.lambda_assume_role.name
    policy_arn = aws_iam_policy.iam_policy_for_alert_lambda.arn
}


data "archive_file" "code" {
    type = "zip"
    source_dir  = "${path.module}/lambda_function"
    output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "alert_lambda" {
    function_name = "alert-create-automate-lambda"
    role = aws_iam_role.lambda_assume_role.arn
    runtime = "python3.9"
    source_code_hash = data.archive_file.code.output_base64sha256
    timeout = 600
    package_type = "Zip"
    handler = "handler.lambda_handler"
    filename = data.archive_file.code.output_path
}

resource "aws_lambda_permission" "lambda_invoke_permision" {
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.alert_lambda.function_name
    principal = "events.amazonaws.com"
    source_arn = aws_cloudwatch_event_rule.eventruleforec2alarm.arn
}

