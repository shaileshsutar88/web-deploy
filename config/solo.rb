# Chef home directory 
chef_home = '/var/chef'

# Chef cache path
file_cache '/var/cache/chef-solo'

# Cookbook Path
cookbook_path [ File.join(chef_home, 'cookbooks'),
		File.join(chef_home, 'vendor', 'cookbooks') ]

# Roles Path
role_path	File.join(chef_home, 'roles')
data_bag_path	File.join(chef_home, 'data_bags')

#log_level :debug
log_level :info
log_location '/var/log/chef/chef.log'

Chef::Log::Formatter.show_time = true
