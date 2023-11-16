#!/bin/bash
###
### Common functions for p2p-migration script
### AO Exo-soft 2023 
### Author: Kalinichenko Ilya 
### mailto: i.kalinichenko@ispsystem.com
###

. ./vars.sh
post() {
	data="$1"
	VM_URL="$2"
	if [ -n "$4" ]; then
		token="$4"
		curl -ks -H "x-xsrf-token: $token" -H "ses6: $token" -H  "accept: application/json" -H  "Content-Type: application/json" -X POST  -d "$data" $VM_URL/$3
	else
		curl -ks -H  "accept: application/json" -H  "Content-Type: application/json" -X POST  -d "$data" $VM_URL/$3
	fi
} 
get() {
	TOKEN=$1
	VM_URL=$2
	URL=$3
	curl -ks -H  "accept: application/json" -H  "Content-Type: application/json" -H "x-xsrf-token: $TOKEN" -H "ses6: $TOKEN" $VM_URL/$URL
}
NC='\033[0m' # No Color

pprint() {
        GREEN='\033[0;32m'
        echo -e "===> $(date) ${GREEN}${1}${NC}"
}
perror() {
        RED='\033[0;31m'
        echo -e "===> $(date) ${RED}${1}${NC}"
}
check_err() {
	if echo $1 | grep -q '"error"'; then
		perror "Request failed with error: $1"
		exit 1
	fi
}
usage() {
	cat << EOF 
Usage:
	Please fill variables in vars.sh
	Please, configure SSH access from your server to VMmanager masters

	We need jq to work with json, please install it maually 
	We need curl to work with API, please install it manually

	p2p_import.sh [vm id] Start migrating VM with id 

EOF
}
login() {
	token_json=$(post '{"email": "'$2'", "password": "'$3'"}' $1 'auth/v4/public/token')
	first_login=1
	while echo $token_json | grep -q error 
	do
		if [ "$first_login" -gt 1 ]; then
			perror "Can't login to $1, do another try"
		fi
		sleep 5
		token_json=$(post '{"email": "'$2'", "password": "'$3'"}' $1 'auth/v4/public/token')
		first_login=2
	done 
	echo $token_from_json | jq -r '.token' > token
}
if [ -z "$1" ]; then
	usage
	exit
fi	
if [ "x$1" = "x--help" ] || [ "x$1" = "x-h" ]; then
	usage
	exit
fi
# We need jq to work with json
# We need curl to work with API
dpkg -l jq >/dev/null 2>/dev/null || usage
dpkg -l curl >/dev/null 2>/dev/null || usage

pprint "Get auth tokens"
login $VM_FROM_URL $VM_FROM_LOGIN $VM_FROM_PASS
token_from=$(cat token)
login $VM_DEST_URL $VM_DEST_LOGIN $VM_DEST_PASS
token_dest=$(cat token)
