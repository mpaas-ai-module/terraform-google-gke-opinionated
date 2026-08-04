# terraform-google-gke-opinionated [![Latest Release](https://img.shields.io/github/release/bootlabstech/terraform-google-gke-opinionated.svg)](https://github.com/bootlabstech/terraform-google-gke-opinionated/releases/latest)

[![Bootlabstech][logo]](https://www.bootlabs.in)

[logo]: https://www.bootlabs.in/wp-content/uploads/2020/09/logo.png
## v1.0.2 — project IAM bindings are now additive members

This module granted roles/cloudkms.cryptoKeyEncrypterDecrypter, roles/container.admin with **authoritative**
`google_project_iam_binding` resources. An authoritative binding does not add
members — it *replaces* the entire member list for that role across the whole
project, so every other holder of the role was silently revoked on apply.

Because several GCP modules in this org write
`roles/cloudkms.cryptoKeyEncrypterDecrypter` at project level, any two of them in
one project overwrote each other and settled on whichever applied last — and
`lifecycle { ignore_changes = [members] }` hid the resulting drift from later
plans, which is why this was never visible.

These are now additive `google_project_iam_member` resources. Same grants, same
scope, no clobbering.

### Upgrading an already-provisioned project

Terraform will **delete** the removed binding, which empties that role at project
level. Abandon it instead, before the first apply on this version:

```sh
terraform state rm 'module.<label>.google_project_iam_binding.network_binding7'
terraform state rm 'module.<label>.google_project_iam_binding.containerAdmin'
```

New projects need no such step.
