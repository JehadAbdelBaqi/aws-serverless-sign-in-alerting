#!/bin/bash

helpFunction() {
    echo ""
    echo "This file deploys a VPC network CloudFormation stack. You must specify an AWS account ID and a profile linked to it to use for deployment"
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo "\t-p(rofile)                       The AWS profile linked with the account you wish to deploy to"
    echo "\t-a(ccount_id)                    The ID of the AWS accouint you wish to deploy to"
    echo "\t-d(eployment_id)                 [OPTIONAL] The deployment id used for your resources"
    echo "\t-s(tack_name)                    [OPTIONAL] The name of your Stack in CloudFormations"
    echo "\t-f(emplate_file)                 [OPTIONAL] The location of your template file"
    echo "\t-l(ambda_zip_file_name)          [OPTIONAL] The name of the lambda zip file"
    echo "\t-b(ucket_for_lambda_artefacts)   [OPTIONAL] The name of the artefactory s3 bucket"
    echo "\t-t(emplate_bucket_name)          [OPTIONAL] The name of the template s3 bucket"
    exit 1
}

while getopts ":p:a:d:s:f:l:b:t" opt ; do
    case "$opt" in
        p) PROFILE="$OPTARG" ;;
        a) ACCOUNT_ID="$OPTARG" ;;
        d) DEPLOYMENT_ID="$OPTARG" ;;
        s) STACK_NAME="$OPTARG" ;;
        t) TEMPLATE_FILE="$OPTARG" ;;
        l) LAMBDA_FUNCTION_ZIP_FILE_NAME="$OPTARG" ;;
        s) BUCKET_FOR_LAMBDA_ARTEFACTS="$OPTARG" ;;
        t) TEMPLATE_BUCKET_NAME="$OPTARG" ;;
        ?) 
            helpFunction
            exit 1 ;;
        :)
            helpFunction
            exit 1 ;;
    esac
done

if [ -z "$PROFILE" ] || [ -z "$ACCOUNT_ID" ]; then
    echo "You need to specify an AWS account ID and a profile linked to that account for deployment"
    helpFunction
fi

if [ -z "$DEPLOYMENT_ID" ]; then
    DEPLOYMENT_ID="stack-deployment"
fi

STACK_NAME="$DEPLOYMENT_ID-user-sign-in-alert-stack"
TEMPLATE_FILE="./aws-sign-in-alert-stack.cf.yaml"
LAMBDA_FUNCTION_ZIP_FILE_NAME="user-sign-in-lambda-code.zip"
BUCKET_FOR_LAMBDA_ARTEFACTS="$DEPLOYMENT_ID-user-sign-in-lambda-artefacts-bucket"
TEMPLATE_BUCKET_NAME="$DEPLOYMENT_ID-user-sign-in-template-bucket"

echo "Creating s3 for CloudFormation templates bucket"
aws s3 mb s3://$TEMPLATE_BUCKET_NAME --profile $PROFILE
sleep 5

echo "Copying Cloudformation templates into bucket"
aws s3 cp . s3://$TEMPLATE_BUCKET_NAME --recursive --profile $PROFILE

echo "Zipping lambda code files"
cd user-sign-in-alert-lambda/artefacts
zip -r $LAMBDA_FUNCTION_ZIP_FILE_NAME .
sleep 5

echo "Creating lambda artefactory s3 bucket"
aws s3 mb s3://$BUCKET_FOR_LAMBDA_ARTEFACTS --profile $PROFILE
sleep 5

echo "Copying zipped file over to new s3 bucket"
aws s3 cp $LAMBDA_FUNCTION_ZIP_FILE_NAME s3://$BUCKET_FOR_LAMBDA_ARTEFACTS/$LAMBDA_FUNCTION_ZIP_FILE_NAME --profile $PROFILE
sleep 5

rm -rf $LAMBDA_FUNCTION_ZIP_FILE_NAME

echo "Creating lambda layers"
mkdir lambda_layer
cd lambda_layer
pip install twilio -t . 'attrs < 23.0'
wait

echo "Zipping lambda layers"
zip -r user-sign-in-lambda-layer.zip .
wait

echo "Copying lambda layers to artefactory bucket"
aws s3 cp user-sign-in-lambda-layer.zip s3://$BUCKET_FOR_LAMBDA_ARTEFACTS/user-sign-in-lambda-layer.zip --profile $PROFILE
wait

cd ..
rm -r lambda_layer
wait

cd ../..
echo "Deploying stack $STACK_NAME"
sleep 5

aws cloudformation deploy \
    --profile $PROFILE \
    --stack-name $STACK_NAME \
    --template-file $TEMPLATE_FILE \
    --parameter-overrides \
        DeploymentId=$DEPLOYMENT_ID AccountId=$ACCOUNT_ID\
    --capabilities CAPABILITY_NAMED_IAM

echo "Deleting buckets"
aws s3 rb s3://$BUCKET_FOR_LAMBDA_ARTEFACTS --force --profile $PROFILE
aws s3 rb s3://$TEMPLATE_BUCKET_NAME --force --profile $PROFILE
