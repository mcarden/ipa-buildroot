#!/usr/bin/env bash

set -xue
set -o pipefail

BR2_TARGET_DIR="${1}"

## Enable ironic-python-agent
mkdir -p "${BR2_TARGET_DIR}/etc/systemd/system/multi-user.target.wants"
ln -sf /etc/systemd/system/ironic-python-agent.service "${BR2_TARGET_DIR}/etc/systemd/system/multi-user.target.wants/"

## Add any commands below to be run in target with fakeroot
## after the build, but before image is created

