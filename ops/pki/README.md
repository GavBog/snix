# //ops/pki

This contains a PKI, created using minica.

We use it to secure some connections via mTLS.

It was created by invoking `minica -domains 'build03.infra.snix.dev'`.

This created the following structure:

```
.
├── build03.infra.snix.dev
│   ├── cert.pem
│   └── key.pem
├── minica-key.pem
└── minica.pem
```

To prevent from accidentially committing secrets into the repository, we
`.gitignore` all `key.pem` files, as well as the `minica-key.pem` file.

## Renewing / Issuing certs

When creating a new cert, the idea is to decrypt the `minica-key.pem` file
locally, run `minica -domains 'your-domain-here'`, and then delete
`minica-key.pem` again.

The `*/cert.pem` file can be committed, or ideally a version of it
piped through `openssl x509 -text < ./your-domain-here/cert.pem`.

The `*/key.pem` only get saved and persisted to the target machine via the
existing `ops/secrets` mechanism.

Certs are valid for 2 years after creation.

This is only a stopgap solution, we probably want to use smallstep or some other
"proper CA" once we add other services to it.
