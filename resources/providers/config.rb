
# Cookbook Name:: pmacct
#
# Provider:: config
#

include Pmacct::Helper

action :add do
  begin

    user = new_resource.user
    cdomain = new_resource.cdomain

    yum_package "pmacct" do
      action :upgrade
      flush_cache [:before]
    end

    user user do
      action :create
      system true
    end

    flow_nodes = []

    template "/etc/pmacct/sfacctd.conf" do
      source "sfacctd.conf.erb"
      owner user
      group user
      mode 0644
      ignore_failure true
      cookbook "pmacct"
      variables(:flow_nodes => flow_nodes)
      notifies :restart, "service[sfacctd]", :delayed
    end

    template "/etc/pmacct/pretag.map" do
      source "pretag.map.erb"
      owner user
      group user
      mode 0644
      ignore_failure true
      cookbook "pmacct"
      variables(:flow_nodes => flow_nodes)
      notifies :restart, "service[sfacctd]", :delayed
    end

    service "sfacctd" do
      service_name "sfacctd"
      ignore_failure true
      supports :status => true, :reload => true, :restart => true, :enable => true
      action [:start, :enable]
    end

    Chef::Log.info("Pmacct cookbook has been processed")
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :remove do
  begin
    
    service "sfacctd" do
      service_name "sfacctd"
      ignore_failure true
      supports :status => true, :enable => true
      action [:stop, :disable]
    end

    %w[ /etc/pmacct ].each do |path|
      directory path do
        recursive true
        action :delete
      end
    end

    yum_package "pmacct" do
      action :remove
    end

    Chef::Log.info("Pmacct cookbook has been processed")
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :register do
  begin
    if !node["pmacct"]["registered"]
      query = {}
      query["ID"] = "sfacct-#{node["hostname"]}"
      query["Name"] = "sfacct"
      query["Address"] = "#{node["ipaddress"]}"
      query["Port"] = "6343"
      json_query = Chef::JSONCompat.to_json(query)

      execute 'Register service in consul' do
         command "curl http://localhost:8500/v1/agent/service/register -d '#{json_query}' &>/dev/null"
         action :nothing
      end.run_action(:run)

      node.set["pmacct"]["registered"] = true
      Chef::Log.info("sfacct service has been registered to consul")
    end
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :deregister do
  begin
    if node["pmacct"]["registered"]
      execute 'Deregister service in consul' do
        command "curl http://localhost:8500/v1/agent/service/deregister/sfacct-#{node["hostname"]} &>/dev/null"
        action :nothing
      end.run_action(:run)

      node.set["pmacct"]["registered"] = false
      Chef::Log.info("sfacct service has been deregistered from consul")
    end
  rescue => e
    Chef::Log.error(e.message)
  end
end
