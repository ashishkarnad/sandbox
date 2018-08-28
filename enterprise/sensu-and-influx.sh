#!/bin/sh
IPADDR=$(/sbin/ip -o -4 addr list enp0s8  | awk '{print $4}' | cut -d/ -f1)

# Make sure we have all the package repos we need!
sudo yum install epel-release nano yum-utils openssl httpd -y
sudo yum groupinstall 'Development Tools' -y

# Set up zero-dependency erlang
echo ' [rabbitmq-erlang]
name=rabbitmq-erlang
baseurl=https://dl.bintray.com/rabbitmq/rpm/erlang/20/el/7
gpgcheck=1
gpgkey=https://www.rabbitmq.com/rabbitmq-release-signing-key.asc
repo_gpgcheck=0
enabled=1' | sudo tee /etc/yum.repos.d/rabbitmq-erlang.repo
sudo yum install erlang -y

# Install rabbitmq
sudo yum install https://dl.bintray.com/rabbitmq/rabbitmq-server-rpm/rabbitmq-server-3.6.12-1.el7.noarch.rpm -y

# Add the Sensu Core YUM repository
echo '[sensu]
name=sensu
baseurl="https://repositories.sensuapp.org/yum/$releasever/$basearch/"
gpgcheck=0
enabled=1' | sudo tee /etc/yum.repos.d/sensu.repo

# Add the Sensu Enterprise YUM repository
echo "[sensu-enterprise]
name=sensu-enterprise
baseurl=http://$SE_USER:$SE_PASS@enterprise.sensuapp.com/yum/noarch/
gpgcheck=0
enabled=1" | tee /etc/yum.repos.d/sensu-enterprise.repo

# Add the Sensu Enterprise Dashboard YUM repository
echo "[sensu-enterprise-dashboard]
name=sensu-enterprise-dashboard
baseurl=http://$SE_USER:$SE_PASS@enterprise.sensuapp.com/yum/\$basearch/
gpgcheck=0
enabled=1" | tee /etc/yum.repos.d/sensu-enterprise-dashboard.repo

# Get Redis installed
sudo yum install redis -y

# Install Sensu itself
sudo yum install sensu-enterprise sensu-enterprise-dashboard -y

# Provide minimal transport configuration (used by client, server and API)
echo '{
  "transport": {
    "name": "rabbitmq"
  }
}' | sudo tee /etc/sensu/transport.json

# Ensure config file permissions are correct
sudo chown -R sensu:sensu /etc/sensu

# Install curl and jq helper utilities
sudo yum install curl jq -y

# Provide minimal uchiwa conifguration, pointing at API on localhost
# Optionally, you can see Sensu datacenters(see https://docs.uchiwa.io/getting-started/configuration/#datacenters-configuration-sensu) in action by adding an additional 
# configuration for another datacenter. If you, by chance, spin up Sensu using 
# kubernetes, it might look like this:

#    {                
#      "name": "sensu-k8s",                     
#      "host": "your-minikube-ip",                 
#      "port": your-minikube-service-port
#    }

echo '{
  "sensu": [
    {
      "name": "sensu-enterprise-sandbox",
      "host": "127.0.0.1",
      "port": 4567
    }
  ],
  "dashboard": {
    "host": "0.0.0.0",
    "port": 3000
  }
}' |sudo tee /etc/sensu/dashboard.json

# Configure sensu to use rabbitmq

echo '{
  "rabbitmq": {
    "host": "127.0.0.1",
    "port": 5672,
    "vhost": "/sensu",
    "user": "sensu",
    "password": "secret",
    "heartbeat": 30,
    "prefetch": 50
  }
}' | sudo tee /etc/sensu/conf.d/rabbitmq.json

# Configure minimal Redis configuration for Sensu

echo '{
  "redis": {
    "host": "127.0.0.1",
    "port": 6379
  }
}' | sudo tee /etc/sensu/conf.d/redis.json

# Start up rabbitmq services
sudo systemctl start rabbitmq-server

# Add rabbitmq vhost configurations
sudo rabbitmqctl add_vhost /sensu
sudo rabbitmqctl add_user sensu secret
sudo rabbitmqctl set_permissions -p /sensu sensu ".*" ".*" ".*"

# Going to do some general setup stuff
cd /etc/sensu/conf.d
mkdir {checks,filters,mutators,handlers,templates}

#Start up other services
sudo systemctl start redis.service
sudo systemctl enable redis.service
sudo systemctl enable rabbitmq-server
systemctl start sensu-enterprise
chkconfig sensu-enterprise on
systemctl start sensu-enterprise-dashboard
chkconfig sensu-enterprise-dashboard on

echo -e "=================
Sensu Enterprise is now up and running!
Access it at $IPADDR:3000
================="
