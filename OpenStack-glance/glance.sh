#!/bin/bash

yum -y install openstack-glance

if [ $? -eq 0 ]; then
    echo "Package openstack-glance installed successfully."
    mysql -uroot -p000000 -e "CREATE DATABASE glance; GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '000000'; GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '000000';"
    
    if [ $? -eq 0 ]; then
        echo "Database operations completed successfully."
        cp /etc/glance/glance-api.conf /etc/glance/glance-api.bak
        
        if [ $? -eq 0 ]; then
            echo "Backup successful."
            grep -Ev '^$|#' /etc/glance/glance-api.bak > /etc/glance/glance-api.conf
            CONFIG_OPTION_DATABASE="connection = mysql+pymysql://glance:000000@controller/glance"
            CONFIG_OPTION_KEYSTONE_AUTHTOKEN=$(cat <<EOF
auth_url = http://controller:5000
memcached_servers = controller:11211
auth_type = password
username = glance
password = 000000
project_name = project
user_domain_name = Default
project_domain_name = Default
EOF
            )
            CONFIG_OPTION_GLANCE_STORE=$(cat <<EOF
stores = file
default_store = file
filesystem_store_datadir = /var/lib/glance/images/
EOF
            )
            CONFIG_OPTION_PASTE_DEPLOY="flavor = keystone"
            CONFIG_FILE="/etc/glance/glance-api.conf"
            if grep -q "^$CONFIG_OPTION_DATABASE$" "$CONFIG_FILE"; then
    echo "Database connection configuration already exists."
else
    sed -i "/^\[database\]$/a $CONFIG_OPTION_DATABASE" "$CONFIG_FILE"
    echo "Database connection configuration added successfully."
fi

if grep -q "^$CONFIG_OPTION_KEYSTONE_AUTHTOKEN$" "$CONFIG_FILE"; then
    echo "Keystone auth token configuration already exists."
else
    sed -i "/^\[keystone_authtoken\]$/a $CONFIG_OPTION_KEYSTONE_AUTHTOKEN" "$CONFIG_FILE"
    echo "Keystone auth token configuration added successfully."
fi

if grep -q "^$CONFIG_OPTION_GLANCE_STORE$" "$CONFIG_FILE"; then
    echo "Glance store configuration already exists."
else
    sed -i "/^\[glance_store\]$/a $CONFIG_OPTION_GLANCE_STORE" "$CONFIG_FILE"
    echo "Glance store configuration added successfully."
fi

if grep -q "^$CONFIG_OPTION_PASTE_DEPLOY$" "$CONFIG_FILE"; then
    echo "Paste Deploy configuration already exists."
else
    sed -i "/^\[paste_deploy\]$/a $CONFIG_OPTION_PASTE_DEPLOY" "$CONFIG_FILE"
    echo "Paste Deploy configuration added successfully."
fi
            su glance -s /bin/sh -c "glance-manage db_sync"
            if [ $? -eq 0 ]; then
                echo "File synchronization successful."
                su root -c "source admin-login &&
                    openstack user create --domain default --password 000000 glance &&
                    openstack role add --project project --user glance admin &&
                    openstack service create --name glance image &&
                    openstack endpoint create --region RegionOne glance public http://controller:9292 &&
                    openstack endpoint create --region RegionOne glance internal http://controller:9292 &&
                    openstack endpoint create --region RegionOne glance admin http://controller:9292 &&
                    systemctl enable openstack-glance-api &&
                    systemctl start openstack-glance-api"
                echo "Configuration added to $CONFIG_FILE."
            else  
                echo "Failed to perform database operations."
            fi
        else
            echo "Failed to backup configuration file."
        fi    
    else     
        echo "Failed to perform database operations."
    fi
else     
    echo "Failed to install package openstack-glance."
fi
#作者：@CZR
#联系方式：1573799514@qq.com
