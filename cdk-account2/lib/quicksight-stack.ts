import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as quicksight from 'aws-cdk-lib/aws-quicksight';
import { Construct } from 'constructs';

export interface QuickSightStackProps extends cdk.StackProps {
  vpc: ec2.IVpc;
  quicksightSecurityGroup: ec2.ISecurityGroup;
  clusterIdentifier: string;
  databaseName: string;
}

export class QuickSightStack extends cdk.Stack {
  public readonly vpcConnectionId: string;

  constructor(scope: Construct, id: string, props: QuickSightStackProps) {
    super(scope, id, props);

    // Get private subnets
    const privateSubnets = props.vpc.selectSubnets({
      subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
    });

    // IAM role for QuickSight to access Redshift and VPC
    const quicksightRole = new iam.Role(this, 'QuickSightRedshiftRole', {
      assumedBy: new iam.ServicePrincipal('quicksight.amazonaws.com'),
      description: 'Role for QuickSight to access Redshift and VPC',
      inlinePolicies: {
        RedshiftAccess: new iam.PolicyDocument({
          statements: [
            new iam.PolicyStatement({
              effect: iam.Effect.ALLOW,
              actions: [
                'redshift:DescribeClusters',
                'redshift:GetClusterCredentials',
              ],
              resources: [
                `arn:aws:redshift:${this.region}:${this.account}:cluster:${props.clusterIdentifier}`,
                `arn:aws:redshift:${this.region}:${this.account}:dbuser:${props.clusterIdentifier}/*`,
                `arn:aws:redshift:${this.region}:${this.account}:dbname:${props.clusterIdentifier}/${props.databaseName}`,
              ],
            }),
          ],
        }),
        VPCAccess: new iam.PolicyDocument({
          statements: [
            new iam.PolicyStatement({
              effect: iam.Effect.ALLOW,
              actions: [
                'ec2:DescribeSubnets',
                'ec2:DescribeSecurityGroups',
                'ec2:DescribeVpcs',
                'ec2:DescribeAvailabilityZones',
                'ec2:DescribeNetworkInterfaces',
                'ec2:CreateNetworkInterface',
                'ec2:DeleteNetworkInterface',
                'ec2:DescribeNetworkInterfaceAttribute',
                'ec2:ModifyNetworkInterfaceAttribute',
              ],
              resources: ['*'],
            }),
          ],
        }),
      },
    });

    // // VPC Connection for QuickSight
    // const vpcConnection = new quicksight.CfnVPCConnection(this, 'QuickSightVPCConnection', {
    //   vpcConnectionId: 'redshift-vpc-connection',
    //   name: 'Redshift VPC Connection',
    //   awsAccountId: this.account,
    //   roleArn: quicksightRole.roleArn,
    //   securityGroupIds: [props.quicksightSecurityGroup.securityGroupId],
    //   subnetIds: privateSubnets.subnetIds,
    // });

    // // Ensure the role and its policies are created before the VPC connection
    // vpcConnection.node.addDependency(quicksightRole);

    // this.vpcConnectionId = vpcConnection.vpcConnectionId!;

    // Outputs
    new cdk.CfnOutput(this, 'QuickSightRoleArn', {
      value: quicksightRole.roleArn,
      description: 'IAM Role ARN for QuickSight',
    });

    // new cdk.CfnOutput(this, 'VPCConnectionId', {
    //   value: this.vpcConnectionId,
    //   description: 'QuickSight VPC Connection ID',
    // });

    new cdk.CfnOutput(this, 'QuickSightSecurityGroupId', {
      value: props.quicksightSecurityGroup.securityGroupId,
      description: 'Security Group ID for QuickSight',
    });
  }
}
