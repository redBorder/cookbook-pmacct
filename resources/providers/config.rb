# Cookbook:: pmacct
# Provider:: config

include Pmacct::Helper

action :add do
  begin
    config_dir = new_resource.config_dir
    sensors = new_resource.sensors
    settings = {
      bind: new_resource.sfacctd_ip || '0.0.0.0',
      brokers: new_resource.kafka_hosts.map { |host| "#{host}:#{new_resource.kafka_broker_port}" },
      topic: new_resource.kafka_topic,
    }

    # redborder-sfacctd ships the sfacctd unit running x2kafka, overriding the one of the legacy
    # pmacct package, which is kept because rb-exporter needs its pmacctd
    dnf_package 'redborder-sfacctd' do
      action :upgrade
    end

    # restart sfacctd when a new x2kafka is installed
    dnf_package 'x2kafka' do
      action :upgrade
      notifies :restart, 'service[sfacctd]', :delayed unless node['redborder']['leader_configuring']
    end

    # leftovers of the legacy pmacct sfacctd (sfacctd.conf and pretag.map)
    directory '/etc/pmacct' do
      recursive true
      action :delete
    end

    directory config_dir do
      owner 'root'
      group 'root'
      mode '0755'
    end

    template "#{config_dir}/config.json" do
      source 'sfacctd_config.json.erb'
      cookbook 'pmacct'
      owner 'root'
      group 'root'
      mode '0644'
      retries 2
      variables(config: x2kafka_config(sensors, settings))
      notifies :restart, 'service[sfacctd]', :delayed unless node['redborder']['leader_configuring']
    end

    service 'sfacctd' do
      service_name 'sfacctd'
      ignore_failure true
      supports status: true, reload: true, restart: true, enable: true, stop: true
      if node['redborder']['leader_configuring']
        action [:enable]
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

    %W(/etc/pmacct #{new_resource.config_dir}).each do |path|
      directory path do
        recursive true
        action :delete
      end
    end

    # x2kafka is left installed, other services (http2k, f2k) run it too
    dnf_package 'redborder-sfacctd' do
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
      query['Port'] = node['pmacct']['port'].to_s
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
