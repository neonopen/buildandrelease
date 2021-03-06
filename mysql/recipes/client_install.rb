# override of client_install from 
#     https://github.com/chef-cookbooks/mysql
# overriding from cached version of the file located at 
#     /var/lib/aws/opsworks/cache.stage2/cookbooks/mysql/recipes
# doing so due to a package mismatch on libmysqlclient18

# for backwards compatiblity default the package name to mysql
mysql_name = node[:mysql][:name] || "mysql"

case node[:platform]
when "redhat", "centos", "fedora", "amazon"
  if rhel7?
    # mysql55-mysql-devel package for Red Hat Enterprise Linux 7 is installed at /opt
    # compiling for example mysql gem will fail because it looks up wrong paths.
    # mariadb-devel is binary compatible and at correct location.
    package "mariadb-devel"
  else
    package "#{mysql_name}-devel"
  end
else # "ubuntu"
  # kf change - update package lists, get most recent libmysqlclient18 
  include_recipe "apt"
  apt_preference 'libmysqlclient18' do
    pin 'version 5.5.53-0'
    pin_priority '1000'
  end
  apt_preference 'libmysqlclient-dev' do
    pin 'version 5.5.53-0'
    pin_priority '1000'
  end
  apt_package "libmysqlclient18" do 
    action :upgrade
  end
  apt_package "libmysqlclient-dev" do 
    action :install 
    options "--fix-broken"
  end 
end

case node[:platform]
when "redhat", "centos", "fedora", "amazon"
  package mysql_name
else "ubuntu"
  package "mysql-client"
end
