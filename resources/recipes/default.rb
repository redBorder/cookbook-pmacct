#
# Cookbook Name:: pmacct
# Recipe:: default
#
# Copyright 2016, redborder
#
# All rights reserved - Do Not Redistribute
#

pmacct_config "config" do
  sensors node["redborder"]["sensors_info"]["flow-sensor"]
  action :add
end
