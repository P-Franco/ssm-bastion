#!/usr/bin/env bash
set -euo pipefail

# Basic hardening & helpers
yum update -y
yum install -y jq amazon-cloudwatch-agent