#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { RedshiftStack } from '../lib/redshift-stack';

const app = new cdk.App();

const account1Id = app.node.tryGetContext('account1Id');
const s3BucketName = app.node.tryGetContext('s3BucketName');

new RedshiftStack(app, 'RedshiftStack', {
  env: {
    region: 'ap-southeast-1'
  },
  account1Id,
  s3BucketName
});
