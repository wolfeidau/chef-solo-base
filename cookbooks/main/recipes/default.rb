=begin
package "git-core"
package "avahi-daemon"
package "mercurial"
package "ntp"
package "apg"
package "zsh"
package "screen"
package "ttf-dejavu"
package "tomcat7"
package "postgresql-9.1"
package "libsqlite3-dev"

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)

node.set[:bamboo][:db_password] = secure_password

template "/etc/default/tomcat7" do
  source "tomcat7.erb"
  notifies :restart, "service[tomcat7]", :delayed
end

template "/etc/tomcat7/server.xml" do
  source "serverxml.erb"
  mode "600"
  owner "tomcat7"
  group "tomcat7"
  notifies :restart, "service[tomcat7]", :delayed
end

service "tomcat7" do
  supports :restart => true, :reload => true
  action :enable
end

directory node[:bamboo][:home] do
  owner "tomcat7"
  group "tomcat7"
  mode "0755"
  recursive true
  action :create
end

execute "download bamboo war" do
  command "wget -O /var/lib/tomcat7/webapps/bamboo.war http://www.atlassian.com/software/bamboo/downloads/binary/atlassian-bamboo-#{node[:bamboo][:version]}.war"
  creates "/var/lib/tomcat7/webapps/bamboo.war"
  action :run
end

execute "download postgresql JDBC driver" do
  command "wget -O /var/lib/tomcat7/common/postgresql-9.1-902.jdbc4.jar http://jdbc.postgresql.org/download/postgresql-9.1-902.jdbc4.jar" 
  creates "/var/lib/tomcat7/common/postgresql-9.1-902.jdbc4.jar"
  action :run
  notifies :restart, "service[tomcat7]", :delayed
end

template "/etc/postgresql/9.1/main/pg_hba.conf" do
  source "pg_hba_conf.erb"
  mode "640"
  owner "postgres"
  group "postgres"
  notifies :restart, "service[postgresql]", :immediately
end

service "postgresql" do
  supports :restart => true, :reload => true
  action :enable
end

bash "assign-bamboo-password" do
  user 'postgres'
  code <<-EOH
echo "CREATE ROLE #{node[:bamboo][:db_user]} ENCRYPTED PASSWORD '#{node[:bamboo][:db_password]}' NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT LOGIN;" | psql
echo "GRANT all privileges ON DATABASE bamboo TO #{node[:bamboo][:db_user]};" | psql
createdb -O #{node[:bamboo][:db_user]} bamboo
  EOH
  not_if "echo '\connect' | PGPASSWORD=#{node['bamboo']['db_password']} psql --username=#{node[:bamboo][:db_user]} --no-password -h localhost"
  action :run
end

template "/etc/tomcat7/Catalina/localhost/bamboo.xml" do
  source "bambooxml.erb"
  mode "600"
  owner "tomcat7"
  group "tomcat7"
  notifies :restart, "service[tomcat7]", :delayed
end
=end
