# Cookbook:: pmacct
# Resource:: config

actions :add, :remove, :register, :deregister
default_action :add

attribute :config_dir, kind_of: String, default: '/etc/sfacctd'
attribute :sensors, kind_of: Hash, default: {}
attribute :kafka_hosts, kind_of: Array, default: ['127.0.0.1']
attribute :kafka_topic, kind_of: String, default: 'rb_flow'
attribute :kafka_broker_port, kind_of: Integer, default: 9092
attribute :sfacctd_ip, kind_of: String
attribute :port, kind_of: Integer, default: 6343
# keepalived checks /health on this port (the health_port of sfacctd in cookbook-rb-manager)
attribute :stats_port, kind_of: Integer, default: 7984
