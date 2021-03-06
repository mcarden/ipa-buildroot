#!/usr/bin/env bash

## We use this script to compile Python wheels for IPA
## These are installed in the target on boot via systemd service

# We want to know if anything fails
set -xue
set -o pipefail

# Path to target is always first argument
BR2_TARGET_DIR="${1}"

# IPA and Requirements versions are set in Buildroot config
# These are passed through as arguments to this script
OPENSTACK_REQUIREMENTS_RELEASE="${2:-master}"
OPENSTACK_IPA_RELEASE="${3:-master}"

# URL to upper-constraints.txt (from Requirements repo) and
# URL to requirements.txt from Ironic Python Agent repo)
# Needed for building Python wheels
OPENSTACK_REQUIREMENTS_URL="https://git.openstack.org/cgit/openstack/requirements/plain/upper-constraints.txt"
OPENSTACK_IPA_URL="https://git.openstack.org/cgit/openstack/ironic-python-agent/plain/requirements.txt"

# Variables to do Python builds for target
PATH="${HOST_DIR}/bin:${HOST_DIR}/sbin:${HOST_DIR}/usr/bin:${HOST_DIR}/usr/sbin:${PATH}"
CC="${HOST_DIR}/usr/bin/toolchain-wrapper"
CFLAGS="-D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 -Os "
LDFLAGS=""
LDSHARED="${HOST_DIR}/usr/bin/toolchain-wrapper -shared"
PYTHONPATH="${BR2_TARGET_DIR}/usr/lib/python2.7/sysconfigdata/:${BR2_TARGET_DIR}/usr/lib/python2.7/site-packages/"
_python_sysroot="$(find ${HOST_DIR} -type d -name sysroot)"
_python_prefix=/usr
_python_exec_prefix=/usr

# Get pip and install deps for creating Python wheels for IPA
rm -f "${BR2_TARGET_DIR}/get-pip.py"
wget https://bootstrap.pypa.io/get-pip.py -O "${BR2_TARGET_DIR}/get-pip.py"
"${HOST_DIR}/usr/bin/python" "${BR2_TARGET_DIR}/get-pip.py"
"${HOST_DIR}/usr/bin/pip" install pbr setuptools

# Bundle up IPA source
pushd ~/code/openstack/ironic-python-agent
"${HOST_DIR}/usr/bin/python" setup.py sdist --dist-dir "${HOST_DIR}/localpip" --quiet
popd

# Create Python wheels using:
# * upper-constraints.txt from Requirements repo
# * requirements.txt from Ironic Python Agent repo
"${HOST_DIR}/usr/bin/pip" wheel -c "${OPENSTACK_REQUIREMENTS_URL}?h=${OPENSTACK_REQUIREMENTS_RELEASE}" --wheel-dir "${BR2_TARGET_DIR}/wheelhouse" setuptools
"${HOST_DIR}/usr/bin/pip" wheel -c "${OPENSTACK_REQUIREMENTS_URL}?h=${OPENSTACK_REQUIREMENTS_RELEASE}" --wheel-dir "${BR2_TARGET_DIR}/wheelhouse" pip
"${HOST_DIR}/usr/bin/pip" wheel -c "${OPENSTACK_REQUIREMENTS_URL}?h=${OPENSTACK_REQUIREMENTS_RELEASE}" --wheel-dir "${BR2_TARGET_DIR}/wheelhouse" -r "${OPENSTACK_IPA_URL}?h=${OPENSTACK_IPA_RELEASE}"
"${HOST_DIR}/usr/bin/pip" wheel -c "${OPENSTACK_REQUIREMENTS_URL}?h=${OPENSTACK_REQUIREMENTS_RELEASE}" --no-index --pre --wheel-dir "${BR2_TARGET_DIR}/wheelhouse" --find-links="${HOST_DIR}/localpip" --find-links="${BR2_TARGET_DIR}/wheelhouse" ironic-python-agent

# Python packages which rely on ldconfig in the target are not supported
# Monkey patch these
# Use Buildroot's patched versions instead
for package in \
	pydev
do
	find "${BR2_TARGET_DIR}/wheelhouse/" -type f -name ${package}* -exec rm -f {} \;
done

# Ensure any SSH keys and configs have appropriate permissions,
# else it may fail to start and that would make life hard
# (Commands are separated out for clarify)
# System keys and configs
if [[ -d "${BR2_TARGET_DIR}/etc/ssh" ]]; then
	find "${BR2_TARGET_DIR}/etc/ssh" -type f -name ssh_config -exec chmod 0644 {} \;
	find "${BR2_TARGET_DIR}/etc/ssh" -type f -name "*pub" -exec chmod 0644 {} \;
	find "${BR2_TARGET_DIR}/etc/ssh" -type f -name sshd_config -exec chmod 0600 {} \;
	find "${BR2_TARGET_DIR}/etc/ssh" -type f -name "*key" -exec chmod 0600 {} \;
fi
# root's keys and config
find "${BR2_TARGET_DIR}/root" -type f -name .rhosts -exec chmod 0600 {} \;
find "${BR2_TARGET_DIR}/root" -type f -name .shosts -exec chmod 0600 {} \;
if [[ -d "${BR2_TARGET_DIR}/root/.ssh" ]]; then
	# Enable root logins via ssh keys only, if we detect a public key
	# This is for convenience, it's better to provide new sshd_config in overlay
	if [[ -f "${BR2_TARGET_DIR}/root/.ssh/authorized_keys" ]]; then
		sed -i 's/^#PermitRootLogin.*/PermitRootLogin\ prohibit-password/g' "${BR2_TARGET_DIR}/etc/ssh/sshd_config"
	fi
	# Ensure root's home directory and other SSH related files are restricted
	chmod 0700 ${BR2_TARGET_DIR}/root
	chmod 0700 ${BR2_TARGET_DIR}/root/.ssh
	find "${BR2_TARGET_DIR}/root/.ssh" -type f -exec chmod 0600 {} \;
fi

## Add any commands below to be run after the build,
## before both fakeroot and image creation

