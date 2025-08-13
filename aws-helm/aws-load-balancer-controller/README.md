# AWS Load Balancer (ALB) Ingress Controller Deployment Guide

This guide explains how to deploy the AWS Load Balancer Controller (ALB Ingress Controller) using Helm in your EKS cluster.

## Prerequisites

- An EKS cluster with IAM OIDC provider enabled
- IAM role for the controller (see AWS docs)
- Helm installed
- Kubernetes context set to your EKS cluster

## Values File

Use the provided `values.yaml` for configuration. Update values as needed for your environment.

## Install the Controller

1. Add the AWS EKS Helm repo:

   ```sh
   helm repo add eks https://aws.github.io/eks-charts
   helm repo update
   ```

2. Install the TargetGroupBinding CRDs:

   ```sh
   kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"
   ```

3. Deploy the controller:
   ```sh
   helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
     --namespace kube-system \
     --set clusterName=anysource \
     --values values.yaml
   ```

## Notes

- Ensure the IAM role ARN in the values file matches your setup.
- The controller must run in the `kube-system` namespace for IRSA.
- For target group bindings, uncomment and set the relevant values in the values file if needed.

## References

- [AWS Load Balancer Controller Docs](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html)
- [Helm Chart Reference](https://github.com/aws/eks-charts/tree/master/stable/aws-load-balancer-controller)
