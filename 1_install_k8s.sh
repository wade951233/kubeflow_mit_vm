#!/bin/bash
set -x

if [ -z "$1" ]
then
      echo "k8s node role not input"
      exit 1
else
      echo "k8s node role: $1"
      role=$1
fi

sudo apt-get update
sudo apt-get install helm
apt install -y nfs-common
apt-get install -y docker.io
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

SWAPFILES=$(grep swap /etc/fstab | sed '/^[ \t]*#/ d' | sed 's/[\t ]/ /g' | tr -s " " | cut -f1 -d' ')
if [ ! -z $SWAPFILES ]; then
  for SWAPFILE in $SWAPFILES
  do
    if [ ! -z $SWAPFILE ]; then
      echo "disabling swap file $SWAPFILE"
      if [[ $SWAPFILE == UUID* ]]; then
        UUID=$(echo $SWAPFILE | cut -f2 -d'=')
        swapoff -U $UUID
      else
        swapoff $SWAPFILE
      fi
      sed -i "\%$SWAPFILE%d" /etc/fstab
    fi
  done
fi


# Update the apt package index and install packages needed to use the Kubernetes apt repository:
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
# Download the Google Cloud public signing key:
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
# Add the Kubernetes apt repository:
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
# Update apt package index, install kubelet, kubeadm and kubectl, and pin their version:
sudo apt-get update
# 指定版本
K_VER="1.21.1-00"
sudo apt-get install -y kubelet=${K_VER} kubectl=${K_VER} kubeadm=${K_VER}
# 鎖住版本
sudo apt-mark hold kubelet kubeadm kubectl

cat <<EOF | sudo tee /etc/docker/daemon.json
{
    "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl restart kubelet

cat <<EOF | echo "Environment=”cgroup-driver=systemd/cgroup-driver=cgroupfs”" >>/etc/systemd/system/kubelet.service.d/10-kubeadm.conf
EOF

if [ $role == "node" ];
then
      echo "please join k8s master"
      exit 2
else    
      echo "k8s master"
      sudo kubeadm init --pod-network-cidr=10.244.0.0/16
fi

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

sudo kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

#wait_for_pods_running 8 kube-system

kubectl get po -A
