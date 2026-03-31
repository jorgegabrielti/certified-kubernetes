#!/bin/bash 
#
# ##########################################################################
# +----------------------------------------------------------------------+ #
# |                 Cluster Kubernetes - Kubeadm                         | #
# +----------------------------------------------------------------------+ #
# |                                                                      | #
# | Name          : provision.sh                                         | #
# | Function      : Cluster Kubernetes install and                       | #
# |                      configuration with Kubeadm.                     | #
# | Version       : 1.0                                                  | #
# | Author        : Jorge Gabriel (Site Releability Engeneer)            | #
# +----------------------------------------------------------------------+ #
# ##########################################################################
#
# Description:
#
# Algortimo do script :
#  Instalação do Cluster com Kubeadm.
# --------------------------------------------------------------------------

# Exit on error, undefined variable, or error in pipeline
set -euo pipefail

grep swap /etc/fstab && swapoff -a && sudo sed -i '/swap/d' /etc/fstab || echo "Swap memory: OK"

which netplan || sudo apt-get install -y netplan.io

sudo cat <<EOF | sudo tee /etc/netplan/50-vagrant.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s8:
      dhcp4: no
      addresses:
        - 192.168.1.100/24
EOF

sudo chmod 600 /etc/netplan/50-vagrant.yaml
sudo netplan apply

sudo apt-get update
sudo apt-get install -y net-tools conntrack socat ipset ipvsadm
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

sudo echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update

sudo apt list -a kubectl
sudo apt list -a kubelet
sudo apt list -a kubeadm

sudo apt install -y kubelet kubeadm kubectl

sudo apt-mark hold kubelet kubeadm kubectl

sudo cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

sudo cat <<EOF | sudo tee /etc/sysctl.d/kubernetes.conf
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
net.ipv6.conf.all.forwarding = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.conf.all.rp_filter = 0
net.ipv6.conf.all.rp_filter = 0
EOF

sudo sysctl --system

sudo systemctl enable --now kubelet

sudo apt install -y containerd

sudo mkdir -p /etc/containerd

sudo containerd config default | sudo tee /etc/containerd/config.toml

sudo sed -i 's/SystemdCgroup.*/SystemdCgroup = true/g' /etc/containerd/config.toml

sudo systemctl enable --now containerd

# export INTERNAL_NETWORK_IP="$(ip a show enp0s8 | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)"

export INTERNAL_NETWORK_IP="$(ip a show enp0s8 | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)"
echo "KUBELET_EXTRA_ARGS=--node-ip=${INTERNAL_NETWORK_IP}" | sudo tee /etc/default/kubelet
sudo systemctl daemon-reexec
sudo systemctl restart kubelet


sudo kubeadm init \
  --apiserver-advertise-address=${INTERNAL_NETWORK_IP} \
  --pod-network-cidr=10.244.0.0/16

export HOME="/home/vagrant" USER="vagrant"
#grep -i "ubuntu" /etc/passwd && export HOME="/home/ubuntu" USER="ubuntu" || export HOME="/home/vagrant" USER="vagrant"

mkdir -p $HOME/.kube

sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config

sudo chown $USER:$USER $HOME/.kube/config

### CNI - Container Network Interface
# https://docs.cilium.io/en/latest/installation/k8s-install-kubeadm/#create-the-cluster

CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

#sleep 60 && cilium install 
#\
#  --helm-set kubeProxyReplacement=disabled \
#  --helm-set k8sServiceHost=${INTERNAL_NETWORK_IP} \
#  --helm-set k8sServicePort=6443

sleep 60 && cilium install

kubeadm token create --print-join-command

sudo reboot