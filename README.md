# Kubernetes over KVM

This is a terraform project to provision a sample Kubernetes system using KVM virtual machines on a single physical server. The system configuration is done using ubuntu cloud image and cloud-init scripts. Each virtual machine is defined as a separate module with all its configurations contained for a better isolation and maintenance. 

The goal of this project is to create a foundation for a highly available kubernetes cluster. Currectly the provisioned system creates the main components required for a professional grade kubernetes cluster without high availability (i.e. Each kubernetes component is configured as a cluster with one machine only). Once I have the time I will work on a fully configured highly available system.

The system has a DNS server (powerdns) handling a local zone for easy managment in a DHCP environment. 

The provisioned kubernetes system has the following characteristics:

- Container engine: Docker CE
- Cluster Manager: kubeadm
- Networking (CNI): Calico (https://www.projectcalico.org/)
- Storage (CSI): linstor (https://www.linbit.com/en/linstor/) 
- K8 database: etcd 

# Prerequisites:

- Ubuntu Server 18.04 LTS (host machine).
- KVM virtialization engine
- git 
- terraform ver 0.11 (https://terraform.io)
- KVM terraform provider (https://github.com/dmacvicar/terraform-provider-libvirt)
- Bridged network with DHCP support.

# Running the system:

I prepared a shell script to download and configure the physical server. It is a very basic shell script without much intelligence just to get the job done. the steps I've used to configure a new system is as follows:

1) Create a Bridge for VMs network. I'm using ubuntu server with netplan as the network managment system.
```
sudo nano /etc/netplan/01-netcfg.yaml
```
in my system the 01-netcfg.yaml looks like:
```
network:
  version: 2
  renderer: networkd
  ethernets:
    eno1:
      dhcp4: yes
  bridges:
    br0:
      interfaces: [eno1]
      parameters:
        stp: true
      dhcp4: yes 
```
then run the following two commands:
```
sudo netplan generate
sudo netplan apply 
```
The name of the bridge is important. If you create a bridge with a different name please change accordingly in the k8-vars.tf file.

2) Clone this repo somewhere on your system
```
git clone https://github.com/moharam-dev/kubernetes-kvm.git
```

3) Run the installation script 
```
sudo chmod +x setup.sh 
sudo ./setup.sh <<non-root user name>>
```

4) Reboot your physical host

5) Run terraform
```
terraform init
terraform plan -out kubernetes.plan
terraform apply kubernetes.plan
```

That's it :)

You can keep track of the system configuration progress via VM's console (i.e. virsh console command). 
***The default system user name for all vms is 'k8' and the password is 'password'***

```
k8@master:~$ virsh list
 Id    Name                           State
----------------------------------------------------
 1     linstor                        running
 2     master                         running
 3     dns                            running
 4     node1                          running
 5     etcd1                          running
```

after around 15 minutes the system should be up and running. On the master node I got:

```
$> kubectl get nodes
NAME              STATUS   ROLES    AGE   VERSION
master.k8.local   Ready    master   56m   v1.16.1
node1.k8.local    Ready    <none>   55m   v1.16.1

k8@master:~$ kubectl get pods --all-namespaces

NAMESPACE     NAME                                      READY   STATUS    RESTARTS   AGE
kube-system   calico-kube-controllers-b7fb7899c-qxcld   1/1     Running   0          4m35s
kube-system   calico-node-6jvvk                         1/1     Running   0          4m35s
kube-system   calico-node-ts7nj                         1/1     Running   0          3m7s
kube-system   coredns-5644d7b6d9-2hz6m                  1/1     Running   0          4m35s
kube-system   coredns-5644d7b6d9-grhrj                  1/1     Running   0          4m35s
kube-system   kube-apiserver-master.k8.local            1/1     Running   0          3m47s
kube-system   kube-controller-manager-master.k8.local   1/1     Running   0          3m29s
kube-system   kube-proxy-g2z2m                          1/1     Running   0          4m35s
kube-system   kube-proxy-nkkrs                          1/1     Running   0          3m7s
kube-system   kube-scheduler-master.k8.local            1/1     Running   0          3m50s
kube-system   linstor-csi-controller-0                  5/5     Running   0          4m35s
kube-system   linstor-csi-node-r79gs                    2/2     Running   0          2m7s
```

Enjoy :)
