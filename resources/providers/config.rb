# Cookbook:: pmacct
# Provider:: config

include Pmacct::Helper

action :add do
  begin
    user = new_resource.user
    kafka_hosts = new_resource.kafka_hosts
    kafka_topic = new_resource.kafka_topic
    kafka_broker_port = new_resource.kafka_broker_port
    geo_country = new_resource.geo_country

    dnf_package 'pmacct' do
      action :upgrade
      flush_cache [:before]
    end

    execute 'create_user' do
      command "/usr/sbin/useradd -r #{user} -s /sbin/nologin"
      ignore_failure true
      not_if "getent passwd #{user}"
    end

    directory '/etc/pmacct' do
      owner user
      group group
      mode '0755'
    end

    flow_nodes = []

    template '/etc/pmacct/sfacctd.conf' do
      source 'sfacctd.conf.erb'
      owner user
      group user
      mode '0644'
      ignore_failure true
      cookbook 'pmacct'
      variables(flow_nodes: flow_nodes,
                kafka_hosts: kafka_hosts,
                kafka_topic: kafka_topic,
                kafka_broker_port: kafka_broker_port,
                geo_country: geo_country)
      notifies :restart, 'service[sfacctd]', :delayed
    end

    template '/etc/pmacct/pretag.map' do
      source 'pretag.map.erb'
      owner user
      group user
      mode '0644'
      ignore_failure true
      cookbook 'pmacct'
      variables(flow_nodes: flow_nodes)
      notifies :restart, 'service[sfacctd]', :delayed
    end

    service 'sfacctd' do
      service_name 'sfacctd'
      ignore_failure true
      supports status: true, reload: true, restart: true, enable: true
      if node['redborder']['leader_configuring'] 
        action [:enable, :stop]
      else
        action [:enable, :start]
      end
    end

    Chef::Log.info('Pmacct cookbook has been processed')
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :remove do
  begin
    service 'sfacctd' do
      service_name 'sfacctd'
      ignore_failure true
      supports status: true, enable: true
      action [:stop, :disable]
    end

    %w(/etc/pmacct).each do |path|
      directory path do
        recursive true
        action :delete
      end
    end

    dnf_package 'pmacct' do
      action :remove
    end

    Chef::Log.info('Pmacct cookbook has been processed')
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :register do
  begin
    unless node['pmacct']['registered']
      query = {}
      query['ID'] = "sfacct-#{node['hostname']}"
      query['Name'] = 'sfacct'
      query['Address'] = "#{node['ipaddress']}"
      query['Port'] = '6343'
      json_query = Chef::JSONCompat.to_json(query)

      execute 'Register service in consul' do
        command "curl -X PUT http://localhost:8500/v1/agent/service/register -d '#{json_query}' &>/dev/null"
        action :nothing
      end.run_action(:run)

      node.normal['pmacct']['registered'] = true
      Chef::Log.info('sfacct service has been registered to consul')
    end
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :deregister do
  begin
    if node['pmacct']['registered']
      execute 'Deregister service in consul' do
        command "curl -X PUT http://localhost:8500/v1/agent/service/deregister/sfacct-#{node['hostname']} &>/dev/null"
        action :nothing
      end.run_action(:run)

      node.normal['pmacct']['registered'] = false
      Chef::Log.info('sfacct service has been deregistered from consul')
    end
  rescue => e
    Chef::Log.error(e.message)
  end
end
