IMAGE = "generic/ubuntu2004"
MEM = 4096
CPU = 3
DISK_NAME = "ft_linux.vdi"
DISK_SIZE = 30 * 1024
VNAME = "zoulhafi"
VIP = "192.168.42.110"

Vagrant.configure("2") do |config|

	config.vm.define VNAME do |master|
		master.vm.box = IMAGE
		master.vm.hostname = VNAME
		master.vm.network :private_network, ip: VIP
		master.vm.provider "virtualbox" do |v|
			v.name = VNAME
			v.memory = MEM
			v.cpus = CPU
			v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
			v.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
			v.customize ["modifyvm", :id, "--audio", "none"]
			unless FileTest.exist?(DISK_NAME)
				v.customize ['createhd', '--filename', DISK_NAME, '--format', 'VDI', '--size', DISK_SIZE]
			end
  			v.customize ['storageattach', :id, '--storagectl', 'IDE Controller', '--port', 1, '--device', 0, '--type', 'hdd', '--medium', DISK_NAME]
		end
		master.vm.provision "file", source: "~/.ssh/id_rsa.pub", destination: "/tmp/id_rsa.pub"
		master.vm.provision "file", source: "./wget-list", destination: "~/wget-list"
		master.vm.provision "shell", privileged: false, inline: "cat /tmp/id_rsa.pub >> ~/.ssh/authorized_keys"
		master.vm.provision "shell", privileged: true, path: "./ft_linux.sh"
	end

end
