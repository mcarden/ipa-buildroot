# WARNING

I'll be rebasing this lots, so if you use it while this message is still
here, it will probably break.

# OpenStack Ironic Python Agent

This is a [Buildroot](https://buildroot.org) based Ironic Python Agent
for OpenStack experiment.

This document assumes you are running a Linux distribution (and more
specifically, probably Fedora).

## How the build works

Buildroot is a popular open source tool for building embedded Linux
systems. It supports many popular (and generic) platforms, however it
can also be extended to support third party platforms.

We will track a stable version of Buildroot, and create an extra set
of configs to support our own third party platforms.

It's then a matter of telling Buildroot where these extra configs are
so that we can build our own Ironic Python Agent images.

## Getting Buildroot

This Git repository (_ipa-buildroot_) contains our configuration files
for building the IPA image (in the _buildroot-ipa_ subdirectory).

This repo also uses a Git submodule to pull in a stable release of the
upstream Buildroot Git repository for us to build against (in the
_buildroot_ subdirectory).

We shouldn't modify anything in the upstream Buildroot repository, but
rather put any changes in our own configuration space.

### Git clone

Clone the ipa-buildroot repo wherever you like (for example,
~/ipa-buildroot/ which we will use below).

_Substitute the directory as appropriate._

When cloning the ipa-buildroot repository, simply clone with the added
_--recursive_ option, to pull in the upstream Buildroot repo.

	cd ~
	git clone --recursive https://github.com/csmart/ipa-buildroot

Alternatively, if you have already cloned this ipa-buildroot repository
on its own, you can initialise and clone the submodules manually.

	cd ~/ipa-buildroot/
	git submodule init
	git submodule update

Now you should have both of the repos required to build an image!

### Directory structure

Inside this main ipa-buildroot repository will be four directories which
are used to build your images.

| Directory | Description |
| --- | --- |
| buildroot | Upstream Buildroot source code |
| buildroot-ipa | Ironic Python Agent image configurations for Buildroot |
| dl | Cache directory for source code tarballs |
| output | Output directory for builds in timestamped subdirectories |
| ccache | Directory for storing ccache files to speed up subsequent builds |

We will export variables later to help use these.

## Build dependencies

For a list of build dependencies, see the Buildroot documentation.

https://buildroot.org/downloads/manual/manual.html#requirement

### Fedora

Something like this should be about right.

	sudo dnf install bash bc binutils bison bzip2 cmake cpio \
	flex gcc gcc-c++ gzip make ncurses-devel patch perl \
	python rsync sed tar texinfo unzip wget which

Install tools for downloading source.

	sudo dnf install bzr cvs git mercurial rsync subversion

Install deps for busybox menuconfig.

	sudo dnf install 'perl(ExtUtils::MakeMaker)' 'perl(Thread::Queue)'

Including ccache will help speed up subsequent builds and is highly
recommended. All you have to do is install it and Buildroot will use it.

	sudo dnf install ccache

### Ubuntu

Something like this should be about right.

	sudo apt-get install bc build-essential libncurses5-dev libc6:i386 texinfo unzip

Install tools for downloading source.

	sudo apt-get install bzr cvs git mercurial rsync subversion

Including ccache will help speed up subsequent builds and is highly
recommended. All you have to do is install it and Buildroot will use it.

	sudo apt-get install ccache

## Building the image

Buildroot makes use of environment variables and it can make our life
easier, too.

In the next steps we're going to export the following variables.

| Variable | Description | Who uses it |
| --- | --- | --- |
| BR2_IPA_REPO | Where this ipa-buildroot Git repo was cloned, e.g. ~/ipa-buildroot | Local |
| BR2_UPSTREAM | Where upstream Buildroot Git submodule was cloned, e.g. ~/ipa-buildroot/buildroot | Local |
| BR2_EXTERNAL | Our Ironic Python Agent Buildroot configs, e.g. ~/ipa-buildroot/buildroot-ipa | Buildroot |
| BR2_CCACHE_DIR | Where Buildroot should write ccache fragments to speed up subsequent builds, e.g. ~/ipa-buildroot/ccache | Buildroot |
| BR2_DL_DIR | Where Buildroot should cache downloaded source code tarballs, e.g. ~/ipa-buildroot/dl | Buildroot |
| BR2_OUTPUT_DIR | Where Buildroot conducts builds and saves built images, e.g. ~/ipa-buildroot/output | Local |

### Step 1

First, let's export the location of this cloned ipa-buildroot Git repo, as
other variables will be relative to it. Substitute with the path to where you
cloned this repo.

_Substitute this directory as appropriate, based on where you cloned this repo._

	export BR2_IPA_REPO="${HOME}/ipa-buildroot"

Let's export the BR2_EXTERNAL variable to tell Buildroot where the IPA
specific configs are inside the cloned ipa-buildroot Git repository is so
that it can find our IPA specific customisations. Without this, Buildroot
will not include our IPA configs and won't be able to build our image.

	export BR2_EXTERNAL="${BR2_IPA_REPO}/buildroot-ipa"

Let's also set the location of the upstream Buildroot code, for convenience.

	export BR2_UPSTREAM="${BR2_IPA_REPO}/buildroot"

Next, let's tell Buildroot to cache downloads, which can save time and bandwidth
when rebuilding. This directory is ignored by Git.

	export BR2_DL_DIR="${BR2_IPA_REPO}/dl"

If you're using ccache, let's tell Buildroot where to write those files. This
directory is ignored by Git.

	export BR2_CCACHE_DIR="${BR2_IPA_REPO}/ccache"

### Step 2

We will build from an output dir utilising Buildroot's out-of-tree support.
This directory is ignored by Git.

	export BR2_OUTPUT_DIR="${BR2_IPA_REPO}/output"
	cd "${BR2_OUTPUT_DIR}"

Or alternatively, specify a _unique_ output dir if you need to perform concurrent
builds.

	export BR2_OUTPUT_DIR="$(mktemp -d -p ${BR2_IPA_REPO}/buildroot-output \
	-t "$(date +%s)-XXXXXX")"
	cd "${BR2_OUTPUT_DIR}"

Now let's list all the available Buildroot configs.

	make -C "${BR2_UPSTREAM}" list-defconfigs

If this worked, you should be able to see IPA configurations under
"External configs."

> External configs in "Buildroot configuration for OpenStack IPA":<br>
> openstack_ipa_defconfig - Build for openstack_ipa

### Step 3

Now we can load the default IPA config.

	make O="${BR2_OUTPUT_DIR}" -C "${BR2_UPSTREAM}" openstack_ipa_defconfig

**Note:** From now on we do not specify the output directory (O=) and change to
source directory (-C) options. After the first time, Buildroot will write a
configuration file in the output directory and remember automatically in the future.

### Step 4 (Optional)

Optionally, make any Buildroot configuration changes you want.

	make menuconfig

Optionally, make any Busybox configuration changes you want (note this
will do some downloading and extracting first).

	make busybox-menuconfig

Optionally, make any Linux kernel configuration changes you want (note
this will do some downloading, extracting and building first).

	make linux-menuconfig

### Step 5

Finally, make the image! Note that you should **not** use -j option with make,
it is set in the config and determined automatically. Specifying -j here may
cause Buildroot components to be built out of order, causing a failure.

	make

A successful build should create both a Linux kernel image and the IPA
initramfs in the ${BR2_OUTPUT_DIR}/images directory.

> bzImage<br>
> rootfs.cpio.xz

### Testing the image

You can test the kernel and initramfs images in QEMU.

	qemu-system-x86_64 \
	-enable-kvm \
	-cpu host \
	-m 1G \
	-kernel images/bzImage \
	-append earlyprintk \
	-initrd images/rootfs.cpio.xz \
	-netdev user,id=net0 \
	-device e1000,netdev=net0

You should see a login prompt, the default user is root with no password.

## Saving changes

If you made changes to the Buildroot, Linux kernel or Busybox configs, you
can save them over the top of the existing configs in the IPA buildroot repo.

	make savedefconfig
	make linux-savedefconfig && make linux-update-defconfig
	make busybox-update-config

Then back in the ipa-buildroot repository you can use Git to review/commit
them.

