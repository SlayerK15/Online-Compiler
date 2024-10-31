name: Destroy Infrastructure

on:
  workflow_dispatch:
    inputs:
      confirm_destroy:
        description: 'Type "DESTROY" to confirm'
        required: true
        type: string

env:
  AWS_REGION: ap-south-1
  TERRAFORM_VERSION: 1.5.0
  TF_WORKING_DIR: ./onlinecompiler terraform

jobs:
  terraform-destroy:
    name: Terraform Destroy
    runs-on: ubuntu-latest
    if: github.event.inputs.confirm_destroy == 'DESTROY'
    
    defaults:
      run:
        working-directory: ${{ env.TF_WORKING_DIR }}
    
    steps:
    - name: Checkout Repository
      uses: actions/checkout@v4

    - name: Configure AWS Credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ env.TERRAFORM_VERSION }}

    - name: Verify Working Directory
      run: |
        pwd
        ls -la
        echo "Current working directory contents:"

    - name: Terraform Init
      id: init
      run: terraform init -input=false

    - name: Comprehensive Resource Cleanup
      run: |
        echo "Starting comprehensive resource cleanup..."
        
        # Get cluster information
        CLUSTER_ARN=$(aws ecs list-clusters | grep "online-compiler" || echo "")
        
        if [ ! -z "$CLUSTER_ARN" ]; then
          CLUSTER_NAME=$(echo $CLUSTER_ARN | cut -d'/' -f2 | tr -d '",')
          echo "Found cluster: $CLUSTER_NAME"
          
          # 1. Update and delete services
          echo "Cleaning up ECS services..."
          SERVICES=$(aws ecs list-services --cluster $CLUSTER_NAME --query 'serviceArns[]' --output text || echo "")
          if [ ! -z "$SERVICES" ]; then
            echo "$SERVICES" | tr '\t' '\n' | while read SERVICE_ARN; do
              SERVICE_NAME=$(echo $SERVICE_ARN | cut -d'/' -f3)
              echo "Updating service $SERVICE_NAME to 0 tasks"
              aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --desired-count 0 || true
            done
            
            # Wait for tasks to drain
            echo "Waiting for tasks to drain..."
            sleep 30
            
            # Delete services
            echo "$SERVICES" | tr '\t' '\n' | while read SERVICE_ARN; do
              SERVICE_NAME=$(echo $SERVICE_ARN | cut -d'/' -f3)
              echo "Deleting service $SERVICE_NAME"
              aws ecs delete-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --force || true
            done
          fi
          
          # 2. Stop all tasks
          echo "Stopping all tasks..."
          TASKS=$(aws ecs list-tasks --cluster $CLUSTER_NAME --query 'taskArns[]' --output text || echo "")
          if [ ! -z "$TASKS" ]; then
            echo "$TASKS" | tr '\t' '\n' | while read TASK_ARN; do
              echo "Stopping task $TASK_ARN"
              aws ecs stop-task --cluster $CLUSTER_NAME --task $TASK_ARN || true
            done
          fi
          
          # Wait for tasks to stop
          echo "Waiting for tasks to stop..."
          sleep 30
          
          # 3. Deregister task definitions
          echo "Cleaning up task definitions..."
          TASK_DEFINITIONS=$(aws ecs list-task-definitions --family-prefix online-compiler --query 'taskDefinitionArns[]' --output text || echo "")
          if [ ! -z "$TASK_DEFINITIONS" ]; then
            echo "$TASK_DEFINITIONS" | tr '\t' '\n' | while read TASK_DEF_ARN; do
              echo "Deregistering task definition $TASK_DEF_ARN"
              aws ecs deregister-task-definition --task-definition $TASK_DEF_ARN || true
            done
          fi
          
          # 4. Delete the cluster
          echo "Deleting cluster $CLUSTER_NAME"
          aws ecs delete-cluster --cluster $CLUSTER_NAME || true
        else
          echo "No ECS cluster found matching 'online-compiler'"
        fi

        # 5. Clean up IAM roles and policies
        echo "Cleaning up IAM roles and policies..."
        
        # Clean up execution role
        EXEC_ROLE="online-compiler-execution-role"
        echo "Cleaning up execution role: $EXEC_ROLE"
        ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name $EXEC_ROLE --query 'AttachedPolicies[*].PolicyArn' --output text 2>/dev/null || echo "")
        if [ ! -z "$ATTACHED_POLICIES" ]; then
          echo "$ATTACHED_POLICIES" | tr '\t' '\n' | while read POLICY_ARN; do
            echo "Detaching policy $POLICY_ARN from role $EXEC_ROLE"
            aws iam detach-role-policy --role-name $EXEC_ROLE --policy-arn $POLICY_ARN || true
          done
        fi
        aws iam delete-role --role-name $EXEC_ROLE || true

        # Clean up task role
        TASK_ROLE="online-compiler-task-role"
        echo "Cleaning up task role: $TASK_ROLE"
        INLINE_POLICIES=$(aws iam list-role-policies --role-name $TASK_ROLE --query 'PolicyNames[]' --output text 2>/dev/null || echo "")
        if [ ! -z "$INLINE_POLICIES" ]; then
          echo "$INLINE_POLICIES" | tr '\t' '\n' | while read POLICY_NAME; do
            echo "Deleting inline policy $POLICY_NAME from role $TASK_ROLE"
            aws iam delete-role-policy --role-name $TASK_ROLE --policy-name $POLICY_NAME || true
          done
        fi
        aws iam delete-role --role-name $TASK_ROLE || true

        # 6. Clean up CloudWatch log groups
        echo "Cleaning up CloudWatch log groups..."
        LOG_GROUPS=$(aws logs describe-log-groups --log-group-name-prefix "/ecs/online-compiler" --query 'logGroups[].logGroupName' --output text || echo "")
        if [ ! -z "$LOG_GROUPS" ]; then
          echo "$LOG_GROUPS" | tr '\t' '\n' | while read LOG_GROUP; do
            echo "Deleting log group $LOG_GROUP"
            aws logs delete-log-group --log-group-name "$LOG_GROUP" || true
          done
        fi

        # 7. Verify all resources are cleaned up
        echo "Verifying cleanup..."
        
        # Verify cluster
        VERIFY_CLUSTER=$(aws ecs describe-clusters --clusters $CLUSTER_NAME --query 'clusters[].status' --output text 2>/dev/null || echo "")
        if [ ! -z "$VERIFY_CLUSTER" ]; then
          echo "Warning: Cluster might still exist. Status: $VERIFY_CLUSTER"
        fi
        
        # Verify IAM roles
        for ROLE in "$EXEC_ROLE" "$TASK_ROLE"; do
          if aws iam get-role --role-name $ROLE 2>/dev/null; then
            echo "Warning: Role $ROLE might still exist"
          fi
        done

        echo "Resource cleanup completed"

    - name: Terraform Plan Destroy
      id: plan
      run: |
        terraform plan -destroy -no-color
      continue-on-error: true

    - name: Terraform Destroy
      run: terraform destroy -auto-approve
