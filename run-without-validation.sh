#!/bin/bash
# Quick script to run the installer without validation

echo "Running Laravel environment installer without validation..."
echo "This bypasses PHP version format checks that may be incompatible with your Ansible version."
echo

sudo ./laravel-env-installer --skip-validation