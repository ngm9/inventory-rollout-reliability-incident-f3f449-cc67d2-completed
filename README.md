# Task Overview

CartGrid's checkout depends on an inventory reservation service that runs on Kubernetes behind a cluster Service. After a recent platform change, checkout requests cannot reliably reach it, even though the platform accepted the deployment and every expected object exists. The application code is complete and is not in question; what the cluster reports and what checkout actually experiences no longer agree. The expectations of the teams who depend on this service are listed under Objectives. Your job is to make the cluster meet every one of them. The cluster is a small single node with limited capacity, and both replicas are expected to fit on it.

# Objectives

- Checkout traffic must reach every intended inventory replica through the cluster Service.
- Reported health must match whether a replica can actually serve reservation requests.
- Both replicas must fit and run together on the single node.
- Fixes must come from the manifests alone; the application code is complete.

# Helpful Tips

- Start from what checkout actually experiences, then work back to what the platform claims.
- Take each objective as its own question and confirm it against the live cluster, not the manifests alone.
- When something looks fixed, re-check the whole picture; a change in one place often moves a problem elsewhere.
- Whatever you change should be checkable by hand afterwards, the same way the grading will check it.

# How to Verify

- Every intended replica is reachable through the cluster Service and answers a reservation health request.
- Reported health for each replica agrees with whether it actually answers.
- Both replicas are running together on the single node, with none left waiting.
- The workload stays stable once it has converged.
- The provided reproduction check fails on the starter and passes when the cluster is healthy.
