#!/usr/bin/env bash

BASE_URL=${BASE_URL:-"http://$(dig +short nginx.service.consul):${BASE_PORT:-8888}"}
MAX_ITERATIONS=${MAX_ITERATIONS:-1000}

declare -a good=("" "demo" "demo/assets" "demo/images")
declare -a bad=("dummy" "demo/wrong" "demo/test/bad")

get_url() {
	max=$((RANDOM%MAX_ITERATIONS))
	echo "Running get_url on $BASE_URL/$1 for $max iterations"
	for i in $(seq 1 $max); do
		curl -so /dev/null "$BASE_URL/$1"
	done
}

# Loop forever
while true; do
	# Sleep for a random period from 5s to 30s
	s=$(((RANDOM%31)+5))
	echo "Sleeping for $s seconds"
	sleep $s
	# Randomize errors vs legitimate access
	if [ $(((RANDOM%100)%2)) -eq 0 ]; then
		get_url ${good[$((RANDOM%${#good[@]}))]}
	else
		get_url ${bad[$((RANDOM%${#bad[@]}))]}
	fi
done