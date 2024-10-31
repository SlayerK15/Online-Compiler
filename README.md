# Online Compiler Infrastructure

This repository contains Infrastructure as Code (IaC) using Terraform to deploy and manage an online compiler service on AWS ECS. The infrastructure is automatically deployed and managed through GitHub Actions workflows.

## Prerequisites

Before you begin, ensure you have:

1. An AWS account with appropriate permissions
2. GitHub repository secrets configured:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

## Infrastructure Overview

The infrastructure is deployed in the `ap-south-1` region and includes:
- Amazon ECS Cluster
- VPC with public and private subnets
- Load Balancer
- IAM roles and policies
- CloudWatch log groups
- Security Groups
- Associated networking components

## GitHub Actions Workflows

### Deploy Infrastructure (`deploy.yml`)

This workflow automatically deploys the infrastructure when changes are pushed to the main branch or when manually triggered.

#### Workflow Triggers:
- Push to `main` branch
- Pull requests to `main` branch
- Manual trigger (workflow_dispatch)

#### Features:
- Terraform initialization and validation
- Infrastructure plan generation
- Automatic plan comments on pull requests
- Automatic apply on merge to main

### Destroy Infrastructure (`destroy.yml`)

This workflow safely destroys all infrastructure components when manually triggered.

#### Safety Features:
- Requires manual confirmation by typing "DESTROY"
- Comprehensive cleanup of resources:
  - ECS services and tasks
  - IAM roles and policies
  - CloudWatch log groups
  - VPC and networking components
  - Load Balancers
  - Security Groups

## Usage

### Deploying Infrastructure

The infrastructure will automatically deploy when changes are merged to the main branch. To manually trigger a deployment:

1. Go to the "Actions" tab in your repository
2. Select the "Deploy Infrastructure" workflow
3. Click "Run workflow"
4. Select the branch and click "Run workflow"

### Destroying Infrastructure

To safely destroy all infrastructure:

1. Go to the "Actions" tab in your repository
2. Select the "Destroy Infrastructure" workflow
3. Click "Run workflow"
4. Type "DESTROY" in the confirmation input
5. Click "Run workflow"

The destroy process will:
1. Scale down ECS services
2. Remove all running tasks
3. Delete ECS services and task definitions
4. Clean up IAM roles and policies
5. Remove CloudWatch log groups
6. Delete VPC and associated networking components
7. Run Terraform destroy

## Working Directory Structure

The Terraform configurations should be placed in:
```
./onlinecompiler terraform/
```

## Terraform Version

This infrastructure uses Terraform version 1.5.0. The version is managed automatically by the GitHub Actions workflows.

## Contributing

When contributing to this repository:
1. Create a new branch for your changes
2. Submit a pull request to the main branch
3. The deploy workflow will automatically run and comment with the Terraform plan
4. Request review from maintainers
5. Once approved and merged, the infrastructure will automatically update

## Troubleshooting

If the destroy workflow fails to remove some resources:
1. Check the workflow logs for specific error messages
2. Verify resource dependencies are properly handled
3. Ensure AWS credentials have sufficient permissions
4. Try running the destroy workflow again
5. Manual cleanup might be required for persistent resources

## Security Considerations

- AWS credentials are stored as GitHub secrets
- Infrastructure is deployed in private subnets where appropriate
- Security groups are configured with minimum required access
- IAM roles follow the principle of least privilege

## Support

For issues or questions:
1. Check the workflow run logs
2. Review the Terraform plans in pull request comments
3. Create an issue in the repository
4. Contact the infrastructure team
