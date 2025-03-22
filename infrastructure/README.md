# Tarot API Infrastructure

This directory contains the [Pulumi](https://www.pulumi.com/) infrastructure definitions for the Tarot API project, configured using YAML.

## Overview

The infrastructure is defined as code using Pulumi and deployed to AWS. The setup includes:

- VPC and networking (network.yaml)
- Database (PostgreSQL via RDS, database.yaml)
- Caching layer (Redis via ElastiCache, cache.yaml)
- Storage (S3 buckets, storage.yaml)
- Container orchestration (ECS, ecs.yaml)
- Monitoring and observability (monitoring.yaml)
- DNS and domain management (dns.yaml, domain.yaml, alt-domain.yaml)
- LLM integration (llm.yaml)

## Environment Stacks

- **Production:** Deployed at tarotapi.cards
- **Staging:** Deployed at staging.tarotapi.cards
- **Preview environments:** Deployed at preview-{feature-name}.tarotapi.cards

## Available Commands

All infrastructure commands are available through Rake tasks:

```bash
# Deploy to staging
bundle exec rake infra:deploy[staging]

# Deploy to production
bundle exec rake infra:deploy[production]

# Create a preview environment
bundle exec rake infra:create_preview[feature-name]

# Destroy an environment
bundle exec rake infra:destroy[environment]

# Backup Pulumi state
bundle exec rake infra:manage_state[backup]

# Restore Pulumi state from a file
bundle exec rake infra:manage_state[restore,file]
```

## Configuration

The main configuration is in `config.yaml`, with environment-specific overrides in:
- `Pulumi.staging.yaml`
- `Pulumi.production.yaml`

### Key Configuration Parameters

- `aws:region`: AWS region for all resources
- `environment`: Current environment (dev, staging, production)
- `domain`: Primary domain (tarotapi.cards)
- `alt-domain`: Alternative domain (tarot.cards)
- `project-name`: Project identifier
- `enable-cost-saving`: Flag for cost optimization features

## Secrets Management

Sensitive configuration values are managed as Pulumi secrets and stored encrypted. 
These include:
- Database passwords
- API keys
- Service credentials

## State Management

Pulumi state is managed in AWS S3. You can back up and restore state using the Rake tasks.

## Cost Optimization

The infrastructure includes cost optimization features:
- Automatic scaling down for non-production environments during non-business hours
- Right-sized resources for each environment type
- Automatic cleanup of preview environments after inactivity

## Continuous Deployment

Infrastructure deployment is automated through GitHub Actions workflows in `.github/workflows/infra-deploy.yml`. 