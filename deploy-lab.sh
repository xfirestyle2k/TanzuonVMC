#!/usr/bin/env bash

clear
echo -e "\033[1m"   #Bold ON
echo " ==========================="
echo "    TKG on VMC deployment"
echo " ==========================="
echo "===== Credentials ============="
echo -e "\033[0m"   #Bold OFF

DEF_ORG_ID="xxxxx"
read -p "Enter your ORG ID (long format) [default=$DEF_ORG_ID]: " TF_VAR_my_org_id
TF_VAR_my_org_id="${TF_VAR_my_org_id:-$DEF_ORG_ID}"
echo ".....Exporting $TF_VAR_my_org_id"
export TF_VAR_my_org_id=$TF_VAR_my_org_id
echo ""

DEF_TOKEN="xxxxx"
read -p "Enter your VMC API token [default=$DEF_TOKEN]: " TF_VAR_vmc_token
TF_VAR_vmc_token="${TF_VAR_vmc_token:-$DEF_TOKEN}"
echo ".....Exporting $TF_VAR_vmc_token"
export TF_VAR_vmc_token=$TF_VAR_vmc_token
echo ""

ACCOUNT="xxxxx"
read -p "Enter your AWS Account [default=$ACCOUNT]: " TF_VAR_AWS_account
TF_VAR_AWS_account="${TF_VAR_AWS_account:-$ACCOUNT}"
echo ".....Exporting $TF_VAR_AWS_account"
export TF_VAR_AWS_account=$TF_VAR_AWS_account
echo ""

#ACCESS="xxxxx"
#read -p "Enter your AWS Access Key [default=$ACCESS]: " TF_VAR_access_key
#TF_VAR_access_key="${TF_VAR_access_key:-$ACCESS}"
#echo ".....Exporting $TF_VAR_access_key"
#export TF_VAR_access_key=$TF_VAR_access_key
#echo ""

#SECRET="xxxxx"
#read -p "Enter your AWS Secret Key [default=$SECRET]: " TF_VAR_secret_key
#TF_VAR_secret_key="${TF_VAR_secret_key:-$SECRET}"
#echo ".....Exporting $TF_VAR_secret_key"
#export TF_VAR_secret_key=$TF_VAR_secret_key
#echo ""


#export ANSIBLE_HOST_KEY_CHECKING=False
#echo ""



echo -e "\033[1m"   #Bold ON
echo "===== PHASE 1: Creating SDDC ==========="
echo -e "\033[0m"   #Bold OFF
cd ./Part1/main
terraform init
terraform apply -auto-approve
cd ../../
export TF_VAR_host=$(terraform output -state=./phase1.tfstate proxy_url)

# read  -p $'Press enter to continue (^C to stop)...\n'
cd ./Part2/main
terraform init

echo -e "\033[1m"   #Bold ON
echo "===== PHASE 2: Security and Networking  ==========="
echo -e "\033[0m"   #Bold OFF
echo ".....Importing CGW and MGW into Terraform phase2."

if [[ ! -f ../../phase2.tfstate ]]
then
  echo "Importing . . . . ."
  terraform import -lock=false module.NSX.nsxt_policy_gateway_policy.mgw mgw/default
  terraform import -lock=false module.NSX.nsxt_policy_gateway_policy.cgw cgw/default
fi
echo ".....CGW, MGW already imported."
terraform apply -auto-approve

echo -e "\033[1m"   #Bold ON
echo "BOOM! Infrastructure is ready!"
echo -e "\033[0m"   #Bold OFF