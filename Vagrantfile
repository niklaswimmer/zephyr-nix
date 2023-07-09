# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # https://docs.vagrantup.com.
  config.vm.box = "ubuntu/jammy64"

  config.vm.provision "nix", type: "shell", reset: true, inline: <<-SHELL
    sh <(curl -L https://nixos.org/nix/install) --daemon
  SHELL
end
