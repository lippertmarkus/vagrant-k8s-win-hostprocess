kubernetes_version="1.22.3" # only supports 1.22+, versions limited by available tags: https://hub.docker.com/r/sigwindowstools/kube-proxy/tags
containerd_version="1.6.0-beta.1" # only supports 1.6.0+ (https://github.com/containerd/containerd/releases/)

Vagrant.configure("2") do |config|
    config.vm.define :controlplane do |controlplane|
        controlplane.vm.host_name = "controlplane"
        controlplane.vm.box = "generic/ubuntu2010"
        controlplane.vm.synced_folder 'share', '/share'

        controlplane.vm.provider "hyperv" do |h|
            h.cpus = 4
            h.maxmemory = 4000
            h.enable_virtualization_extensions = true
        end

        controlplane.vm.provision "file", source: "setup-scripts/kubeadm-config.yml", destination: "kubeadm-config.yml"
        controlplane.vm.provision "shell", path: "setup-scripts/controlplane.sh", privileged: false, args: [kubernetes_version]
    end

    config.vm.define :winworker do |winworker|
        winworker.vm.host_name = "winworker"
        winworker.vm.box = "gusztavvargadr/windows-server-2022-standard-core"
        winworker.vm.synced_folder 'share', '/share'

        winworker.vm.provider "hyperv" do |h|
            h.cpus = 4
            h.memory = 8000
            h.enable_virtualization_extensions = true
        end

        winworker.vm.provision "shell", path: "setup-scripts/winworker-prereqs.ps1", privileged: false, reboot: true
        winworker.vm.provision "shell", path: "setup-scripts/winworker.ps1", privileged: true, args: ["-KubernetesVersion", kubernetes_version, "-ContainerDVersion", containerd_version]
    end
end