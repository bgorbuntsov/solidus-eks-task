#!/bin/bash

# Company name
export TF_VAR_corpname='solidus'
# Domain pointed to k8s cluster
export TF_VAR_domainname='kube.solidus.io'
# Repo storing apps sourcecode
export TF_VAR_reponame_prefix='https://github.com/bgorbuntsov/'
# Github access token (shoul be generated via Github web)
export TF_VAR_github_token=''
# AWS region to run all this stuff
export TF_VAR_region='us-east-1'
# Database user
export TF_VAR_rds_user='user'
# Database name
export TF_VAR_rds_database='solidusdb'
# AWS access
export AWS_ACCESS_KEY_ID=""
export AWS_SECRET_ACCESS_KEY=""

