# Configure the flume agent that will listen to the logs from the
# stats manager job
node.default[:neon_logs][:flume_streams][:statsmanager_logs] = 
  get_jsonagent_config(node[:neon_logs][:json_http_source_port],
                       "stats_manager")

if node[:opsworks][:activity] == "config" then
  include_recipe "neon_logs::flume_core_config"
else
  include_recipe "neon_logs::flume_core"
end

# Give statsmanager access to airflow scheduler service
execute "sudoers for statsmanager" do
  command "echo 'statsmanager ALL=NOPASSWD: /usr/sbin/service airflow-scheduler *' >> /etc/sudoers"
  not_if "grep -F 'statsmanager ALL=NOPASSWD: /usr/sbin/service airflow-scheduler *' /etc/sudoers"
  Chef::Log.info("Modifying sudoers to add statsmanager access to airflow service")
end

# Write the configuration file for the statsmanager
template node[:stats_manager][:config] do
  source "statsmanager.conf.erb"
  owner node[:stats_manager][:user]
  group node[:stats_manager][:group]
  mode "0644"
  variables({ 
              :cluster_type => node[:stats_manager][:cluster_type],
              :cluster_name => node[:stats_manager][:cluster_name],
              :cluster_ip => node[:stats_manager][:cluster_public_ip],
              :cluster_log_uri => node[:stats_manager][:cluster_log_uri],
              :cluster_subnet_ids => node[:stats_manager][:cluster_subnet_ids],
              :emr_key => node[:stats_manager][:emr_key],
              :max_task_instances => node[:stats_manager][:max_task_instances],
              :master_instance_type => node[:stats_manager][:master_instance_type],
              :airflow_rebase_date => node[:stats_manager][:airflow_rebase_date],
              :notify_email => node[:stats_manager][:notify_email],
              :full_run_input_path => node[:stats_manager][:full_run_input_path],
              :n_core_instances => node[:stats_manager][:n_core_instances],
              :input_path => node[:stats_manager][:input_path],
              :cc_cleaned_path => node[:stats_manager][:cc_cleaned_path],
              :quiet_period => node[:stats_manager][:quiet_period],
              :log_file => node[:stats_manager][:log_file],
              :carbon_host => node[:neon][:carbon_host],
              :carbon_port => node[:neon][:carbon_port],
              :flume_log_port => node[:neon_logs][:json_http_source_port],
            })
end
