
![alt text](https://github.com/bgorbuntsov/solidus-eks-task/blob/master/img/solidus.png?raw=true)

Repo consists of:
1. Terraform config for:
   - EKS Cluster
   - Ingress
   - Apps routing rules
   - RDS Database
   - ECR Repos
   - CodeBuild projects
   - Apps config
2. Configuration script for kubectl
3. Script template for environmental variables

## Prerequisites
1. Fill ```./setvars.sh.tmpl``` file provided with appropriate values and make it executable and run
```bash
mv ./setvars.sh.tmpl ./setvars.sh
chmod u+x ./setvars.sh
. ./setvars.sh
```
It will set env variables
2. Install ```kubectl``` client
3. Prepare apps repos
* [scale](https://github.com/bgorbuntsov/solidus-scale)
* [numbers](https://github.com/bgorbuntsov/solidus-numbers)
* [names](https://github.com/bgorbuntsov/solidus-names)
* [content](https://github.com/bgorbuntsov/solidus-content)

Need to be cloned to use push webhook to run autobuild in CodeBuild. Otherwise, if you will use this links, autobuild will not work

## Usage
Configs devided to steps:
1. Deploy EKS
```bash
cd eks/cluster
terraform init
terraform apply --auto-approve
```
2. Create ECR
```bash
cd ../../ecr
terraform init
terraform apply --auto-approve
```
3. Create CodeBuild projects
```bash
cd ../codebuild
terraform init
terraform apply --auto-approve
```
This will create build projects for all apps and webhook to catch push event on GitHub repo.
In order for this to work, you need to generate token in GitHub web interface and insert it into appropriate variable in the file setvars.sh
During Terraform execution an error ```ResourceNotFoundException: Could not find access token for server type github``` can be returned.
This is documented behavior since one time OAuth API access auth to GitHub is needed to create webhook. This is a manual step that must be done 
The AWS account that Terraform uses to create this resource must have authorized CodeBuild to access Bitbucket/GitHub's OAuth API in each applicable region. This is a manual step that must be done via
ECR web interface:
Project_name -> Edit -> Source
If you can see status ```You are connected to GitHub using OAuth```, it means that you authorised and webhook will fire on every push event.

![alt text](https://github.com/bgorbuntsov/solidus-eks-task/blob/master/img/connected.png?raw=true)

4. After ECR, CodeBuild and repos are ready, you need to create images.
It can be done be making an any commit to all repos or simply start every Build in CodeBuild web interface

![alt text](https://github.com/bgorbuntsov/solidus-eks-task/blob/master/img/start_build.png?raw=true)

Building process takes some time. Be patient.
After all images be created you may proceed to create database and cluster payload
5. Create DB
```bash
cd ../rds
terraform init
terraform apply --auto-approve
```
6. Deploy apps
```bash
cd ../eks/payload
terraform init
terraform apply --auto-approve
```

Check EKS Cluster endpoint
```bash
kubectl 
. ./setvars.sh
```



