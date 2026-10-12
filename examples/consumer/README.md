# External consumer example

This executable imports only `001-Elsa/medseal/api/policy`. It does not import
any `src/` implementation package. The W6 verifier copies the published archive into a fresh
`.mooncakes/` directory, builds this consumer there, and then runs it after the
original checkout is outside the consumer's working directory.

```sh
moon run --target native examples/consumer
```

Policy compilation is a public API operation. It does not grant IOD, privacy,
pixel or release approval; those remain explicit MedSeal validation and review
gates.
