# Git Annex & setup model data
# TODO: Fix the /root/.gitconfig lock issue & change user to root

apt_package "git-annex" do
    action :install
end

directory node[:video_client][:model_data_folder] do
  action :create
  owner "neon"
  group "neon"
  mode "1755"
end

# Install the ssh deploy key to get the repository
if node[:video_client][:gitannex_key].start_with?("s3://") then
  # The key is on s3, so go get it
  s3_file "#{node[:neon][:home]}/.ssh/model_data.pem" do
    source node[:video_client][:gitannex_key]
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

template "#{node[:neon][:code_root]}/model_data-wrap-ssh4git.sh" do
  owner "neon"
  group "neon"
  cookbook "neon"
  source "wrap-ssh4git.sh.erb"
  mode "0755"
  variables({:ssh_key => "#{node[:neon][:home]}/.ssh/model_data.pem"})
end

#git node[:video_client][:model_data_folder] do
#  repository node[:video_client][:model_data_repo]
#  revision node[:video_client][:model_data_repo_rev]
#  action :sync
#  user "neon"
#  group "neon"
#  ssh_wrapper "#{node[:neon][:code_root]}/model_data-wrap-ssh4git.sh"
#end

file "#{node[:video_client][:model_data_folder]}/#{node[:video_client][:model_file]}" do
  action :nothing
end

bash "get_model_file" do
  user "neon"
  cwd node[:video_client][:model_data_folder]
  environment ({
    "GIT_SSH" => "#{node[:neon][:code_root]}/model_data-wrap-ssh4git.sh"
  })
  code <<-EOH
  git clone #{node[:video_client][:model_data_repo]} .
  git config user.email ops@neon-lab.com
  git config user.name #{node[:opsworks][:instance][:hostname]}
  git annex sync
  git annex get #{node[:video_client][:model_file]}
  EOH
  action :run
  #subscribes :run, "git[#{node[:video_client][:model_data_folder]}]"
end
