include_attribute "neon::repo"

# Parameters for imageservingplatform (neonisp)
default[:neonisp][:log_file] = "#{node[:neon][:log_dir]}/neonisp.log"
default[:neonisp][:port] = 80 #port for isp to listen on
default[:neonisp][:mastermind_validated_filepath] = "#{node[:nginx][:default_root]}/mastermind.validated"
default[:neonisp][:mastermind_file_url] = "s3://neon-image-serving-directives/mastermind"
default[:neonisp][:mastermind_download_filepath] = "#{node[:nginx][:default_root]}/mastermind"
default[:neonisp][:client_api_expiry] = "10m" #10 mins
default[:neonisp][:app_name] = "image_serving_platform"
default[:neonisp][:crossdomain_root] = "/opt/neon"
default[:neonisp][:s3downloader_src] = "imageservingplatform/neon_isp/isp_s3downloader.py"
default[:neonisp][:s3downloader_exec_loc] = "/usr/local/bin/isp_s3downloader"

# Which repos to install
default[:neon][:repos]["#{node[:neonisp][:app_name]}"] = true
default[:neon][:repos]["core"] = true

# Nginx parameters
#default['nginx']['source']['version'] = '1.4.7'
default[:nginx][:init_style] = "upstart"
default[:nginx][:large_client_header_buffers] = "8 1024000"
default[:nginx][:disable_access_log] = true 
default[:nginx][:install_method] = "source"
default[:nginx][:log_dir] = "#{node[:neon][:log_dir]}/nginx"
default[:nginx][:worker_rlimit_nofile] = 65536
default[:nginx][:source][:modules] = %w(
  neon-nginx::http_realip_module
  neon-nginx::http_geoip_module
  neonisp::nginx_ispmodule
)

# Force_Default is needed because these parameters are set in the nginx recipe
force_default[:nginx]['worker_processes'] = 1
force_default[:nginx]['worker_connections'] = 12000
force_default[:nginx]['worker_rlimit_nofile'] = 200000

# System configs
force_default[:opsworks_initial_setup][:sysctl]['net.core.somaxconn'] = 10240     
force_default[:opsworks_initial_setup][:sysctl]['net.core.netdev_max_backlog'] = 10240
force_default[:opsworks_initial_setup][:sysctl]['net.ipv4.tcp_max_syn_backlog'] = 2048 # 1024
force_default[:opsworks_initial_setup][:sysctl]['net.ipv4.tcp_fin_timeout'] = 15 
force_default[:opsworks_initial_setup][:sysctl]['net.ipv4.tcp_keepalive_time'] = 100
force_default[:opsworks_initial_setup][:sysctl]['net.ipv4.tcp_max_orphans'] = 131072
force_default[:opsworks_initial_setup][:sysctl]['net.ipv4.tcp_tw_reuse'] = 1   

# Allow a high number of timewait sockets
force_default[:opsworks_initial_setup][:sysctl]['net.ipv4.tcp_max_tw_buckets'] = 2000000

# Wait a maximum of 5 * 2 = 10 seconds in the TIME_WAIT state after a FIN, to handle
# any remaining packets in the network. 
#force_default[:opsworks_initial_setup][:sysctl]['net.ipv4.netfilter.ip_conntrack_tcp_timeout_time_wait'] = 10   

# Determines the wait time between isAlive interval probes (reduce from 75 sec to 15)
#force_default[:opsworks_initial_setup][:sysctl]['net.ipv4.tcp_keepalive_intvl'] = 15   

# increase the ephemeral port range (TODO(Sunil): figure out the format)
#force_default[:opsworks_initial_setup][:sysctl]['net.ipv4.ip_local_port_range'] = 10000 64000   
