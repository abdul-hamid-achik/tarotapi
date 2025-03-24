# Tarot API Infrastructure

This directory contains the infrastructure as code (IaC) implementation for the Tarot API project using Pulumi. The infrastructure is designed to run on AWS and supports multiple environments.

## State Management

We use **Pulumi Cloud** for state storage, providing:
- Centralized access
- Robust security features
- Automatic state locking
- Version history

## Infrastructure Components

### Network Layer
- VPC with CIDR block 10.0.0.0/16
- Public subnets in mx-central-1a and mx-central-1b
- Security groups for service isolation

### Database Layer
- RDS PostgreSQL 14.13
- Instance class: db.t3.micro
- 20GB allocated storage
- Automated backups enabled

### Cache Layer
- Redis ElastiCache cluster
- Node type: cache.t3.micro
- Single node configuration

### Storage Layer
- S3 bucket for general storage
- Private ACL configuration
- Appropriate bucket policies

### Compute Layer
- ECS Fargate for container orchestration
- Task definitions for:
  - API service
  - Ollama LLM service
  - OpenAI proxy service
  - (Future) Anthropic service

### LLM Services Configuration
- Ollama:
  - CPU: 2048
  - Memory: 4096
  - Model: llama3:8b
- OpenAI Proxy:
  - CPU: 256
  - Memory: 512
  - Nginx-based proxy

## Environment Variables

Required environment variables for infrastructure deployment:

```bash
# AWS Configuration
AWS_DEFAULT_REGION=mx-central-1
AWS_ACCOUNT_ID=<your-account-id>
CONTAINER_REGISTRY=<your-registry>

# Database Configuration
DB_INSTANCE_CLASS=db.t3.micro
DB_USERNAME=tarotapi
DB_PASSWORD=<your-password>
DB_PORT=5432

# LLM Configuration
OPENAI_API_KEY=<your-key>
OLLAMA_API_KEY=<your-key>
```

## Deployment

1. Initialize Pulumi:
   ```bash
   pulumi login
   pulumi stack init dev
   ```

2. Configure secrets:
   ```bash
   pulumi config set --secret tarotapi:ollamaApiKey <your-ollama-api-key>
   pulumi config set --secret tarotapi:openaiApiKey <your-openai-api-key>
   ```

3. Deploy:
   ```bash
   pulumi up
   ```

## Stack Outputs

The infrastructure provides the following outputs:
- `dbEndpoint`: PostgreSQL database endpoint
- `redisEndpoint`: Redis cache endpoint
- `ecsClusterId`: ECS cluster identifier
- `containerRegistry`: ECR repository URL
- `s3BucketName`: Storage bucket name

## Security Considerations

- All secrets managed through AWS Secrets Manager
- IAM roles follow least privilege principle
- Security groups restrict access appropriately
- SSL/TLS certificates managed for domains

## Monitoring

- CloudWatch log groups for all services
- CloudWatch alarms for high CPU usage
- Container insights enabled on ECS cluster

## Cost Optimization

- Cost-saving features enabled by default
- t3.micro instances used where appropriate
- Auto-scaling configured for optimal resource usage

## Contributing

When making infrastructure changes:
1. Document changes in this README
2. Test in a development stack first
3. Use `pulumi preview` to review changes
4. Get approval before applying to production

## Troubleshooting

Common issues and solutions:

1. **State Lock Issues**
   ```bash
   pulumi stack export > backup.json
   pulumi stack import --file backup.json
   ```

2. **Resource Creation Failures**
   ```bash
   pulumi refresh
   pulumi up
   ```

3. **Secret Management**
   ```bash
   pulumi config refresh
   pulumi config set-all
   ``` 