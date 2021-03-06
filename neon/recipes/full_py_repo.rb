# Installs the full python repo and all of the dependencies in the
# requirements.txt file.

# Install the repo
node.default[:neon][:repos]['core'] = true
include_recipe "neon::repo"

# Install virtualenv
include_recipe "python::virtualenv"

# Install packages that are needed
package_deps = [
                "libfreetype6-dev",
                "libatlas-base-dev",
                "libyaml-0-2",
                "libcurl4-openssl-dev",
                "libboost1.46-dev",
                "libboost1.46-dbg",
                "fftw3-dev",
                "gfortran",
                "cmake",
                "libpcre3",
                "libpcre3-dev",
                "libgtest-dev",
                "libpq-dev", 
                "cython",
                "libsnappy-dev",
                "libsnappy1",
                "postgresql-9.4", 
                "postgresql-contrib-9.4", 
                "python-snappy",
                "libboost-python1.46-dev",
                "libfreeimage-dev",
               ]
package_deps.each do |pkg|
  package pkg do
    action :install
  end
end

# Install redis and make sure the service is turned off
remote_file "/tmp/redis-installer.deb" do
  source node[:neon][:redis_pkg_link]
  mode 0644
end
dpkg_package "redis-server" do
  action :install
  source "/tmp/redis-installer.deb"
  version node[:neon][:redis_version]
end
service "redis-server" do
  action :stop
end

# Install the FindNumpy.cmake file
cookbook_file "FindNumpy.cmake" do
  path lazy { "#{`cmake --system-information | grep CMAKE_ROOT | perl -nle 'm/\"(.*)\"/; print $1'`.strip}/Modules/FindNumpy.cmake" }
  source "FindNumpy.cmake"
  action :create
  owner "root"
  group "root"
  mode "0644"
end

# Install opencv
include_recipe "neon-opencv"

# Install perftools and libunwind
code_path = get_repo_path(nil)
directory "#{Chef::Config[:file_cache_path]}/pprof" do
    :create
end
bash "install_libunwind" do
    cwd "#{Chef::Config[:file_cache_path]}/pprof"
    code <<-EOH
         tar -xzf #{code_path}/externalLibs/libunwind-0.99-beta.tar.gz
         cd libunwind-0.99-beta
         ./configure CFLAGS=-U_FORTIFY_SOURCE LDFLAGS=-L`pwd`/src/.libs
         make -j#{node[:cpu][:total]} install
    EOH
    creates "/usr/include/libunwind.h"
end

bash "install_perftools" do
    cwd "#{Chef::Config[:file_cache_path]}/pprof"
    code <<-EOH
         tar -xzf #{code_path}/externalLibs/gperftools-2.1.tar.gz
         cd gperftools-2.1
         ./configure
         make -j#{node[:cpu][:total]} install
    EOH
    creates "/usr/local/bin/pprof"
end

# Install gflags
if platform?("ubuntu") then

# TODO(mdesnoyer): Create a gflags cookbook that builds from
# source. For now, we just grab the gflags deb from the externalLibs
# directory.
#  ['libgflags-dev', 'libgflags0'].each do | pkg |
#    cur_file = "#{pkg}_#{node[:gflags][:version]}-1_amd64.deb"
#    remote_file "#{Chef::Config[:file_cache_path]}/#{cur_file}" do
#      source "#{node[:gflags][:package][:url_base]}#{cur_file}"
#    end
#    dpkg_package pkg do
#      action :install
#      source "#{Chef::Config[:file_cache_path]}/#{cur_file}"
#    end
#  end
  dpkg_package "libgflags0" do
    action :install
    source "#{code_path}/externalLibs/libgflags0_2.0-1_amd64.deb"
  end
  dpkg_package "libgflags-dev" do
    action :install
    source "#{code_path}/externalLibs/libgflags-dev_2.0-1_amd64.deb"
  end

else
  include_recipe "gflags"
end
    

# Get the list of apps to install
apps = ['core']
if not node[:deploy].nil? then
  node[:deploy].each do |app, data|
    if not node[:neon][:repos][app].nil? and node[:neon][:repos][app] then
      apps << app
    end
  end
end

apps.each do |app, data|

  # Run make in the directory, which installs all the python
  # depdencies in a virtual environment and builds the c++ code.
  code_path = get_repo_path(app)
  Chef::Log.info("Making app #{app} using code path #{code_path}")

  app_built = "#{code_path}/BUILD_DONE"
  file app_built do
    user "neon"
    group "neon"
    action :nothing
    subscribes :delete, "git[#{code_path}]", :immediately
  end

  # Write the build configuration to a file - if it changes, we recompile
  # TODO: Add subscriptions for changes to libunwind or perftools or gflags
  template "#{code_path}/build-configuration" do
    source "build-configuration.erb"
    owner "root"
    group "root"
    mode 0600
    variables(
              :package_deps => package_deps,
              :params => { 
                :python_venv_version => node[:python][:virtualenv_version],
                :redis_version => node[:neon][:redis_version],
                :opencv_version => node[:opencv][:version]
              }
    )
    notifies :delete, "file[#{app_built}]", :immediately
  end


  bash "compile_#{app}" do
    cwd code_path
    user "neon"
    group "neon"
    code <<-EOH
       . enable_env
       make clean BUILD_TYPE=Release && make release
    EOH
    not_if {  ::File.exists?(app_built) }
    notifies :create, "file[#{app_built}]"
  end
end

package "python-nose" do
  :install
end
