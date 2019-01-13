#!/bin/bash

# Create gitlab systemd service
# First parameter is the linux account username you want the service run under
# Second parameter is the location of your gitlab docker-compose.yml
# Example:  $ sudo sh gitlab_service.sh LINUXUSER /home/youruser/gitlab-docker-local

echo "
[Unit]
Description=Gitlab Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
User=$1
WorkingDirectory=$2
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/gitlab.service

systemctl start gitlab
systemctl enable gitlab