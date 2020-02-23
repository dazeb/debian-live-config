#!/usr/bin/make -f

all: install_buildenv build

install_buildenv:
	# Install packages required to build the image
	sudo apt install live-build make build-essential wget git xmlstarlet unzip colordiff shellcheck apt-transport-https rename ovmf rsync

bump_version:
	@last_tag=$$(git tag | tail -n1); \
	echo "Please set version to $$last_tag in Makefile config/bootloaders/isolinux/live.cfg.in config/bootloaders/isolinux/menu.cfg auto/config"

build:
	# Build the live system/ISO image
	#sudo lb clean --purge #only required when changing the mirrors/architecture config
	sudo lb clean --all
	sudo lb config
	sudo lb build

##############################

release: checksums sign_checksums

checksums:
	# Generate checksums of the resulting ISO image
	@mkdir -p iso/
	mv *.iso iso/
	last_tag=$$(git tag | tail -n1); \
	cd iso/; \
	rename "s/live-image/dlc-$$last_tag-debian-buster/" *; \
	sha512sum *.iso  > SHA512SUMS; \

sign_checksums:
	# Sign checksums with a GPG private key
	cd iso; \
	gpg --detach-sign --armor SHA512SUMS; \
	mv SHA512SUMS.asc SHA512SUMS.sign

################################

tests: download_iso test_kvm_bios test_kvm_uefi

download_iso:
	# download the iso image from a build server
	rsync -avP buildbot.xinit.se:/var/dlc/iso ./

test_kvm_bios:
	# Run the resulting image in KVM/virt-manager (legacy BIOS mode)
	sudo virt-install --name dlc-test --boot cdrom --disk path=/dlc-test-disk0.qcow2,format=qcow2,size=20,device=disk,bus=virtio,cache=none --cdrom 'iso/dlc-2.1-rc3-debian-buster-amd64.hybrid.iso' --memory 2048 --vcpu 2
	sudo virsh destroy dlc-test
	sudo virsh undefine dlc-test
	sudo rm /dlc-test-disk0.qcow2

test_kvm_uefi:
	# Run the resulting image in KVM/virt-manager (UEFI mode)
	# UEFI support must be enabled in QEMU config for EFI install tests https://wiki.archlinux.org/index.php/Libvirt#UEFI_Support (/usr/share/OVMF/*.fd)
	sudo virt-install --name dlc-test --boot loader=/usr/share/OVMF/OVMF_CODE.fd --disk path=/dlc-test-disk0.qcow2,format=qcow2,size=20,device=disk,bus=virtio,cache=none --cdrom 'iso/dlc-2.1-rc3-debian-buster-amd64.hybrid.iso' --memory 2048 --vcpu 2
	sudo virsh destroy dlc-test
	sudo virsh undefine dlc-test
	sudo rm /dlc-test-disk0.qcow2
