import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as redshift from 'aws-cdk-lib/aws-redshift';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as secretsmanager from 'aws-cdk-lib/aws-secretsmanager';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as cr from 'aws-cdk-lib/custom-resources';
import { Construct } from 'constructs';
import * as path from 'path';

interface RedshiftStackProps extends cdk.StackProps {
  account1Id?: string;
  s3BucketName?: string;
}

export class RedshiftStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: RedshiftStackProps) {
    super(scope, id, props);

    const vpc = new ec2.Vpc(this, 'RedshiftVpc', {
      maxAzs: 2,
      natGateways: 1
    });

    const redshiftRole = new iam.Role(this, 'RedshiftRole', {
      assumedBy: new iam.ServicePrincipal('redshift.amazonaws.com'),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonS3ReadOnlyAccess')
      ]
    });

    const dbSecret = new secretsmanager.Secret(this, 'RedshiftSecret', {
      generateSecretString: {
        secretStringTemplate: JSON.stringify({ username: 'admin' }),
        generateStringKey: 'password',
        excludePunctuation: true,
        passwordLength: 32
      }
    });

    const subnetGroup = new redshift.CfnClusterSubnetGroup(this, 'SubnetGroup', {
      description: 'Redshift cluster subnet group',
      subnetIds: vpc.privateSubnets.map(subnet => subnet.subnetId)
    });

    const securityGroup = new ec2.SecurityGroup(this, 'RedshiftSG', {
      vpc,
      description: 'Redshift cluster security group'
    });

    const cluster = new redshift.CfnCluster(this, 'RedshiftCluster', {
      clusterType: 'single-node',
      nodeType: 'ra3.xlplus',
      dbName: 'dev',
      masterUsername: 'admin',
      masterUserPassword: dbSecret.secretValueFromJson('password').unsafeUnwrap(),
      clusterSubnetGroupName: subnetGroup.ref,
      vpcSecurityGroupIds: [securityGroup.securityGroupId],
      iamRoles: [redshiftRole.roleArn],
      publiclyAccessible: false
    });

    cluster.addDependency(subnetGroup);

    // Add resource policy if Account1 details are provided
    if (props?.account1Id && props?.s3BucketName) {
      const policyHandler = new lambda.Function(this, 'ResourcePolicyHandler', {
        runtime: lambda.Runtime.NODEJS_20_X,
        handler: 'resource-policy-handler.handler',
        code: lambda.Code.fromAsset(path.join(__dirname, 'lambda')),
        timeout: cdk.Duration.minutes(5)
      });

      policyHandler.addToRolePolicy(new iam.PolicyStatement({
        actions: ['redshift:PutResourcePolicy', 'redshift:DeleteResourcePolicy'],
        resources: ['*']
      }));

      const policyProvider = new cr.Provider(this, 'ResourcePolicyProvider', {
        onEventHandler: policyHandler
      });

      const resourcePolicy = new cdk.CustomResource(this, 'RedshiftResourcePolicy', {
        serviceToken: policyProvider.serviceToken,
        properties: {
          ResourceArn: cluster.attrClusterNamespaceArn,
          Policy: JSON.stringify({
            Version: '2012-10-17',
            Statement: [
              {
                Effect: 'Allow',
                Principal: {
                  Service: 'redshift.amazonaws.com'
                },
                Action: 'redshift:AuthorizeInboundIntegration',
                Resource: cluster.attrClusterNamespaceArn
              },
              {
                Effect: 'Allow',
                Principal: {
                  AWS: `arn:aws:iam::${props.account1Id}:root`
                },
                Action: 'redshift:CreateInboundIntegration',
                Resource: cluster.attrClusterNamespaceArn
              }
            ]
          })
        }
      });
      resourcePolicy.node.addDependency(cluster);

      // Output commands for manual steps
      new cdk.CfnOutput(this, 'Step1CreateIntegration', {
        value: `aws redshift create-integration --integration-name s3-data-source-integration --source-arn arn:aws:s3:::${props.s3BucketName} --target-arn ${cluster.attrClusterNamespaceArn} --region ${this.region} --profile default`,
        description: 'Step 1: Run this command to create S3 event integration'
      });

      new cdk.CfnOutput(this, 'Step2CreateCopyJob', {
        value: `Connect to Redshift and run: COPY public.data_import FROM 's3://${props.s3BucketName}/' IAM_ROLE '${redshiftRole.roleArn}' CSV IGNOREHEADER 1 JOB CREATE data_import_job AUTO ON;`,
        description: 'Step 2: Create COPY JOB in Redshift'
      });

      new cdk.CfnOutput(this, 'Step3UploadData', {
        value: `aws s3 cp data/ s3://${props.s3BucketName}/ --recursive --profile cloudops-demo`,
        description: 'Step 3: Upload test data to S3'
      });
    }

    new cdk.CfnOutput(this, 'ClusterIdentifier', {
      value: cluster.ref,
      description: 'Redshift cluster identifier'
    });

    new cdk.CfnOutput(this, 'ClusterNamespaceArn', {
      value: cluster.attrClusterNamespaceArn,
      description: 'Redshift namespace ARN for S3 event integration'
    });

    new cdk.CfnOutput(this, 'RedshiftRoleArn', {
      value: redshiftRole.roleArn,
      description: 'IAM role ARN for Redshift S3 access'
    });

    new cdk.CfnOutput(this, 'Account', {
      value: this.account,
      description: 'Account ID'
    });

    new cdk.CfnOutput(this, 'DatabaseName', {
      value: 'dev'
    });

    new cdk.CfnOutput(this, 'SecretArn', {
      value: dbSecret.secretArn
    });
  }
}
