# This recipe installs the neon click trackserver

include_recipe "neon::default"

# Setup collecting system metrics
include_recipe "neon::system_metrics"

# Create a trackserver user
user "trackserver" do
  action :create
  system true
  shell "/bin/false"
end

include_recipe "trackserver::config"

# Install the python dependencies

# List the python dependencies for this server. We don't install
# all the neon dependencies so that the server can come up more
# quickly
pydeps = {
  "futures" => "2.1.5",
  "tornado" => "3.1.1",
  "shortuuid" => "0.3",
  "PyYAML" => "3.10",
  "boto" => "2.29.1",
  "simplejson" => "2.3.2",
  "nose" => "1.3.0",
  "pyfakefs" => "2.4",
  "mock" => "1.0.1",
  "httpagentparser" => "1.6.0",
  "avro" => "1.7.6",
  "thrift" => "0.9.1",
  "psutil" => "1.2.1",
}

pydeps.each do |package, vers|
  python_pip package do
    version vers
    options "--no-index --find-links http://s3-us-west-1.amazonaws.com/neon-dependencies/index.html"
  end
end

package "python-nose" do
  :install
end

# Make directories 
file node[:trackserver][:log_file] do
  user "trackserver"
  group "neon"
  mode "0644"
end
directory node[:trackserver][:backup_dir] do
  user "trackserver"
  group "neon"
  mode "1775"
  recursive true
end

node[:deploy].each do |app_name, deploy|
  if app_name != "Track Server" then
    next
  end
  
  trackserver_repo = get_repo_path("Track Server")
  Chef::Log.info "Deploying app #{app_name} using code path #{trackserver_repo}"
  # Install the neon code
  include_recipe "neon::repo"

  # Add the image serving platform
  include_recipe "neonisp"

  # Test the trackserver
  trackserver_repo = get_repo_path("trackserver")
  execute "nosetests --exe clickTracker" do
    cwd "#{trackserver_repo}"
    user "trackserver"
    action :run
    notifies :restart, "service[neon-trackserver]", :delayed
  end

  # Write the daemon service wrapper
  template "/etc/init/neon-trackserver.conf" do
    source "trackserver_service.conf.erb"
    owner "root"
    group "root"
    mode "0644"
    variables({
                :neon_root_dir => "#{trackserver_repo}",
                :config_file => node[:trackserver][:config],
                :user => "trackserver",
                :group => "trackserver",
              })
  end

  # Write a script that will send a mail when the service dies
  template "/etc/init/neon-trackserver-email.conf" do
    source "mail-on-restart.conf.erb"
    cookbook "neon"
    owner "root"
    group "root"
    mode "0644"
    variables({
                :service => "neon-trackserver",
                :host => node[:hostname],
                :email => node[:neon][:ops_email],
                :log_file => node[:trackserver][:log_file]
              })
  end

  template "/etc/init/nginx-email.conf" do
    source "mail-on-restart.conf.erb"
    cookbook "neon"
    owner "root"
    group "root"
    mode "0644"
    variables({
                :service => "nginx",
                :host => node[:hostname],
                :email => node[:neon][:ops_email],
                :log_file => "#{node[:nginx][:log_dir]}/error.log"
              })
  end

  service "neon-trackserver" do
    provider Chef::Provider::Service::Upstart
    supports :status => true, :restart => true, :start => true, :stop => true
    action [:enable, :start]
  end
end


if ['undeploy', 'shutdown'].include? node[:opsworks][:activity] then
  # Turn off the trackserver
  service "neon-trackserver" do
    action :stop
  end

  file "/etc/init/neon-trackserver.conf" do
    action :delete
  end
end