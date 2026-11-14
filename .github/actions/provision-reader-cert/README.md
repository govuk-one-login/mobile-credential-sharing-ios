# Provision reader authentication certificate

> [!WARNING]
> This composite step provisions private key material into the **test verifier** app, which is for **non-production / internal use only**. Separate teams build and maintain the production verifier apps that consume this SDK. Never use this step, or the app it provisions, in production.

This composite step provisions a short-lived Digital Verification Service (DVS) L4 reader-auth leaf certificate for the test verifier and writes it into the app's bundled files.

## Flow

1. Generate an EC key pair and a public-key certificate signing request (CSR), in Public-Key Cryptography Standards (PKCS) #10 format, with openssl.
2. Assume an AWS role using the workflow's GitHub OpenID Connect (OIDC) token (`aws-actions/configure-aws-credentials`).
3. Send the CSR to the L3 CA `POST /issue-reader-cert` endpoint. `curl` signs the request with AWS SigV4 using the assumed credentials.
4. Convert the issued leaf-first PEM chain to a concatenated DER chain, then write it and the generated leaf private key into the environment's files, and remove the working directory.

The workflow only ever bundles the L4 leaf private key. The endpoint never exposes the CA private keys.

## Inputs

| Input          | Required | Default                                                            | Description                                              |
| -------------- | -------- | ------------------------------------------------------------------ | -------------------------------------------------------- |
| `environment`  | yes      |                                                                    | `dev` or `integration`.                                  |
| `endpoint-url` | yes      |                                                                    | Base URL of the issuance API (no trailing slash).        |
| `aws-role-arn` | yes      |                                                                    | Amazon Resource Name (ARN) of the AWS role to assume.    |
| `aws-region`   | no       | `eu-west-2`                                                        | AWS region hosting the endpoint.                         |
| `assets-dir`   | no       | `mobile-credential-sharing-ios/mobile-credential-sharing-ios/ReaderAuthProfiles` | Directory holding the bundled reader-auth files. |
| `subject`      | no       | GDS distinguished name                                             | Subject for the CSR.                                     |
| `ec-curve`     | no       | `prime256v1`                                                       | Named curve for the generated key pair.                  |

The calling job must grant `id-token: write` so that GitHub can mint the OIDC token.

The generated leaf key uses `prime256v1` (P-256) to match the app's `ReaderAuthSigningMaterial`, which signs ReaderAuth with an ES256 (P-256) key.

## Written files

For a given `environment`, this step overwrites the committed placeholders:

```
reader_dvs_<environment>_chain.der       # issued chain, leaf first, concatenated DER
reader_dvs_<environment>_leaf_key.pem    # generated leaf private key
```

The issued chain is returned as leaf-first PEM; this step converts every certificate in it to DER and concatenates them (leaf first) because the app parses a concatenated DER chain.

## Certificate lifecycle

The issued leaf is short-lived, with 90 day validity that matches the DVS issuance flow. Treat provisioned app builds as deprecated once the leaf expires, and re-provision them by re-running the pipeline.

This step fails closed if the endpoint returns a non-200 response, an empty chain, or a leaf that has already expired. A build therefore can't ship with unusable material.

## Example

```yaml
- name: Provision reader certificate
  uses: ./.github/actions/provision-reader-cert
  with:
    environment: integration
    endpoint-url: ${{ vars.READER_CERT_INTEGRATION_ENDPOINT_URL }}
    aws-role-arn: ${{ vars.READER_CERT_INTEGRATION_ROLE_ARN }}
```
