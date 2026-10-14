# CDE HOL Setup

## Objective

This document provides instructions for setting up HOL dependencies. The HOL lead must complete these steps as a requirement prior to the HOL event date.


## Table of Contents

* [Requirements](https://github.com/pdefusco/CDE_126_HOL/tree/main/setup#requirements)
* [Deployment Instructions](https://github.com/pdefusco/CDE_126_HOL/tree/main/setup#deployment-instructions)
* [EC2 Setup Guide](https://github.com/pdefusco/CDE_126_HOL/tree/main/setup#ec2-setup-guide)
* [Teardown Instructions](https://github.com/pdefusco/CDE_126_HOL/tree/main/setup#teardown-instructions)
* [Python Utils](https://github.com/pdefusco/CDE_126_HOL/tree/main/setup#python-utils)
* [Summary](https://github.com/pdefusco/CDE_126_HOL/tree/main/setup#summary)


## Requirements

To deploy the demo / HOL via this automation you need:

* A CDP tenant in Public or Private cloud.
* A CDP Workload User with Ranger policies and IDBroker Mappings configured accordingly. In particular, you must configure the Ranger Hadoop SQL and Raz (S3 or ADLS) policies accordingly.
* A CDE Service on version 1.26 (Spark 3.5.4, Python 3.11, Iceberg 1.5.2).
* At least two All-Purpose CDE Spark 3.5 Virtual Clusters for the labs. One will serve as DEV. One will serve as PRD. If you are hosting an HOL with many participants, organizing groups of 10 participants in multiple Dev & Prd VC pairs is highly recommended.
* A working local installation of the CDE CLI.
* A GitHub account. Keep your GitHub token handy.


## Deployment Instructions

There are four setup steps. All four can be done in parallel.

1. Create data using the Spark 3.5 Virtual Cluster. Using the DEV VC is recommended.
2. Create shared participant resources (files and Python resources) in all the Spark 3.5 VC's used throughout the labs.
3. Airflow configurations.
4. Participant IDE environment (local Docker, or EC2 with or without Docker).

In order to complete these requirements, clone this repository in your local machine and follow the steps below.

#### 1. Run new_deploy_hol.sh in the Spark 3.5 Virtual Cluster.

This step must only be run once.

Before proceeding, make sure to update your ~/.cde/config.yaml with your Spark 3.5 Virtual Cluster's CDE Jobs API URL.

Deployment script command template. Notice the demo argument. Currently, "bank" and "manufacturing" are the two supported demos.

```
% ./setup/new_deploy_hol.sh <cdp-workload-user> <max-hol-participants> <storage-location> <demo>
```

You must always create data in the data directory. For example:

```
#AWS
% ./setup/new_deploy_hol.sh <cdp-workload-user> 10 s3a://<your-bucket>/data/cde-126-hol bank
```

```
#Azure
% ./setup/new_deploy_hol.sh <cdp-workload-user> 7 abfs://<container>@<storage-account>.dfs.core.windows.net/data/cde-126-hol manufacturing
```

#### 2. Run deploy_hol_resources.sh in all the Spark 3.5 Virtual Clusters used by Participants.

You must repeat these steps for each Spark 3.5 VC in which HOL participants will work through the labs.

The script targets the Virtual Cluster passed as the `<vcluster-endpoint>` argument (its CDE Jobs API URL), so you don't need to edit your ~/.cde/config.yaml between runs.

Deployment script command template:

```
% ./setup/deploy_hol_resources.sh <cdp-workload-user> <vcluster-endpoint> <demo>
```

For example:

```
#AWS
% ./setup/deploy_hol_resources.sh <cdp-workload-user> https://<vc-id>.cde-<service-id>.<env>.a465-9q4k.cloudera.site/dex/api/v1 bank
```

```
#Azure
% ./setup/deploy_hol_resources.sh <cdp-workload-user> https://<vc-id>.cde-<service-id>.<env>.a465-9q4k.cloudera.site/dex/api/v1 manufacturing
```

#### 3. Airflow Configurations

In this step you will install the GitHub operator in the Airflow Python Environment and create the GitHub Airflow connection in all the Spark 3.5 VC's used throughout the labs. You must repeat these steps for each Spark 3.5 VC in which HOL participants will work through the labs.

First, open the Airflow tab of the Virtual Cluster Details page and install the GitHub operator as shown below.

![alt text](../img/airflow-pyenv-view.png)

![alt text](../img/validate-configs.png)

![alt text](../img/build-pyenv.png)

![alt text](../img/building-pyenv.png)

![alt text](../img/activate-pyenv.png)

![alt text](../img/pyenv-built.png)

Then, create the GitHub Connection. Make sure to name the Connection ID with "default_github" and then paste the GitHub token in the respective field.

![alt text](../img/airflow-ui.png)

![alt text](../img/airflow-connection-1.png)

![alt text](../img/airflow-connection-2.png)

![alt text](../img/airflow-connection-3.png)

#### 4. Participant IDE Environment

Participants run the CDE CLI and Spark Connect from JupyterLab. Pick one of the following options:

1. **Local Docker (default):** participants run `docker run -p 8888:8888 pauldefusco/cde_126_hol` on their own machine. No admin action is needed.
2. **EC2 with Docker:** launch one EC2 instance per participant with `setup/aws-bootstrap.sh` as user data. It runs the same container on port 80.
3. **EC2 without Docker:** launch one EC2 instance per participant with `setup/aws-bootstrap-native.sh` as user data. It installs Python 3.11, JupyterLab, the CDE CLI and the CDE 1.26 Spark Connect packages directly on the instance and serves JupyterLab on port 80 as a systemd service.

For options 2 and 3, follow the [EC2 Setup Guide](https://github.com/pdefusco/CDE_126_HOL/tree/main/setup#ec2-setup-guide) below.

##### Rebuilding the Docker Image

The image bakes in the CDE 1.26 CLI and Spark Connect tarballs. The large binaries are not committed to git; they are published as assets of the `v1.26-assets` GitHub Release. To rebuild and push the image:

1. Download the `cdeconnect` tarball from the Connect tab of a Spark Connect session in your 1.26 Virtual Cluster and place it in `spark-connect/`.
2. Run `./docker/build.sh`. It downloads the CLI and pyspark tarball from the release if missing, then builds for linux/amd64 and pushes `pauldefusco/cde_126_hol:1.26.1` and `:latest`. Use `./docker/build.sh --no-push` to build locally only.


## EC2 Setup Guide

Use this guide when participants can't run Docker on their own machines. You launch one EC2 instance per participant, and each instance serves JupyterLab on port 80 with everything the labs need already installed. Participants only need a browser.

There are two bootstrap scripts. Both were validated on Amazon Linux 2023 (x86_64) with t3.large instances:

| Script | What it does | Participant terminal |
|---|---|---|
| `setup/aws-bootstrap.sh` | Installs Docker and runs the `pauldefusco/cde_126_hol:latest` container on port 80 | Inside the container, as `cdeuser` |
| `setup/aws-bootstrap-native.sh` | Installs Python 3.11, JupyterLab, the CDE 1.26 CLI and the Spark Connect tarballs directly on the instance, and runs JupyterLab as a systemd service on port 80 | On the instance, as `ec2-user` |

Either way, participants get the same home folder layout as the Docker image: the lab files, the `cdeconnect` and `pyspark` tarballs, and template `~/.cde/config.yaml` and `~/.cdp/credentials` files. They then follow the guides unchanged, starting with the `pip3 install` step in Lab 2.

#### Prerequisites

* AWS CLI v2, logged in to the target account and region, with permissions to create security groups and key pairs and to run and terminate EC2 instances.
* Enough EC2 vCPU quota for the event: each t3.large uses 2 vCPUs. Request a quota increase in advance for large events.
* The participants' public IP ranges, or your corporate egress range, for the security group.

The commands below use shell variables. Run them in the same terminal session.

#### 1. Pick a Region and a Public Subnet

The instances need a public IP and an internet gateway route to install packages, clone this repository and download the release assets. The default VPC's subnets work:

```
export AWS_REGION=us-east-2

aws ec2 describe-subnets --filters Name=default-for-az,Values=true \
  --query 'Subnets[].[SubnetId,AvailabilityZone,VpcId]' --output text

VPC_ID=<vpc-id>
SUBNET_ID=<subnet-id>
```

#### 2. Create a Security Group

JupyterLab is token-less by default, so only allow port 80 from participant IP ranges. Port 22 is optional and only needed for troubleshooting from your own IP.

```
SG_ID=$(aws ec2 create-security-group --group-name cde-126-hol \
  --description "CDE 1.26 HOL participant JupyterLab" \
  --vpc-id $VPC_ID --query GroupId --output text)

aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr <participant-cidr>
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr <your-ip>/32
```

#### 3. Optional: Create a Key Pair

A key pair lets you SSH into an instance to check the bootstrap log.

```
aws ec2 create-key-pair --key-name cde-126-hol --key-type ed25519 \
  --query KeyMaterial --output text > cde-126-hol.pem
chmod 600 cde-126-hol.pem
```

#### 4. Optional: Set a JupyterLab Password

For `setup/aws-bootstrap-native.sh` only, set `JUPYTER_PASSWORD` at the top of the script before launching. All instances get the same password. Leave it empty for token-less access. `setup/aws-bootstrap.sh` is always token-less, so rely on the security group.

#### 5. Launch the Instances

Look up the latest Amazon Linux 2023 AMI, pick a script, and launch one instance per participant. The 30 GB root volume leaves room for the pyspark install (and the Docker image, for the Docker option). Drop `--key-name` if you skipped step 3.

```
AMI_ID=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query Parameter.Value --output text)

BOOTSTRAP=setup/aws-bootstrap-native.sh   # or setup/aws-bootstrap.sh for the Docker option
PARTICIPANTS=10

aws ec2 run-instances --image-id $AMI_ID --instance-type t3.large --count $PARTICIPANTS \
  --subnet-id $SUBNET_ID --security-group-ids $SG_ID --associate-public-ip-address \
  --key-name cde-126-hol \
  --block-device-mappings 'DeviceName=/dev/xvda,Ebs={VolumeSize=30,VolumeType=gp3,DeleteOnTermination=true}' \
  --user-data file://$BOOTSTRAP \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=cde-126-hol},{Key=hol,Value=cde-126-hol}]' \
  --query 'Instances[].InstanceId' --output text
```

#### 6. Hand Out the URLs

Bootstrapping takes about 5 minutes after an instance reaches the running state. List the public IPs and assign one to each participant, along with their HOL username (user001, user002, ...):

```
aws ec2 describe-instances --filters Name=tag:hol,Values=cde-126-hol Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].[InstanceId,PublicIpAddress]' --output table
```

Participants open `http://<public-ip>/lab` in their browser.

#### 7. Verify an Instance

Open `http://<public-ip>/lab`. If you created a key pair, you can also check the bootstrap on the instance:

```
ssh -i cde-126-hol.pem ec2-user@<public-ip>

cloud-init status --wait                     # waits until the bootstrap finishes, then prints "status: done"
sudo tail -3 /var/log/user-data.log          # ends with "Bootstrap Script Completed"

# Native option
systemctl status jupyterlab
bash -lc "python --version; cde --version"   # Python 3.11.x, cde version 1.26.1

# Docker option
sudo docker ps                               # cde-hol-web, 0.0.0.0:80->8888/tcp
sudo docker exec cde-hol-web bash -c "python --version; cde --version"
```

#### Troubleshooting

* **The page doesn't load:** check that the participant's IP is inside the security group's port 80 range, that the instance has a public IP, and that the bootstrap has finished (`cloud-init status`).
* **The bootstrap failed:** read `/var/log/user-data.log`. Both scripts stop at the first error, so the last lines show the failing step. The most common cause is a subnet without internet access.
* **JupyterLab stopped responding:** run `sudo systemctl restart jupyterlab` (native) or `sudo docker restart cde-hol-web` (Docker).

#### EC2 Teardown

Terminate the instances after the event, then delete the security group and key pair:

```
IDS=$(aws ec2 describe-instances --filters Name=tag:hol,Values=cde-126-hol \
  Name=instance-state-name,Values=pending,running,stopping,stopped \
  --query 'Reservations[].Instances[].InstanceId' --output text)

aws ec2 terminate-instances --instance-ids $IDS
aws ec2 wait instance-terminated --instance-ids $IDS
aws ec2 delete-security-group --group-id $SG_ID
aws ec2 delete-key-pair --key-name cde-126-hol && rm cde-126-hol.pem
```

## Teardown Instructions

When you are done run this script to tear down the data in the Catalog but not in S3. That step will be handled by the GOES teardown scripts. It drops each participant's HOL_DB_userNNN and db_1M_userNNN (optional compaction lab) databases and the participant tables created in the default database.

```
% ./setup/teardown.sh <cdp-workload-user> <max-participants>
```

For example:

```
% ./setup/teardown.sh <cdp-workload-user> 2
```

## Python Utils

#### Destroy All Jobs for an HOL Participant

You can delete all jobs created by a particular hol user by running the "setup/destroy_jobs.py" script from your local machine.

This is useful when a particular hol participant needs to start the labs from scratch after having completed only some of the labs.

Before running, edit the following parameters:

* Lines 48, 49: add Jobs API URL's of Virtual Clusters where you want to remove the user's jobs.
* Line 50: add hol_username e.g. "user001"
* Line 52: workload username for authenticating against the CDE VC.
* Line 53: workload password for authenticating against the CDE VC.

## Summary

You can deploy an end to end CDE Demo with the provided automation. The demo executes a small ETL pipeline including Iceberg, Spark and Airflow.
