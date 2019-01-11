# Gitlab CE Docker Compose Local Install

Install and run Gitlab CE and Gitlab-Runner in local docker containers via docker-compose.

### Preqrequisites

- [Docker](https://docs.docker.com/install/)
- [Docker Compose](https://docs.docker.com/compose/install/#install-compose)

For the purpose of this demonstration, we will be assuming the persistent docker volumes will be at the path `/srv/gitlab` and `/srv/gitlab-runner` as well as a hostname of `my.gitlab`.  For the example project we'll be testing and building an [evergreen app](https://github.com/ProjectEvergreen/create-evergreen-app) with Gitlab's CI/CD.


## Guide

1. [Optionally modify omnibus and docker-compose.yml with a custom hostname](#gitlab-omnibus-config)
2. [Create a Self-Signed Certificate](#create-self-signed-certificate)
3. [Set hostname on local machine](@set-hostname)
4. [Start with Docker Compose](#docker-compose-control)
5. Browse: https://my.gitlab:3143 to see your new installation.
6. Add an exception in your browser for the page because of the self-signed certificate. If Chrome hit "advanced" then "Proceed to my.gitlab (unsafe)". If firefox, click "add exception".
7. Create a new gitlab admin password
8. Create a new user account
9. [Add Account SSH key](#add-account-ssh-key) 
10. [Create New Project](#create-new-project)
11. [Create New Runner](#register-new-runner)
12. [Setup Runner Docker in Docker](#setup-runner-docker-socket-binding)
13. [Setup Gitlab DevOps](#setup-devops)
14. [Run test job](#run-test-job)
15. [Troubleshooting]


## Gitlab Omnibus Config

Our gitlab omnibus config environment variable in our `docker-compose.yml` file by default is using the hostname `my.gitlab` for this example. You can use whichever you'd like, but if you change it you'll need to change the hostname everywhere else, [including the host machine](#set-hostname).

```
GITLAB_OMNIBUS_CONFIG: |
    external_url 'https://my.gitlab:3143'
    gitlab_rails['gitlab_shell_ssh_port'] = 3122
    registry_external_url 'https://my.gitlab:4567'
```
You will also want to make the network alias for the GitLab container your hostname

```
networks:
    dev-net:
        aliases:
        - my.gitlab
```

### Ports
You may choose to edit the preferred ports for this example above but if you choose to do that you'll need to change the ports part of the `docker-compose.yml` as well as the `external_url` and `registry_external_url`. By default, 443 and 22 are in use by my system so it makes sense to map a different port.

```
ports:
- '4567:4567'
- '3143:443'
- '3122:22'
```

**Note**: the external_url port cannot be the same as registry_external_port

### Enable and Configure Registry

In our omnibus config environment variable within `docker-compose.yml` we already have the registry configured:

```
registry_external_url 'https://my.gitlab:4567'
registry_nginx['enable'] = true
registry_nginx['ssl_certificate'] = "/etc/ssl/certs/gitlab/server-cert.pem"
registry_nginx['ssl_certificate_key'] = "/etc/ssl/certs/gitlab/server-key.pem"
```

It's important that you [choose(and expose) a port](#ports) that's different than the other external_url as we've done here using port `4567`. You will also need access to the GitLab self-signed certificate to authenticate the connection.


## Create Self-Signed Certificate

[Follow Steps 1-5 for generating a self-signed certificate](https://github.com/GetchaDEAGLE/gitlab-https-docker#generating-a-self-signed-certificate)

Then copy the certificate to your persistent docker volumes
```
sudo mkdir -p /srv/gitlab/ssl
sudo mkdir /srv/gitlab-runner/certs -p
sudo cp server-*.pem /srv/gitlab/ssl/
sudo cp server-*.pem /srv/gitlab-runner/certs/
sudo cp server-cert.pem /srv/gitlab-runner/certs/my.gitlab.crt
sudo ln -s /srv/gitlab/ssl /srv/gitlab-runner/certs
```

These 2 folders (`/srv/gitlab/ssl` and `/srv/gitlab-runner/certs`) will be mounted from the host to our gitlab containers.

**Note** Gitlab Runner [by default reads a predefined cert named your.hostname.crt](https://docs.gitlab.com/runner/configuration/tls-self-signed.html#supported-options-for-self-signed-certificates). Gitlab's Nginx and Nginx Registry will use server-cert.pem and server-key.pem

## Configure git to accept self-signed certificate

In order to clone from gitlab on your host machine or elsewhere on your network, we need to tell git to accept our self-signed certificate.
```
git config --global http."https://my.gitlab/".sslCAInfo /srv/gitlab/ssl/server-cert.pem
```

## Set Hostname

To set the hostname you want to forward to on your local machine

```
sudo nano /etc/hosts
```

add the following line at the bottom:

```
127.0.0.1       my.gitlab
```

## Docker Compose Control

### Start

Launch gitlab ce and gitlab runner via docker-compose with:
```
docker-compose up -d  
```
The `-d` is daemon mode. Remove it to see output logs.

Visit https://my.gitlab:3143 to see your new installation

### Stop

```
docker-compose down
```

## Add Account SSH Key

[Add](https://docs.gitlab.com/ce/ssh/README.html#generating-a-new-ssh-key-pair) / [generate](https://docs.gitlab.com/ce/ssh/README.html#generating-a-new-ssh-key-pair) a ssh key
```
tail ~/.ssh/id_rsa.pub
```
Copy entire output and paste to https://my.gitlab:3143/profile/keys

## Create New project

1. Click new project. Name it example
2. Test clone new project on host machine (make sure you've [configured git global config on your local machine to accept self-signed cert](#configure-git-to-accept-self-signed-certificate)). 

    ```
    git clone ssh://git@my.gitlab:3122/yourusername/example.git
    ```
    It will ask you yes/no whether to add the fingerprint. type: `yes` 

3. Add example repository remote to a new application called `my-app` (replacing yourusername with your gitlab username). We're copying over the provided `Dockerfile` and `.gitlab-ci.yml` configs to setup the application for Gitlab's CI/CD with containers. Also we're adding some ignore files to prevent eslint from checking out node_modules folder when it builds a new container.

    ```
    npx create-evergreen-app my-app
    cd my-app
    git init
    echo "node_modules" > .gitignore
    echo "node_modules" > .eslintignore
    cp ../Dockerfile .
    cp ../.gitlab-ci.yml .
    git remote add origin ssh://git@my.gitlab:3122/yourusername/example.git
    git add .
    git commit -m "Initial commit"
    git push -u origin master
    ```

## Register New Runner

* [Gitlab Runner commands](https://docs.gitlab.com/runner/commands/)

1. Browse your projects *Settings -> CI/CD* and expand the *Runners* section.

2. You need to scroll down to the "Set up a specific Runner manually" section and copy the registration token, you will need it below

3. Run:
    ```
    docker exec -it gitlab-runner gitlab-runner register
    ```

    Enter your hostname, for this example: my.gitlab

    ```
    Please enter the gitlab-ci coordinator URL (e.g. https://gitlab.com/):`
    https://my.gitlab
    ```

    Enter the token you copied in the previous step

    ```
    Please enter the gitlab-ci token for this runner:
    SDfksafsDAF_fsadfas42
    ```

    ```
    Please enter the gitlab-ci description for this runner:
    [1297529a8a58]: Docker Runner
    Please enter the gitlab-ci tags for this runner (comma separated):
    docker
    Registering runner... succeeded                     runner=RQ-XuZwP
    Please enter the executor: docker-ssh, virtualbox, docker+machine, docker-ssh+machine, docker, parallels, shell, ssh, kubernetes:
    docker
    Please enter the default Docker image (e.g. ruby:2.1):
    docker:stable
    Runner registered successfully. Feel free to start it, but if it's running already the config should be automatically reloaded! 
    ```

4. You can now edit this new configuration from either:

    your persistent volume 

    ```
    sudo gedit /srv/gitlab-runner/config.toml
    ```

    or from within the gitlab-runner container
    ```
    docker exec -it gitlab-runner nano /etc/gitlab-runner/config.toml
    docker exec -it gitlab-runner gitlab-runner restart
    ```

## Setup Runner Docker socket binding

[Official Gitlab Docs on docker socket binding](https://docs.gitlab.com/ee/ci/docker/using_docker_build.html#use-docker-socket-binding)

1. Edit the `config.toml` runner configuration(using the steps above) so that the following is amended:

    ```
    [[runners]]
      name = "Docker Runner"
      url = "https://my.gitlab"
      token = "YOUR_TOKEN"
      executor = "docker"
      clone_url = "https://my.gitlab"
      [runners.docker]
        tls_verify = false
        image = "docker:stable"
        privileged = false
        disable_entrypoint_overwrite = false
        oom_kill_disable = false
        disable_cache = false
        volumes = ["/var/run/docker.sock:/var/run/docker.sock", "/cache"]
        network_mode = "development"
        shm_size = 0
      [runners.cache]
        [runners.cache.s3]
        [runners.cache.gcs]
    ```

    You can also copy and paste the provided `config.toml` into your `/srv/gitlab-runner` directory and simply edit the `token` with the generated gitlab token from [Register New Runner step 2](#register-new-runner).

    The `network_mode` and `clone_url` are necessary so that your runner can clone your gitlab repository at your hostname `my.gitlab`. To bind our host docker socket to the runner we need to add the `volumes` parameter. 

2. Save it and restart the gitlab-runner service

    ```
    docker exec -it gitlab-runner gitlab-runner restart
    ```

**Note** There is a security concern here that you should be aware of.  

According to the [official Gitlab documentation](https://docs.gitlab.com/ee/ci/docker/using_docker_build.html#use-docker-socket-binding):
```
By sharing the docker daemon, you are effectively disabling all the security mechanisms of containers and exposing your host to privilege escalation which can lead to container breakout. For example, if a project ran docker rm -f $(docker ps -a -q) it would remove the GitLab Runner containers
```

There are [other methods](https://docs.gitlab.com/ee/ci/docker/using_docker_build.html#runner-configuration) of configuring the runner for docker builds, this is an example for a small personal local build using docker-compose. If you're running this for a small/medium sized company, you will may want to configure this differently. From my tests, self-signed certs without a real domain didn't work well with any other method.

## Setup DevOps

To push new containers to our gitlab registry we need to use our login credential to login through docker in the gitlab runner.  One way of doing that is to enter variables into your `Settings -> CI/CD -> Variables(expanded)`.

Add each of the following
```
CI_REGISTRY my.gitlab:4567
CI_REGISTRY_USER your_username
CI_REGISTRY_PASSWORD your_password
```

Save variables.

You can see these variables in the provided `.gitlab-ci.yml` devops configuration file.

Here we're setting git to not verify ssl due to the self-signed certificate. W

We're using the package.json version number as the tag for the container image. 

We push the specific version along with a general latest version. We're then removing those images from our host because it's redundant, we don't need to take up image space on Host machine in addition to the Gitlab CE registry.

## Run test job

If you followed all the above steps, the CI/CD pipeline will run on every commit to the master branch. Your project will run tests, build a container, push that container to the registry. To try this out, go to your project -> CI/CD -> Pipelines -> Run pipeline. Or just commit then push something new to the project repository.


## Troubleshooting

1. If you see an error about 'unknown certificate authority' in your gitlab-runner, make sure you included the correct `volumes` docker socket bind within your [gitlab-runner config.toml](#setup-runner-docker-socket-binding)

2. If you see an error 'could not resolve host' when gitlab-runner initially clones your repository, make sure you have the correct clone_url, and network_mode, within your [gitlab-runner config.toml](#setup-runner-docker-socket-binding), that matches your hostname and docker network within your `docker-compose.yml`.

3. If you see an error 'connection refused' when gitlab-runner initially clones your repository, make sure you have the correct clone_url within your [gitlab-runner config.toml](#setup-runner-docker-socket-binding) that matches your hostname within your `docker-compose.yml` e.g. `https://my.gitlab` without a port.

4. If you see an error in gitlab-runner after docker login `unauthorized: HTTP Basic: Access denied`, make sure you entered the correct CI_REGISTRY_URL, CI_REGISTRY_USER, CI_REGISTRY_PASS in the variables section of your project -> Settings -> CI/CD. See [Setup DevOps](#setup-devops).