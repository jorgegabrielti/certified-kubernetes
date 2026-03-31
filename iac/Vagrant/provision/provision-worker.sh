#!/bin/bash 
#
# ##########################################################################
# +----------------------------------------------------------------------+ #
# |                 Cluster Kubernetes - Kubeadm                         | #
# +----------------------------------------------------------------------+ #
# |                                                                      | #
# | Name          : provision-worker.sh                                  | #
# | Function      : Kubernete worker node: Install and configuration     | #
#                   with kubeadm                                         | #
# | Version       : 1.0                                                  | #
# | Author        : Jorge Gabriel (Site Releability Engeneer)            | #
# +----------------------------------------------------------------------+ #
# ##########################################################################
#
# Description:
#
# Algortimo do script :
#  Instalação e configuração do worker node com Kubeadm.
# --------------------------------------------------------------------------
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
        - 192.168.1.110/24
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

export INTERNAL_NETWORK_IP="$(ip a show enp0s8 | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)"
echo "KUBELET_EXTRA_ARGS=--node-ip=${INTERNAL_NETWORK_IP}" | sudo tee /etc/default/kubelet
sudo systemctl daemon-reexec
sudo systemctl restart kubelet

sudo reboot