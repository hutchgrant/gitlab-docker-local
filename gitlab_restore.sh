#!/bin/bash

CONTAINER="GitLab"
TARGET_DIR="/srv/gitlab"
RUNNER="gitlab-runner"
RUNNER_DIR="/srv/gitlab-runner"
BACKUP_DIR="/some/external/drive/gitlab/backups"

# Restore application data
cp $BACKUP_DIR/*_gitlab_backup.tar $TARGET_DIR/data/backups/
docker exec -it $CONTAINER sh -c 'chown git.git /var/opt/gitlab/backups/*.tar'
docker exec -it $CONTAINER gitlab-rake gitlab:backup:restore

# Restore configurations, ssh keys, SSL
tar -xvf $BACKUP_DIR/*-gitlab-config.tar -C $TARGET_DIR
docker exec -it $CONTAINER gitlab-ctl reconfigure

# Fix permissions with container registry
docker exec -it $CONTAINER sh -c 'chown -R registry:registry /var/opt/gitlab/gitlab-rails/shared/registry'

# Restore Gitlab Runner 
tar -xvf $BACKUP_DIR/*-gitlab-runner.tar -C $RUNNER_DIR
docker exec -it $RUNNER gitlab-runner restart

# Restart all containers
docker-compose restart