## AWS EC2 Cost Estimator
A Shell-based automation tool that identifies running Amazon EC2 instances in an AWS account, filters them using resource tags, and generates an estimated cost summary. It also supports automatically tagging running instances that do not have the configured environment tag.

## Task Overview
Managing cloud costs is important in DevOps. This project automates the process of identifying running EC2 instances in a development AWS account and estimating their compute costs.

The script uses the AWS CLI to retrieve EC2 instance details, applies tag-based filtering, calculates estimated hourly, daily, and monthly costs, and generates a CSV report.

## Features
```text
Retrieves running EC2 instances using the AWS CLI.
Filters instances using configurable AWS tags.

Automatically adds the configured environment tag to running instances that do not have it.

Calculates estimated hourly, daily, and monthly costs.

Displays a cost summary in the terminal.

Generates a CSV report for further analysis.

Supports configurable AWS profiles, regions, and tag values.

Handles instances with unsupported pricing entries.
```

## Technologies Used
```text

Shell Script (Bash) – Automation and cost calculations

AWS CLI – Communication with AWS services

Amazon EC2 – Compute instance information

jq – JSON processing

awk – Cost calculations

Git and GitHub – Version control
```

## Required IAM Permissions

The script requires these permissions:

| Permission | Purpose |
|---|---|
| `ec2:DescribeInstances` | Retrieve EC2 instance information |
| `ec2:CreateTags` | Add the environment tag to untagged instances |
| `sts:GetCallerIdentity` | Verify the AWS account identity |

Important: The automatic tagging feature modifies AWS resources. It tags every running EC2 instance in the configured region that does not already have the selected tag. Review the target account and region before running the script.


## Configuration

The script uses the following default configuration:

| Variable | Default Value | Description |
|---|---|---|
| `AWS_PROFILE` | `dev` | AWS CLI profile |
| `AWS_REGION` | `ap-southeast-2` | AWS region |
| `TAG_KEY` | `Environment` | Tag key used for filtering |
| `TAG_VALUE` | `dev` | Tag value used for filtering |

## Installation and Execution
1. Clone the repository
```bash
git clone https://github.com/sadequekhan46/aws-ec2-cost-estimator.git
```
2. Navigate to the project directory
```bash
cd aws-ec2-cost-estimator
```
3. Give execution permission
```bash
chmod +x ec2_cost_estimator.sh
```
4. Run the script
```bash
./ec2_cost_estimator.sh
```
## Cost Estimation
```text
The script uses predefined hourly rates for supported EC2 instance types.

The cost calculations follow these formulas:

Hourly Cost = EC2 Instance Hourly Rate

Daily Cost = Hourly Cost × 24

Monthly Cost = Hourly Cost × 730

The monthly calculation assumes 730 hours.
```

![Project Screenshot](screenshots/aws-instances-cost.png)

## CSV Report

After execution, the script generates:
```text
reports/ec2-cost-report.csv
```

The report contains EC2 instance details and estimated costs. You can open it using Microsoft Excel or another spreadsheet application.
## Limitations

1. Cost estimates use predefined hourly rates rather than live AWS pricing.

2. Actual costs may vary by region, operating system, and purchasing model.

3. EBS storage, snapshots, data transfer, taxes, and other AWS services are not included.

4. Only supported instance types with configured rates are included in the priced total.

5. Automatic tagging requires ec2:CreateTags permission and changes resource metadata.

## Future Improvements

1. Integrate live AWS Pricing API data.

2. Add support for more EC2 instance types.

3. Generate HTML cost reports.

4. Add cost comparison between AWS regions.

5. Integrate the script into a scheduled CI/CD workflow.

##  Author
**Khan Sadeque**
Cloud & DevOps intern | MCA Graduate