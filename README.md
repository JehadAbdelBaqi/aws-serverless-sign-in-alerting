## AWS Serverless Security Monitoring with CloudFormation

This project leverages several AWS services to create a serverless security monitoring solution using CloudFormation for deployment automation.

Currently the Lambda only print out and returns the event it receives since this project was more for setting up the AWS services. However the idea is to send an alert if the IP address in the sign in log is not a recognised IP address.

I do have an old code snippet which I worked ona few years back using the twilio API to send a text message with stock news - the same code could be refactored to be put into the lambda code here. This is why in the deploy.sh file where the lambda layers are being created I am downloading and zipping twilio.

## Architecture

The project consists of a parent stack and three child stacks:

### Parent Stack

- Orchestrates the deployment of the child stacks.
- Retrieves CloudFormation template locations (S3 URLs) for the child stacks.

### CloudTrail Stack

- Creates an AWS CloudTrail management trail to track API activity within the account.
- Provisions an S3 bucket to store CloudTrail logs.
- Configures a CloudWatch Log Group for centralized log aggregation.

### Lambda Stack with Lambda Layers

- Defines an AWS Lambda function responsible for processing CloudTrail events.
- Integrates Lambda Layers to package additional dependencies with the function.
- Retrieves Lambda function code and layers from an S3 bucket during deployment.

### EventBridge Stack with Rule & Triggers

- Establishes an AWS EventBridge rule to monitor CloudTrail logs for specific events.
- Triggers the Lambda function and log group upon detecting console or SSO sign-in events.

## Deployment Process
A Bash script automates the deployment process:

- Bucket Creation: Creates S3 buckets to store:
    - CloudFormation template files for all stacks.
    - Lambda function code and layers.
- Template & Artifact Copying: Uploads CloudFormation template files to the designated S3 bucket.
- Lambda Packaging: Zips Lambda function code and layers for deployment.
- CloudFormation Deployment: Uses the aws cloudformation deploy command to deploy the local stack which fetches the nested stacks from s3.
- Cleanup: Deletes temporary S3 buckets after successful deployment.

## Prerequisites and Usage

### Prerequisites 

- An AWS account with sufficient permissions to create the required resources.
- AWS config file linked to the desired account through a profile configuration.

### Usage

- Required Parameters:
    - Profile: The name of the AWS profile in your configuration file that has sso access to your AWS account. You can specify this with the -p flag.
    - Account Number: The AWS account number associated with the profile you're using. Use the -a or flag to provide this. 

All other parameters are optional since they are set to defaults in the bash script - you can change them there. However if you decide to change these default parameters you must pass them into the --parameter-overrides in the bash script and delete their assignment.

Example usage:

```bash
sh deploy.sh -p <aws-profile> -a <aws-account-number>
```

Any other parameters are optional. For full information, type in the command below:

```bash
sh deploy.sh --help
```

### AWS Account Usage

Since there is currently no lambda code this currently doesn't do anything. However you can still see it working. The way to do this after the deployment of the stack is to either log out and log back into the console or to execute the below command in your terminal:

```bash
aws sso login --profile <aws-profile>
```

After running the command above you can check the logs of the lambda in the stack and see the message that's come from CloudTrail through EventBridge and into the Lambda. If you can see anything in the logs then give it a few minutes as sometimes it takes a moment for the logs to appear.

## Issues Encountered

### EventBridge Rule Deployment Outside Default Bus

When I was Deploying an AWS EventBridge rule outside of the default event bus resulted in the rule not being triggered as expected. The configuration of the Rule was exactly the same as the one deployed in a custom EventBridge Bus I had made. But for some reason, the Rule I made in the custom Bus just wouldn't trigger. In the end I gave up and just deployed it to the default EventBridge Bus that comes with the account.

### Policy Issue with CloudTrail S3 Bucket:

When deploying the CloudTrail S3 bucket policy through CloudFormation, an extra statement resource condition within the policy caused deployment to fail. However, when the bucket is created automatically when making a CloudTrail management directly from the AWS console it worked successfully.

I have kept both these conditions in the user-sign-in-cloudtrail.cf.yaml template but have commented them out. They are exactly the same (I believe) as the ones created automatically in the console. Upon some research it seems some others did come across this issue. I did read these extra conditions are not required but are more desireable to have. Further investigation needed.


## Next Steps
Extend the Lambda functionality to perform actions based on suspicious activity (e.g., sending alerts, blocking access).
Investigate issue with successful EventBridge Rule triggers when deploying to a custom EventBRidge Bus.
Investigate issue with CloudTrail S3 bucket policy not working as it should be - or add cli command to bash script to add those extra policies into the bucket permissions after deployment.
