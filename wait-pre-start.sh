#! /usr/bin/env bash

while [[ ! -f /run/pre-start.done ]]; do
	sleep 1
done

exit 0