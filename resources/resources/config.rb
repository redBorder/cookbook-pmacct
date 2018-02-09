# Cookbook Name:: pmacct
#
# Resource:: config
#

actions :add, :remove, :register, :deregister
default_action :add

attribute :user, :kind_of => String, :default => "pmacct"
attribute :cdomain, :kind_of => String, :default => "redborder.cluster"


