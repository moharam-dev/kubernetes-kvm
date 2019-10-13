#! /bin/bash
#
# run this script as root and pass it 
# the user name you will be using to run the demo

TERRAFORM_VER=0.11.12
USER=$1

mkdir ./temp-files
cd ./temp-files

echo "preparing ..."
# tools
apt update
apt install -y wget unzip git

# terraform
echo "installing terraform ... "
wget https://releases.hashicorp.com/terraform/${TERRAFORM_VER}/terraform_${TERRAFORM_VER}_linux_amd64.zip
unzip terraform_${TERRAFORM_VER}_linux_amd64.zip
mv terraform /usr/local/bin/
terraform init
echo "terraform installation complete."


# kvm-terraform provider
echo "installing KVM terraform provider ... "
wget https://github.com/dmacvicar/terraform-provider-libvirt/releases/download/v0.6.0/terraform-provider-libvirt-0.6.0+git.1569597268.1c8597df.Ubuntu_18.04.amd64.tar.gz
tar -xvf terraform-provider-libvirt-0.6.0+git.1569597268.1c8597df.Ubuntu_18.04.amd64.tar.gz

mkdir -p /home/$USER/.terraform.d/plugins
mv terraform-provider-libvirt /home/$USER/.terraform.d/plugins/
chown -R $USER:$USER /home/$USER/.terraform.d

echo "KVM terraform provider installation complete."

# kvm
echo "installing KVM ... "
apt install -y qemu-kvm libvirt-daemon bridge-utils virtinst libvirt-daemon-system
# permission issue : https://github.com/dmacvicar/terraform-provider-libvirt/commit/22f096d9
echo 'security_driver = "none"' >> /etc/libvirt/qemu.conf
# add normal user to libvirt 
usermod -a -G libvirt $USER
systemctl restart libvirtd
echo "KVM installation complete."

# genisoimage
apt install -y genisoimage
ln -s /usr/bin/genisoimage /usr/bin/mkisofs

# prep folders
mkdir -p /home/$USER/k8-demo/config-iso/

# get guest OS
wget https://cloud-images.ubuntu.com/releases/bionic/release/ubuntu-18.04-server-cloudimg-amd64.img
mv ubuntu-18.04-server-cloudimg-amd64.img /home/$USER/k8-demo/

# make sure everything in home is owned by our user
chown -R $USER:$USER /home/$USER/

echo "***********************************"
echo " "
echo "Next steps:"
echo "  - create a bridged network and pass the name of it in k8-vars.tf"
echo "  - reboot your system"
echo " "
echo "***********************************"
echo "setup completed."
echo "***********************************"

cd ..