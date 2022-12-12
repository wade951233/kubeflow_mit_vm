# 提示使用者輸入
read -p "Please input your master ip: " master_ip
read -p "Please input your node1 ip: " node1_ip      # 提示使用者輸入
read -p "Please input your node2 ip: " node2_ip      # 提示使用者輸入

snap install helm --classic
apt update && apt -y upgrade
apt install -y nfs-server
mkdir /data

cat << EOF >> /etc/exports
/data ${node1_ip}(rw,no_subtree_check,no_root_squash)
/data ${node2_ip}(rw,no_subtree_check,no_root_squash)
EOF

systemctl enable --now nfs-server
exportfs -ar


helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner

helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --create-namespace \
  --namespace nfs-provisioner \
  --set nfs.server=${master_ip} \
  --set nfs.path=/data

kubectl patch storageclass nfs-client -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

kubectl apply -f ./pvc.yaml
