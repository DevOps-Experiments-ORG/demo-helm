# Testing the Terraform / Terragrunt locally

CloudShell can't run this (1 GB disk is too small for the AWS provider).
Run it from your local machine instead.

## 1. Install tools (Windows PowerShell)

```powershell
winget install Hashicorp.Terraform
winget install Gruntwork.terragrunt
winget install Amazon.AWSCLI
```

(macOS/Linux: use `brew install terraform terragrunt awscli`.)

Verify:
```powershell
terraform version
terragrunt --version
aws --version
```

## 2. Configure AWS credentials

```powershell
aws configure
# Access Key / Secret / region = ap-south-1 / output = json
aws sts get-caller-identity    # must show 730335384723
```

## 3. Validate the code (no AWS changes, smallest check)

```powershell
cd demo-helm\Iac\terragrunt-resources\dev\security-services
terragrunt init
terraform -chdir=.terragrunt-cache\*\* validate   # or just: terragrunt validate
```

## 4. See the plan (no changes made)

```powershell
terragrunt plan
```

- Clean region/account -> plan shows "9 to add".
- Your current account (services already exist) -> plan may show conflicts;
  run the imports from ../../../../deploy-all.sh first, or test in a fresh region.

## 5. Apply (actually create) — use a CLEAN region for a conflict-free proof

Edit the region to one where you have NOT enabled these services, e.g. edit
`Iac/terragrunt.hcl` locals `aws_region = "eu-west-1"`, then:

```powershell
terragrunt apply
```

Expected output:
```
Apply complete! Resources: 9 added, 0 changed, 0 destroyed.
Outputs:
  guardduty_detector_id      = "..."
  signer_profile_arn         = "..."
  ecr_scanning_type          = "ENHANCED"
  inspector_resource_types   = ["ECR","EC2"]
```

## 6. Tear down the test (if you used a throwaway region)

```powershell
terragrunt destroy
```

## Notes

- Local state is used (no S3 bucket needed). State file lands in the
  security-services folder as `terraform.tfstate`.
- Only the AWS provider is downloaded (~700 MB) — needs a machine with more
  than CloudShell's 1 GB.
- The module is idempotent; re-running `apply` makes no changes once created.
