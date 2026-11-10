module Pmacct
  module Helper
    require 'ipaddr'

    DOMAIN_FIELDS = %w(sensor_uuid deployment deployment_uuid namespace namespace_uuid market market_uuid
                       organization organization_uuid service_provider service_provider_uuid campus
                       campus_uuid building building_uuid floor floor_uuid).freeze

    # Builds the x2kafka config that replaces sfacctd.conf and the logstash sflow
    # direction and enrichment steps. x2kafka enriches each flow with the whole
    # enrichment_map entry matching the exporter IP, so every sensor IP gets one
    # flat entry. home_nets and span_port are per listener in x2kafka, so they
    # are merged across all the sensors.
    def x2kafka_config(sensors, brokers, bind, topic)
      enrichment_map = {}
      home_nets = []
      span_ports = []

      sensors.keys.sort.each do |sensor|
        begin
          node_info = Chef::Node.load(sensor)
        rescue => e
          Chef::Log.warn("sfacctd: skipping sensor #{sensor}: #{e.message}")
          next
        end

        ip = node_info['ipaddress'].to_s
        next if ip.empty?

        rb = node_info['redborder'] || {}

        # sflow has no observation id, so only one entry per exporter IP
        if enrichment_map.key?(ip)
          Chef::Log.warn("sfacctd: exporter #{ip} already mapped, ignoring #{sensor}")
          next
        end

        enrichment = {
          'sensor_name' => node_info['rbname'] || node_info.name,
          'sensor_ip' => ip,
          'index_partitions' => [1, (rb['index_partitions'] || 5).to_i].max,
          'index_replicas' => [1, (rb['index_replicas'] || 1).to_i].max,
        }
        DOMAIN_FIELDS.each do |field|
          enrichment[field] = rb[field] unless rb[field].to_s.empty?
        end
        enrichment_map[ip] = enrichment

        span_ports << (rb['spanport'].to_i == 1)

        Array(rb['homenets']).each do |homenet|
          network = homenet['value'].to_s.strip
          begin
            IPAddr.new(network)
            home_nets << network
          rescue IPAddr::Error
            # a single invalid CIDR makes x2kafka drop all the home_nets
            Chef::Log.warn("sfacctd: ignoring invalid homenet '#{network}' of #{sensor}")
          end
        end
      end

      listener = {
        'name' => 'sfacctd',
        'proto' => 'sflow',
        'bind' => bind,
        'port' => 6343,
        'topic' => topic,
        'span_port' => !span_ports.empty? && span_ports.all?,
        'enrichment_key' => 'sensor_ip',
        'enrichment_map' => enrichment_map,
      }
      # without home_nets x2kafka falls back to the private ranges
      listener['home_nets'] = home_nets.uniq unless home_nets.empty?

      {
        'brokers' => brokers,
        'topic' => topic,
        'client_id' => 'sfacctd',
        'async' => true,
        'stats_socket' => '/run/sfacctd/sfacctd.sock',
        # keepalived health checks /health on this port from the other managers
        'stats_bind' => '0.0.0.0',
        'stats_port' => 7984,
        'listeners' => [listener],
      }
    end
  end
end
