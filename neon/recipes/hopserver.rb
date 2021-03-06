# This recipe creates a hop serving that can be ssh'd to in order to
# access all the other serving systems in the VPC without needing a
# password. If you want to setup your local machine to ssh easily, you
# can add the following entry to your ~/.ssh/config file:
#
# Host hopserver
#   HostName <Elastic IP of this machine>
#   User ubuntu
#   IdentityFile <Location to the ssh key for this machine>
#
# Host <VPC address space. e.g. 10.0.*>
#   ProxyCommand ssh -q hopserver nc -q0 %h 22
#   IdentityFile <Location to the ssh key for the machine behind the hop>
#   User ubuntu


include_recipe "neon::default"

package "netcat6" do
  action :install
end

s3_file "/home/ubuntu/.ssh/neon-serving.pem" do
  bucket node[:serving_key_bucket]
  remote_path data[:serving_key_path]
  owner "ubuntu"
  group "ubuntu"
  action :create
  mode "0600"
end

# Find a list of all the hostnames that we can hop to
hostnames = []
node[:opsworks][:layers].each do | layer_name, layer|
  layer[:instances].each do |hostname, instance|
    hostnames << hostname
    if not instance[:ip].nil?
      hostnames << instance[:ip]
    end
  end
end

template "/home/ubuntu/.ssh/config" do
  source "hopserver-ssh-config.erb"
  owner "ubuntu"
  group "ubuntu"
  mode "0600"
  variables({
              :hostnames => hostnames,
              :key_file => "/home/ubuntu/.ssh/neon-serving.pem",
              :vpc_prefix => node[:opsworks][:instance][:private_ip].split('.')[0,2].join('.')
            })
end

# Remove the known_hosts file because servers change on config
if node[:opsworks][:activity] == "config" then
  file "/home/ubuntu/.ssh/known_hosts" do
    action :delete
  end
end
