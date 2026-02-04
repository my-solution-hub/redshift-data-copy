#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { DataSourceStack } from '../lib/data-source-stack';

const app = new cdk.App();

const account2Id = app.node.tryGetContext('account2Id');
const redshiftRoleArn = app.node.tryGetContext('redshiftRoleArn');

new DataSourceStack(app, 'DataSourceStack', {
  env: {
    region: 'ap-southeast-1'
  },
  account2Id,
  redshiftRoleArn
});
