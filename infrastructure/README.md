# Tarot API Infrastructure

This directory contains the Pulumi Infrastructure as Code (IaC) configuration for the Tarot API project.

## Overview

The infrastructure is managed using Pulumi with a YAML configuration approach. Key components include:

- AWS EC2 Virtual Private Cloud (VPC)
- Amazon RDS PostgreSQL database
- Amazon ElastiCache Redis
- AWS S3 storage buckets
- Amazon ECR container repositories
- Amazon ECS for container orchestration
- DNS and certificate management

## Architecture

The Tarot API uses a hybrid infrastructure approach that leverages:

1. **Pulumi** - For cloud infrastructure provisioning
2. **Rake Tasks** - For application deployment

## Getting Started

### Prerequisites

- AWS CLI configured with appropriate credentials
- Pulumi CLI installed
- Ruby environment set up

### Setup

1. Install Pulumi:
   ```bash
   gem install pulumi
   ```

2. Login to Pulumi:
   ```bash
   pulumi login
   ```

3. Initialize the stack:
   ```bash
   bundle exec rake infra:init
   ```

## Deployment

To deploy the infrastructure:

```bash
# For staging environment
bundle exec rake infra:deploy[staging]

# For production environment
bundle exec rake infra:deploy[production]

# For preview environments
bundle exec rake infra:create_preview[name]
```

## Container Registry

Each environment has its own Amazon ECR repository created by Pulumi. The repository URL follows this format:

```
<aws-account-id>.dkr.ecr.<region>.amazonaws.com/tarot-api-<environment>
```

To access the container registry URL programmatically:

```bash
cd infrastructure && pulumi stack output containerRegistry
```

This URL is used by the deployment tasks to push and deploy container images.

## Outputs

Pulumi exports several important outputs that can be used by other scripts and processes:

- `containerRegistry`: URL of the ECR repository for container images
- `dbEndpoint`: PostgreSQL database endpoint
- `redisEndpoint`: Redis cache endpoint 
- `ecsClusterId`: ECS cluster ARN
- `s3BucketName`: S3 bucket name for file storage

To view all outputs:

```bash
pulumi stack output
```

## Managing Environments

To destroy an environment:

```bash
bundle exec rake infra:destroy[environment]
```

To manage Pulumi state:

```bash
# Backup state
bundle exec rake infra:manage_state[backup]

# Restore state
bundle exec rake infra:manage_state[restore,backup_file]
```

## Security Considerations

- Sensitive configuration is encrypted using Pulumi secrets
- AWS resources use appropriate IAM roles with least privilege
- All communication uses TLS/SSL encryption
- Database and cache instances are placed in private subnets 