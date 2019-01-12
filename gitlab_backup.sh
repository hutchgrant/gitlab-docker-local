#!/bin/bash

CONTAINER="GitLab"
TARGET_DIR="/some/external/drive/backups"
GITLAB_DIR="/srv/gitlab"
RUNNER_DIR="/srv/gitlab-runner"
REMOVE_DAYS=1

# Backup Application DATA
echo "Backing up GitLab application data"
docker exec -it $CONTAINER gitlab-rake gitlab:backup:create && \
cp -u $GITLAB_DIR/data/backups/* $TARGET_DIR/

# Backup configurations, SSH keys, and SSL certs
echo "Backing up GitLab configurations, ssh keys, and ssl certs"
sh -c "umask 0077; tar cf $TARGET_DIR/$(date "+%s-gitlab-config.tar") -C $GITLAB_DIR config ssl" 
sh -c "umask 0077; tar cf $TARGET_DIR/$(date "+%s-gitlab-runner.tar") -C $RUNNER_DIR ."

# Remove files older than x days 
echo "Removing files older than $REMOVE_DAYS days"
find $TARGET_DIR/*.tar -mtime $REMOVE_DAYS -exec rm {} \;