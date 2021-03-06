# Git Annex & setup model data

apt_package "git-annex" do
    action :install
end

directory node[:video_client][:model_data_folder] do
  action :create
  owner "neon"
  group "neon"
  mode "1755"
  recursive true
end

# Install the ssh deploy key to get the repository
if node[:video_client][:gitannex_key].start_with?("s3://") then
  # The key is on s3, so go get it
  buck, path = node[:video_client][:gitannex_key].match(/s3:\/\/(.*)\/(.*)/).captures 
  s3_file "#{node[:neon][:home]}/.ssh/model_data.pem" do
    bucket buck
    remote_path path
    owner "neon"
    group "neon"
    action :create
    mode "0600"
  end
else
  # The key is in the variable, so write it to a file
  file "#{node[:neon][:home]}/.ssh/model_data.pem" do
    content node[:video_client][:gitannex_key]
    owner "neon"
    group "neon"
    action :create
    mode "0600"
  end
end

template "#{node[:neon][:home]}/.ssh/config" do
  source "gitannex-ssh-config.erb"
  owner "neon"
  group "neon"
  mode "0600"
  variables({
            :hostname => node[:video_client][:model_data_host],
            :key_file => "#{node[:neon][:home]}/.ssh/model_data.pem",
  })
end

template "#{node[:neon][:code_root]}/model_data-wrap-ssh4git.sh" do
  owner "neon"
  group "neon"
  source "wrap-ssh4git.sh.erb"
  mode "0755"
  cookbook "neon"
  variables({:ssh_key => "#{node[:neon][:home]}/.ssh/model_data.pem"})
end


git node[:video_client][:model_data_folder] do
  repository node[:video_client][:model_data_repo]
  revision node[:video_client][:model_data_repo_rev]
  action :sync
  user "neon"
  group "neon"
  ssh_wrapper "#{node[:neon][:code_root]}/model_data-wrap-ssh4git.sh"
end

# bash "sync_annex" do
#   user "neon"
#   cwd node[:video_client][:model_data_folder]
#   group "neon"
#   environment "GIT_SSH" => "#{node[:neon][:code_root]}/model_data-wrap-ssh4git.sh"
#   code <<-EOH
#   git annex sync
#   EOH
#   action :run
# end

model_files = (node[:video_client][:model_files] + 
               node[:video_client][:custom_model_files].map { 
                 |x| File.join(node[:video_client][:model_data_folder], x)})


model_files.each do |file|
  # iterate through the model files
  bash "get_model_file #{file}" do
    user "neon"
    cwd node[:video_client][:model_data_folder]
    group "neon"
    code <<-EOH
    git config user.email "ops@neon-lab.com"
    git config user.name "ops"
    git annex get #{file}
    EOH
    action :run
  end
end

# Use an md5 of the model file to see if it has changed and trigger a
# service restart.
file "#{node[:neon][:home]}/model_file.md5" do
  content lazy { Digest::MD5.file("#{node[:video_client][:model_data_folder]}/#{node[:neon][:model_file]}").hexdigest }
  owner "neon"
  group "neon"
  mode "0644"
  action :create
end
