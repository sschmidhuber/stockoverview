#! /usr/bin/env bash

# redirect from port 80 => 8000

# create rules
sudo iptables -t nat -I PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8000
#sudo iptables -I INPUT -p tcp --dport 8080 -j ACCEPT

# delete rules
#sudo iptables -t nat -D PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8000
#sudo iptables -D INPUT -p tcp --dport 8080 -j ACCEPT
