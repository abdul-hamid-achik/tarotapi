# pulumi infrastructure quick start guide

this document provides a quick overview of how to set up and use the pulumi infrastructure for tarot api.

## prerequisites

- aws cli installed and configured with appropriate credentials
- pulumi cli installed (`brew install pulumi` or visit [pulumi.com](https://www.pulumi.com/docs/install/))
- ruby 3.4+
- appropriate github secrets for github actions workflows

## getting started

1. initialize the pulumi project:

```sh
bundle exec rake pulumi:init
```

This command will:
- Bootstrap an S3 bucket (`tarotapi-pulumi-state`) for Pulumi state storage
- Configure Pulumi to use this bucket as the backend
- Create stacks for all environments (production, staging, preview)
- Set up initial configuration for each stack

2. set up secrets for your environment:

```sh
bundle exec rake pulumi:set_secrets[staging]
```

3. deploy the infrastructure:

```sh
bundle exec rake pulumi:deploy[staging]
```

## environment management

### create a preview environment

preview environments are perfect for testing features before they are merged:

```sh
# via rake task
bundle exec rake pulumi:create_preview[feature-name]

# or via github (preferred)
git tag preview-my-feature-name
git push origin preview-my-feature-name
```

### view infrastructure status

check the current state of your infrastructure:

```sh
bundle exec rake pulumi:info[environment]
```

### deploy to production

production deployments require explicit confirmation:

```sh
# via rake task
bundle exec rake pulumi:deploy_production

# or via github (preferred)
git tag v1.0.0
git push origin v1.0.0
```

### cleanup preview environments

preview environments are automatically cleaned up after 3 days of inactivity, but you can manually clean them up:

```sh
bundle exec rake pulumi:cleanup_previews
```

## domain management

### register domain

to register tarotapi.cards (if not already registered):

```sh
bundle exec rake pulumi:register_domain
```

this will guide you through the aws domain registration process.

### protect domain from deletion

to protect the domain from accidental deletion:

```sh
bundle exec rake pulumi:protect_domain
```

## environments

the project supports multiple deployment environments with their own domains:

- **production**: https://tarotapi.cards
- **staging**: https://staging.tarotapi.cards
- **preview**: https://preview-{feature-name}.tarotapi.cards

### domain patterns

all environments are subdomains of tarotapi.cards:

```
# production
tarotapi.cards
cdn.tarotapi.cards

# staging
staging.tarotapi.cards
cdn-staging.tarotapi.cards

# preview environments
preview-my-feature.tarotapi.cards
cdn-preview-my-feature.tarotapi.cards
```

## infrastructure details

the infrastructure is defined in the `infra/pulumi` directory with yaml configuration files:

- `network.yaml`: vpc, subnets, security groups
- `database.yaml`: rds for postgresql
- `cache.yaml`: elasticache for redis
- `storage.yaml`: s3 buckets and cloudfront cdn
- `dns.yaml`: route53 configuration
- `ecs.yaml`: container orchestration with blue/green deployment support

## github actions integration

the infrastructure is automatically deployed via github actions workflows:

- `pulumi-deploy.yml`: handles deployments to staging and production
- `cleanup-previews.yml`: cleans up inactive preview environments

## costs and optimization

the infrastructure includes cost optimization features:

- staging and preview environments scale down during non-business hours
- resource sizes are optimized for each environment
- preview environments are automatically cleaned up when inactive 

## pulumi state management

### state storage

by default, pulumi uses an aws s3 bucket to store state:

- bucket name: `tarotapi-pulumi-state`
- versioning: enabled
- encryption: aes-256
- lifecycle policy: noncurrent versions expire after 30 days
- public access: blocked

the bootstrap process automatically creates and configures this bucket if it doesn't exist when you run `pulumi:init`.

### local state for development

for local development or testing, you can use local state storage instead of s3:

```sh
pulumi login --local
```

to switch back to s3 state storage:

```sh
pulumi login s3://tarotapi-pulumi-state
```

### state backup

it's recommended to periodically backup your pulumi state:

```sh
# backup all stacks
bundle exec rake pulumi:backup_state

# restore from backup
bundle exec rake pulumi:restore_state[backup_file.tar.gz]
``` 