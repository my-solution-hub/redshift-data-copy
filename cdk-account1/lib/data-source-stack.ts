import * as cdk from 'aws-cdk-lib';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

interface DataSourceStackProps extends cdk.StackProps {
  account2Id?: string;
  redshiftRoleArn?: string;
}

export class DataSourceStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: DataSourceStackProps) {
    super(scope, id, props);

    const bucket = new s3.Bucket(this, 'DataSourceBucket', {
      bucketName: `${this.account}-data-source`,
      encryption: s3.BucketEncryption.S3_MANAGED,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: true
    });

    // Only add policies if Account2 details are provided
    if (props.account2Id && props.redshiftRoleArn) {
      // Allow Redshift service to manage S3 event notifications (no conditions)
      bucket.addToResourcePolicy(new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        principals: [new iam.ServicePrincipal('redshift.amazonaws.com')],
        actions: [
          's3:GetBucketNotification',
          's3:PutBucketNotification',
          's3:GetBucketLocation'
        ],
        resources: [bucket.bucketArn]
      }));

      // Allow Redshift IAM role to read objects
      bucket.addToResourcePolicy(new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        principals: [new iam.ArnPrincipal(props.redshiftRoleArn)],
        actions: ['s3:GetObject', 's3:ListBucket'],
        resources: [bucket.bucketArn, `${bucket.bucketArn}/*`]
      }));
    }

    new cdk.CfnOutput(this, 'BucketName', {
      value: bucket.bucketName
    });

    new cdk.CfnOutput(this, 'BucketArn', {
      value: bucket.bucketArn
    });
  }
}
