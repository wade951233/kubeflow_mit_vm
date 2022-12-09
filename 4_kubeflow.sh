cd ./manifests
wget https://github.com/kubernetes-sigs/kustomize/releases/download/v3.2.0/kustomize_3.2.0_linux_amd64
chmod 777 kustomize_3.2.0_linux_amd64
mv kustomize_3.2.0_linux_amd64 /usr/bin/kustomize

kubectl patch storageclass nfs-client -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

while ! kustomize build example | kubectl apply -f -; do echo "Retrying to apply resources"; sleep 10; done


kubectl get po -A --watch