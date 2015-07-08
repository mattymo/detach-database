notice("MODULAR: deploy_hiera_override.pp")

$detach_db_plugin = hiera('detach-db')
$settings_hash = parseyaml($detach_db_plugin["yaml_additional_config"])
$nodes_hash = hiera('nodes')
$management_vip = hiera('management_vip')
$database_vip = pick($settings_hash['remote_db'],hiera('management_database_vip'))

###################
if hiera('role', 'none') == 'primary-db' {
  $primary_database = 'true'
} else {
  $primary_database = 'false'
}

if hiera('role', 'none') =~ /^primary/ {
  $primary_controller = 'true'
} else {
  $primary_controller = 'false'
}

$database_nodes_ips = nodes_with_roles($nodes_hash, ['primary-db',
                                  'db'], 'internal_address')
$database_nodes_names = nodes_with_roles($nodes_hash, ['primary-db',
                                  'db'], 'name')

#TODO(mattymo): debug needing corosync_roles
case hiera('role', 'none') {
  /db/: {
    $corosync_roles = ['primary-db','db']
    $deploy_vrouter = 'false'
    $mysql_enabled = 'true'
  }
  /controller/: {
    $deploy_vrouter = 'true'
    $mysql_enabled = 'false'
  }
  default: {
    $corosync_roles = ['primary-controller', 'controller']
  }
}

case hiera('role', 'none') {
  /controller/: {
#TODO(mattymo): Remote DB support without following hack
#Uncomment to enable remote DB creation, but add mysql hash in db with host and password to settings
#      include mysql
#      file { "/etc/my.cnf":
#        ensure => "present",
#        content =>
#        "[client]\nuser=root\nhost=${database_vip}\npassword=${settings_hash['remote_db_password']}\n",
#        require => Class["Mysql"],
#      }
  }
  default: {
  }
}

###################
$calculated_content = inline_template('
primary_database: <%= @primary_database %>
database_vip: <%= @database_vip %>
<% if @database_nodes_ips -%>
database_nodes:
<%
@database_nodes_ips.each do |dbnode|
%>  - <%= dbnode %>
<% end -%>
mysqld_ipaddresses:
<%
@database_nodes_ips.each do |dbnode|
%>  - <%= dbnode %>
<% end -%>
<% end -%>
<% if @database_nodes_names -%>
mysqld_names:
<%
@database_nodes_names.each do |dbnode|
%>  - <%= dbnode %>
<% end -%>
<% end -%>
mysql:
  enabled: <%= @mysql_enabled %>
primary_controller: <%= @primary_controller %>
<% if @corosync_roles -%>
corosync_roles:
<%
@corosync_roles.each do |crole|
%>  - <%= crole %>
<% end -%>
<% end -%>
deploy_vrouter: <%= @deploy_vrouter %>
')

###################
file {'/etc/hiera/override':
  ensure  => directory,
} ->
file { '/etc/hiera/override/plugins.yaml':
  ensure  => file,
  content => "${detach_db_plugin['yaml_additional_config']}\n${calculated_content}\n",
}

package {"ruby-deep-merge":
  ensure  => 'installed',
}

file_line {"hiera.yaml":
  path  => '/etc/hiera.yaml',
  line  => ':merge_behavior: deeper',
}

