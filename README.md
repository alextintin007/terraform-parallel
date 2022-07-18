This script build multiple GKE clusters in parallel based on Terraform. 

The infrastructure to build for each user is the one presented on the CMS Workshop 2022

## Requirements
<ul>
<li> Google Cloud SDK <a href="https://cloud.google.com/sdk/docs/install"> install </a> </li>
<li> Terraform <a href="https://learn.hashicorp.com/tutorials/terraform/install-cli"> install </a> </li>
</ul>

## Setup
1) Login into your GCP account
```sh
gcloud auth application-default login
gcloud auth login
```
2) Install/Update Terraform providers 
```sh
cd terraform
terraform init
cd ..
```

## Run 
To create the clusters in parallel please run the executable:
```sh
./apply.sh
```
During execution, a log files will be generated in `logs/logs-apply/<user>`
tfstate file will be in `users/<user>/` this can be used to update user's infrastructure

## Destroy
To destroy the clusters alongside the infrastructure of all the participants run:
```sh
./destroy.sh
```
During execution, a log files will be generated in `logs/logs-destroy/<user>`

# Note
Argo is already installed but to submit worksflows you must first run:
```sh
# Download the binary
curl -sLO https://github.com/argoproj/argo/releases/download/v2.11.1/argo-linux-amd64.gz

# Unzip
gunzip argo-linux-amd64.gz

# Make binary executable
chmod +x argo-linux-amd64

# Move binary to path
sudo mv ./argo-linux-amd64 /usr/local/bin/argo
```
