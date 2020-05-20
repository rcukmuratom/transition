# Transition

Rails app for managing the transition of websites to GOV.UK. Specifically, it's for the production of and handling
of mappings for use with [Bouncer](https://github.com/alphagov/bouncer).

## Dependencies

* Redis
* PostgreSQL 9.3+ (the app uses materialized views, which were introduced in 9.3).
  This is included in the Trusty dev VM, which is now the default.

## Set up the database

```sh
bundle exec rake db:setup
```

## Seed the database

FactoryBot will seed some dummy data to get started with.

```sh
bundle exec rake db:seed
```

## Configure the environment variables

Copy the file `env.example` to `.env` and fill in the environment variables:

First, Auth0 environment variables configure the Auth0 plugin for user login.
These values come from your [Auth0 tenant](https://manage.auth0.com/dashboard).
```
AUTH0_CLIENT_ID=abc123
AUTH0_CLIENT_SECRET=xyz456
AUTH0_DOMAIN=example.eu.auth0.com
```

[Rollbar](https://rollbar.com/) is used for error reporting, though this is not
used in development, so does not need to be set.
```
ROLLBAR_ACCESS_TOKEN=
```

The app needs a Redis server for queueing:
```
REDIS_URL=redis://localhost:6379
```

Data can be ingested from an S3 bucket. Use the AWS IAM tools to create
[security credentials](https://docs.aws.amazon.com/general/latest/gr/aws-security-credentials.html)
to use here.
```
AWS_ACCESS_KEY_ID=access-key-id-goes-here
AWS_SECRET_ACCESS_KEY=access-key-secret-goes-here
AWS_REGION=eu-west-2
```

## Running the app

The web application itself is run like any other Rails app, for example:

```sh
script/rails s
```

In development, you can run sidekiq to process background jobs:

```sh
bundle exec sidekiq -C config/sidekiq.yml
```

### Running with docker-compose

Alternatively, you can use `docker-compose` to run the application. The
config values set in `.env` will be automatically passed to the docker containers.

```sh
docker-compose build
docker-compose up -d
docker-compose run transition rake db:setup
```

If you have problems, try `docker-compose rm` and then `docker-compose up -d` again. Sometimes
database setup doesn't happen quite right, and until you remove and rebuild that part, the
problem will persist.

## Style guide

Available at /style, the guide documents how transition is using bootstrap, where the app has diverged from default
styles and any custom styles needed to fill in the gaps.

## Deployments

This service is hosted on dxw's container platform called Dalmatian.

Deployments from this application's point of view are done by merging new code into either the develop branch for staging or the master branch for production. Once pushed [DockerHub](https://cloud.docker.com/u/thedxw/repository/docker/thedxw/transition) will build a new Docker Image.

### Dalmation

Once complete, the deployment process to provision this new container hands over to Dalmatian.

This application has a [separate private GitHub repository](https://github.com/dxw/ukri-transition-dalmatian-config) that is responsible for provisioning the required infrastructure. This includes the [Bouncer service](https://github.com/dxw/bouncer) and is done using Terraform.

The way to deploy new containers is manual and involves downtime:

1. Within AWS select the dxw-dalmatian-1 role
1. Visit the ECS service
1. Select the intended cluster (be careful as this cluster is shared)
1. Click 'Tasks'
1. Search by 'transition'
1. Select all tasks running for the app in the intended environment
1. Click 'stop'
1. Those containers will restart and pull the new version of the containers


## Access the console

To access a Rails console or run a rake task on a live environment:

1. Within AWS select the dxw-dalmatian-1 role
1. Visit the Systems Manager service
1. Select 'Session Manager'
1. Click 'Start session'
1. Select a running node for the intended environment
1. Once the session has started enter `sudo su`
1. Enter `docker ps`
1. Copy the intended container ID from a container of the right application (be careful other containers are running here)
1. Enter `docker exec -ti <container-id> /bin/bash`
1. Enter `eval $(AWS_ENV_PATH=/ukri-transition-0-staging/$SSM_PATH_SUFFIX/ AWS_REGION=eu-west-2 ./aws-env)` to load the environment variables
1. Enter `rails c` or `rake` as normal
