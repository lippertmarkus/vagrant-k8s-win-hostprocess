[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $KubernetesVersion,

    [Parameter()]
    [string]
    $ContainerDVersion
)

Write-Host "##############################`nContinuing after restart...`n##############################`n"

Write-Host "##############################`nInstalling ContainerD version $ContainerDVersion`n##############################`n"
curl.exe -LO https://github.com/kubernetes-sigs/sig-windows-tools/releases/latest/download/Install-Containerd.ps1
.\Install-Containerd.ps1 -ContainerDVersion $ContainerDVersion

Write-Host "##############################`nRemoving NAT CNI config`n##############################`n"
# remove NAT CNI config as it leads to error:
# Failed to create pod sandbox: rpc error: code = Unknown desc = failed to setup network for sandbox "18b1292ae16d14b36a87417e2a7009f5797247a209f2099d40d3b4b9c7e3003a": plugin type="nat" name="nat" failed (add): error creating endpoint hcnCreateEndpoint failed in Win32: IP address is either invalid or not part of any configured subnet(s). (0x803b001e) {"Success":false,"Error":"IP address is either invalid or not part of any configured subnet(s). ","ErrorCode":2151350302} : endpoint config &{ 18b1292ae16d14b36a87417e2a7009f5797247a209f2099d40d3b4b9c7e3003a_nat d5ec6f42-7433-4111-922b-45d6f7cc1368  [] [{ 0}] { [default.svc.cluster.local svc.cluster.local cluster.local] [10.96.0.10] [ndots:5]} [{10.1.0.121 0.0.0.0/0 0}]  0 {2 0}} 
Remove-Item C:\etc\cni\net.d\* -Recurse

Write-Host "##############################`nInstalling kubelet, wins, kubeadm in version $KubernetesVersion`n##############################`n"
curl.exe -LO https://raw.githubusercontent.com/kubernetes-sigs/sig-windows-tools/master/kubeadm/scripts/PrepareNode.ps1
.\PrepareNode.ps1 -KubernetesVersion "v$KubernetesVersion" -ContainerRuntime containerD

Write-Host "##############################`nJoining the cluster with kubeadm`n##############################`n"
$jc = (Get-Content "C:\share\kubeadm-join-command.txt" -Encoding UTF8 -Raw).replace("`n","").replace("`r","")
Invoke-Expression "& $jc --cri-socket `"npipe:////./pipe/containerd-containerd`""