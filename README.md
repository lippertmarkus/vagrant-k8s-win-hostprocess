# Vagrant: Running Windows HostProcess Pods in a mixed Kubernetes cluster

`Vagrantfile` for deploying a two-node cluster with a Linux controlplane and a Windows Server 2022 worker node with [Windows HostProcess Containers](https://kubernetes.io/blog/2021/08/16/windows-hostprocess-containers/) enabled. [Calico](https://www.tigera.io/project-calico/) is used for networking. CNI configuration, Calico itself and `kube-proxy` are deployed via [HostProcess pods](https://github.com/kubernetes-sigs/sig-windows-tools/tree/master/hostprocess) to the Windows nodes.

Getting started with Windows HostProcess Containers: https://lippertmarkus.com/2021/11/05/k8s-win22-hostprocess/

## Prerequisites

- [Vagrant](https://vagrantup.com/)

- Hyper-V
  ```powershell
  Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
  ```

- Virtual External Switch connected to your main network with DHCP
  ```powershell
  Get-NetAdapter # Find the name of your main network adapter to create a new switch:
  New-VMSwitch -name ExternalSwitch -NetAdapterName Ethernet -AllowManagementOS $true
  ```

- Git-cloning this repository

## Configuration

Within [`setup-scripts/kubeadm-config.yml`](setup-scripts/kubeadm-config.yml) you can adapt the [kubeadm Configuration](https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta2/) to your needs. This is also where the feature gates for `WindowsHostProcessContainers` are enabled for `kubelet` and `api-server`. 

To quickly start, you can leave everything as is, but you should at least verify that the `podSubnet` and `serviceSubnet` do not overlap with your main network and may set `clusterDNS` accordingly.

## Provisioning

Open PowerShell as Administrator, switch to the cloned directory and run
```
vagrant up
```

During provisioning `vagrant` requires two inputs from you for each machine:
1. > *Please choose a switch to attach to your Hyper-V instance.*

    Select the switch you created as a prerequisite. 

2. > *You will be asked for the username and password to use for the SMB folders*

   Enter the username and password of an administrative account on your computer. Depending on your setup, domain accounts sometimes don't work. You can create a new local admin user with the following PowerShell commands:
   ```powershell
   New-LocalUser "vagrant" -Password (Read-Host -AsSecureString)
   Add-LocalGroupMember -Group "Administrators" -Member "vagrant"
   ```

Provisioning takes around 10 minutes. After `vagrant` has finished, please wait another 10 minutes until all images were pulled and pods were started.

## Accessing the cluster

A `kubeconfig` for accessing the cluster is available in the `share/kubeconfig` file:

```
$ $env:KUBECONFIG=(Get-Item .\share\kubeconfig).FullName
$ kubectl get node -o wide

NAME           STATUS   ROLES                  AGE     VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                                  KERNEL-VERSION     CONTAINER-RUNTIME
controlplane   Ready    control-plane,master   16m     v1.22.3   10.1.0.134    <none>        Ubuntu 20.10                              5.8.0-63-generic   docker://20.10.8
winworker      Ready    <none>                 2m24s   v1.22.3   10.1.0.135    <none>        Windows Server 2022 Standard Evaluation   10.0.20348.230     containerd://1.6.0-beta.1
```

## Deploying an example Windows workload

An example Windows workload is available under `deployments/win-webserver.yml`:
```
$ kubectl apply -f deployments/win-webserver.yml
```

As soon as it is started, you can access it via the NodePort service:
```
$ kubectl get svc/win-webserver -o wide
NAME            TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE   SELECTOR
win-webserver   NodePort   172.16.200.194   <none>        80:32350/TCP   61m   app=win-webserver

$ curl.exe http://10.1.0.134:32350
<html><body><H1>Windows Container Web Server</H1><p>IP 192.168.52.196 callerCount 1 </body></html>
```

After verifying that everything works, you can start playing around with HostProcess pods: https://kubernetes.io/docs/tasks/configure-pod-container/create-hostprocess-pod/

## Troubleshooting

### Windows worker not able to report IP address

The Windows worker sometimes runs into a race condition during `vagrant up` where it didn't lease an IP yet and `vagrant` already tries to use the IPv6 or [APIPA](https://en.wikipedia.org/wiki/Link-local_address) instead:
```
==> winworker: Waiting for the machine to report its IP address...
    winworker: Timeout: 600 seconds
    winworker: IP: fe80::6494:8f91:4832:ba5f
==> winworker: Waiting for machine to boot. This may take a few minutes...
The box is not able to report an address for WinRM to connect to yet.
WinRM cannot access this Vagrant environment.
```

If that happens for you, just reload the machine with:
```
vagrant reload winworker
```
This sets up the machine with the synced folders again and should fix the problem.

### View setup logs

`vagrant` will output logs during `vagrant up` which will indicate if something goes wrong. Further you can verify if the CNI networking as well as the `kube-poxy` was setup correctly on the Windows node via HostProcess Pods:

**Calico CNI configuration**
```
$ kubectl logs daemonset.apps/calico-node-windows -n kube-system install-cni

Starting install. Cleaning up any previous files
Writing calico kubeconfig to c:/etc/cni/net.d
Copying CNI binaries to c:/opt/cni/bin
Writing CNI configuration to c:/etc/cni/net.d.
CNI configured
```

**Calico node initialization**
```
$ kubectl logs daemonset.apps/calico-node-windows -n kube-system calico-node-startup
...
Calico node initialisation succeeded; monitoring kubelet for restarts...
```

**Calico Felix**
```
$ kubectl logs daemonset.apps/calico-node-windows -n kube-system calico-node-felix
...
2021-11-03 15:48:02.175 [INFO][4572] felix/vxlan_mgr.go 241: All VXLAN route updates succeeded.
2021-11-03 15:48:02.175 [INFO][4572] felix/win_dataplane.go 306: Finished applying updates to dataplane. msecToApply=3.7899000000000003
2021-11-03 15:48:02.175 [INFO][4572] felix/win_dataplane.go 312: Completed first update to dataplane. secsSinceStart=0.1165118
...
```

**Kube-Proxy**
```
$ kubectl logs daemonset.apps/kube-proxy-windows -n kube-system
...
```
