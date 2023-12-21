# Cookbook Name:: pmacct
#
# Resource:: config
#

actions :add, :remove, :register, :deregister
default_action :add

attribute :user, :kind_of => String, :default => "pmacct"
attribute :cdomain, :kind_of => String, :default => "redborder.cluster"
attribute :sensors, :kind_of => Hash, :default => {}
attribute :kafka_hosts, :kind_of => Array, :default => ["127.0.0.1"]
attribute :kafka_topic, :kind_of => String, :default => "sflow"
attribute :kafka_broker_port, :kind_of => Integer, :default => 9092
attribute :geo_country, :kind_of => String, :default => "/usr/share/GeoIP/GeoLiteCountry.dat"


