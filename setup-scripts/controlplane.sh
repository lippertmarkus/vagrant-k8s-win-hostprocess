kubernetes_version=${1}

printf "##############################\nSetup networking prerequisites\n##############################\n"
sudo modprobe br_netfilter
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

printf "##############################\nDisabling swap\n##############################\n"
sudo sed -i '/swap.img/s/^/#/' /etc/fstab
sudo swapoff -a

printf "##############################\nDisabling firewall\n##############################\n"
sudo ufw disable

printf "##############################\nInstall kubelet, kubeadm, kubectl in specific version\n##############################\n"
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet=$kubernetes_version\* kubeadm=$kubernetes_version\* kubectl=$kubernetes_version\*
sudo apt-mark hold kubelet kubeadm kubectl

printf "##############################\nInstall docker\n##############################\n"
# TODO move to containerd
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
sudo systemctl enable docker.service
sudo systemctl enable containerd.service
echo '{ "exec-opts": ["native.cgroupdriver=systemd"] }' | sudo tee /etc/docker/daemon.json
sudo systemctl restart docker

printf "##############################\nInit cluster with kubeadm\n##############################\n"
ip=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
sed -i "s/controlPlaneEndpoint: DONOTCHANGE/controlPlaneEndpoint: $ip:6443/" kubeadm-config.yml
sed -i "s/kubernetesVersion: DONOTCHANGE/kubernetesVersion: $kubernetes_version/" kubeadm-config.yml
sudo kubeadm init --config kubeadm-config.yml

printf "##############################\nSetting up kubeconfig\n##############################\n"
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

printf "##############################\nUntainting controlplane\n##############################\n"
kubectl taint nodes --all node-role.kubernetes.io/master-

printf "##############################\nSetup Calico CNI with VXLAN\n##############################\n"
curl https://docs.projectcalico.org/manifests/calico.yaml -O
sed -i 's/value: "Always"/value: "REPLACEME"/' calico.yaml
sed -i 's/value: "Never"/value: "Always"/' calico.yaml
sed -i 's/value: "REPLACEME"/value: "Never"/' calico.yaml
sed -i 's/calico_backend: "bird"/calico_backend: "vxlan"/' calico.yaml
sed -i 's/- -bird-live/#- -bird-live/' calico.yaml
sed -i 's/- -bird-ready/#- -bird-ready/' calico.yaml
kubectl apply -f calico.yaml 

printf "##############################\nSmoke testing Linux nodes\n##############################\n"
curl -o nginx-lin.yml -LO https://raw.githubusercontent.com/kubernetes/website/main/content/en/examples/service/networking/run-my-nginx.yaml
echo "      nodeSelector:" >> nginx-lin.yml
echo "        kubernetes.io/os: linux" >> nginx-lin.yml
kubectl apply -f nginx-lin.yml
kubectl create -f https://raw.githubusercontent.com/kubernetes/website/main/content/en/examples/service/networking/nginx-svc.yaml

printf "##############################\nInstalling Calico for Windows via hostprocess daemonsets\n##############################\n"
kubectl create -f https://raw.githubusercontent.com/kubernetes-sigs/sig-windows-tools/master/hostprocess/calico/calico.yml

printf "##############################\nInstalling kube-proxy for Windows iva hostprocess daemonsets\n##############################\n"
curl -o kube-proxy-win.yml -LO "https://raw.githubusercontent.com/kubernetes-sigs/sig-windows-tools/master/hostprocess/calico/kube-proxy/kube-proxy.yml"
sed -i "s/image: [^\n]\+/image: sigwindowstools\/kube-proxy:v$kubernetes_version-calico-hostprocess/" kube-proxy-win.yml
kubectl apply -f kube-proxy-win.yml

printf "##############################\nGenerating kubeadm join command\n##############################\n"
rm -f /share/kubeadm-join-command.txt
kubeadm token create --print-join-command > /share/kubeadm-join-command.txt

printf "##############################\nWriting Kubeconfig to share\n##############################\n"
rm -f /share/kubeconfig
cp $HOME/.kube/config /share/kubeconfig