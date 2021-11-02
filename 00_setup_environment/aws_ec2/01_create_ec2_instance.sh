#!/usr/bin/env bash

# Script builds a single EC2 instance with Rasterio and rio-cogeo installed
#
# Arguments:
#    -p : proxy address (if behind a proxy). e.g. http://myproxy.mycorp.corp:8080
#

SECONDS=0*

# check if proxy server required
while getopts ":p:" opt; do
  case $opt in
  p)
    PROXY=$OPTARG
    ;;
  esac
done

echo "-------------------------------------------------------------------------"
echo " Start time : $(date)"
echo "-------------------------------------------------------------------------"
echo " Set temp local environment vars"
echo "-------------------------------------------------------------------------"

AMI_ID="ami-00764cc25c2985858"  # private AMI - choose your own preferred AMI

#r5d.16xlarge: 64	CPUs, 512GB RAM, 4 x 600 NVMe SSD
INSTANCE_TYPE="r5d.16xlarge"

USER="ec2-user"

SSH_CONFIG="${HOME}/.ssh/aws-sandbox-config"

# load AWS parameters
. ${HOME}/.aws/iag_ec2_vars.sh

# script to check instance status
PYTHON_SCRIPT="import sys, json
try:
    print(json.load(sys.stdin)['InstanceStatuses'][0]['InstanceState']['Name'])
except:
    print('pending')"

# get directory this script is running from
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo "-------------------------------------------------------------------------"
echo " Create EC2 instance and wait for startup"
echo "-------------------------------------------------------------------------"

# create EC2 instance
INSTANCE_ID=$(aws ec2 run-instances \
--image-id ${AMI_ID} \
--count 1 \
--tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=hs_testing}]" \
--instance-type ${INSTANCE_TYPE} \
--key-name ${AWS_KEYPAIR} \
--security-group-ids ${AWS_SECURITY_GROUP} \
--subnet-id ${AWS_SUBNET} \
--iam-instance-profile "Name=${AWS_IAM_PROFILE}" | \
python3 -c "import sys, json; print(json.load(sys.stdin)['Instances'][0]['InstanceId'])")

echo "Instance ${INSTANCE_ID} created"

# this doesn't work everytime, hence the while/do below
aws ec2 wait instance-exists --instance-ids ${INSTANCE_ID}

# wait for instance to fire up
INSTANCE_STATE="pending"
while [ $INSTANCE_STATE != "running" ]; do
    sleep 5
    INSTANCE_STATE=$(aws ec2 describe-instance-status --instance-id  ${INSTANCE_ID} | python3 -c "${PYTHON_SCRIPT}")
    echo "  - Instance status : ${INSTANCE_STATE}"
done

INSTANCE_IP_ADDRESS=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID} | \
python3 -c "import sys, json; print(json.load(sys.stdin)['Reservations'][0]['Instances'][0]['PrivateIpAddress'])")
echo "  - Private IP address : ${INSTANCE_IP_ADDRESS}"

# save instance details to a local file for easy SSH commands
echo "export SCRIPT_DIR=${SCRIPT_DIR}" > ~/git/temp_ec2_vars.sh
echo "export USER=${USER}" >> ~/git/temp_ec2_vars.sh
echo "export SSH_CONFIG=${SSH_CONFIG}" >> ~/git/temp_ec2_vars.sh
echo "export INSTANCE_ID=${INSTANCE_ID}" >> ~/git/temp_ec2_vars.sh
echo "export INSTANCE_IP_ADDRESS=${INSTANCE_IP_ADDRESS}" >> ~/git/temp_ec2_vars.sh

# wait for SSH to start
INSTANCE_READY=""
while [ ! $INSTANCE_READY ]; do
    echo "  - Waiting for ready status"
    sleep 5
    set +e
    OUT=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes ${USER}@$INSTANCE_ID 2>&1 | grep "Permission denied" )
    [[ $? = 0 ]] && INSTANCE_READY='ready'
    set -e
done

echo "-------------------------------------------------------------------------"
echo " Copy AWS credentials & supporting files and run remote script"
echo "-------------------------------------------------------------------------"

# copy AWS creds to access S3
ssh -F ${SSH_CONFIG} -o StrictHostKeyChecking=no ${INSTANCE_ID} 'mkdir ~/.aws'
scp -F ${SSH_CONFIG} -r ${HOME}/.aws/credentials ${USER}@${INSTANCE_ID}:~/.aws/credentials

# copy remote setup script
scp -F ${SSH_CONFIG} ${SCRIPT_DIR}/02_remote_setup.sh ${USER}@${INSTANCE_ID}:~/

# copy test script
scp -F ${SSH_CONFIG} ${SCRIPT_DIR}/../../01_create_cog/create_dem_cog.sh ${USER}@${INSTANCE_ID}:~/

# setup proxy (if required), install packages & environment and import data
if [ -n "${PROXY}" ]; then
  ssh -F ${SSH_CONFIG} ${USER}@${INSTANCE_ID} ". ./02_remote_setup.sh -p ${PROXY}"
else
  ssh -F ${SSH_CONFIG} ${USER}@${INSTANCE_ID} ". ./02_remote_setup.sh"
fi

echo "-------------------------------------------------------------------------"
duration=$SECONDS
echo " End time : $(date)"
echo " Build took $((duration / 60)) mins"
echo "----------------------------------------------------------------------------------------------------------------"

ssh -F ${SSH_CONFIG} ${INSTANCE_ID}
