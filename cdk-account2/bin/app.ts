#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { RedshiftStack } from '../lib/redshift-stack';
import { QuickSightStack } from '../lib/quicksight-stack';

const app = new cdk.App();

const account1Id = app.node.tryGetContext('account1Id');
const s3BucketName = app.node.tryGetContext('s3BucketName');
const enableQuickSight = app.node.tryGetContext('enableQuickSight') === 'true';

const redshiftStack = new RedshiftStack(app, 'RedshiftStack', {
  env: {
    region: 'ap-southeast-1'
  },
  account1Id,
  s3BucketName
});

// QuickSight stack requires QuickSight subscription first
if (enableQuickSight) {
  new QuickSightStack(app, 'QuickSightStack', {
    vpc: redshiftStack.vpc,
    quicksightSecurityGroup: redshiftStack.quicksightSecurityGroup,
    clusterIdentifier: redshiftStack.clusterIdentifier,
    databaseName: redshiftStack.databaseName,
    env: {
      region: 'ap-southeast-1'
    },
  });
}
