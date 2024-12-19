# Smoo.th Smart Contracts

[![Open in Github][github-editor-badge]][github-editor-url] [![Github Actions][gha-quality-badge]][gha-quality-url]
[![Github Actions][gha-test-badge]][gha-test-url]
[![Github Actions][gha-static-analysis-badge]][gha-static-analysis-url]
[![Github Actions][gha-release-badge]][gha-release-url] [![Foundry][foundry-badge]][foundry]
[![License: MIT][license-badge]][license]

[github-editor-url]: https://github.dev/get-smooth/smart-contracts/tree/main
[github-editor-badge]: https://img.shields.io/badge/Github-Open%20the%20Editor-purple?logo=github
[gha-quality-url]: https://github.com/get-smooth/smart-contracts/actions/workflows/quality-checks.yml
[gha-quality-badge]: https://github.com/get-smooth/smart-contracts/actions/workflows/quality-checks.yml/badge.svg?branch=main
[gha-test-url]: https://github.com/get-smooth/smart-contracts/actions/workflows/tests.yml
[gha-test-badge]: https://github.com/get-smooth/smart-contracts/actions/workflows/tests.yml/badge.svg?branch=main
[gha-static-analysis-url]: https://github.com/get-smooth/smart-contracts/actions/workflows/static-analysis.yml
[gha-static-analysis-badge]: https://github.com/get-smooth/template-foundry/actions/workflows/static-analysis.yml/badge.svg?branch=main
[gha-release-url]: https://github.com/get-smooth/smart-contracts/actions/workflows/release-package.yml
[gha-release-badge]: https://github.com/get-smooth/smart-contracts/actions/workflows/release-package.yml/badge.svg
[foundry]: https://book.getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg
[license]: ./LICENSE.md
[license-badge]: https://img.shields.io/badge/License-MIT-blue.svg

## Description

This repository contains the smart contracts used by [Smoo.th](https://github.com/get-smooth). Smoo.th makes accessing the blockchain as seamless as using Apple Pay or PayPal. By removing the need for browser extensions or hardware wallets, it enables users to interact with decentralized ecosystems effortlessly through a single click or biometric confirmation. Leveraging advancements in passkeys and account abstraction, Smoo.th bridges Web2 and Web3, empowering individuals and businesses to embrace blockchain without complexity.

> 🚨 None of the implementations have been audited. DO NOT USE THEM IN PRODUCTION.

## Installation

1. Install Foundry:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. Clone the repository:

```bash
git clone https://github.com/get-smooth/smart-contracts
cd smart-contracts
```

3. Install dependencies:

```bash
forge install
```

4. Build the project:

```bash
forge build
```

5. Run tests:

```bash
forge test
```

The repository is fully tested across 35+ test suites and 180+ unit tests. However the repository is not audited yet, use at your own risks.

## Smart Contracts (v1)

### Account
- **[SmartAccount.sol](./src/v1/Account/SmartAccount.sol)**: Core account implementation with versioning that supports generic interactions. This contract can be controlled by one or multiple passkey signers and is ERC-4337 compliant. The implementation is deployed once per network, with users controlling dedicated proxies that target this implementation contract.
- **[SmartAccountEIP1271.sol](./src/v1/Account/SmartAccountEIP1271.sol)**: Implementation of EIP-1271 standard for smart contract signature validation, enabling the account to verify signatures for external protocols and dApps.
- **[SmartAccountTokensSupport.sol](./src/v1/Account/SmartAccountTokensSupport.sol)**: Implementation of ERC721 and ERC1155 receiver interfaces (ERC721Receiver, ERC1155Receiver), allowing the smart account to safely receive and manage NFTs and multi-tokens.

### Factory
- **[AccountFactory.sol](./src/v1/AccountFactory.sol)**: ERC-4337-compliant factory contract for deploying user proxies that target the smart account implementation. The proxy deployments are deterministic, computed using the passkey's public key and credential ID. This ensures users get the same account address across all EVM-compatible networks. The factory contract is versioned and upgradeable.

### Utils
- **[SignerVaultWebAuthnP256R1.sol](./src/utils/SignerVaultWebAuthnP256R1.sol)**: Library for storing and retrieving Passkeys signers using the p256r1 curve. Uses a custom storage layout to avoid collisions with other contracts.
- **[SignerVaultVanillaP256K1.sol](./src/utils/SignerVaultVanillaP256K1.sol)**: The same as *SignerVaultWebAuthnP256R1.sol* but for native ETH signers using the p256k1 curve. This library allows the support of a different type of signer post-onboarding.
- **[Signature.sol](./src/utils/Signature.sol)**: Library containing signature types and utilities for signature handling.
- **[StorageSlotRegistry.sol](./src/utils/StorageSlotRegistry.sol)**: Registry of storage slots used across the protocol to avoid storage collisions between different components

## Scripts

The `script/` directory contains deployment and interaction scripts for the smart contracts. The directory provides everything needed to deploy the entire protocol or interact with its components individually.

## Gas Reports

Edge and failure cases are currently included in the snapshots, which explains certain maximum values in the reports.

### SmartAccount Contract
| Function Name | min | avg | median | max | # calls |
|--------------|-----|-----|--------|-----|---------|
| addWebAuthnP256R1Signer | 574 | 1,152 | 574 | 73,120 | 259 |
| entryPoint | 268 | 268 | 268 | 268 | 518 |
| execute | 736 | 6,206 | 736 | 83,584 | 294 |
| executeBatch | 23,089 | 33,704 | 27,433 | 56,171 | 8 |
| factory | 351 | 1,017 | 351 | 2,351 | 3 |
| getNonce | 1,084 | 3,334 | 3,334 | 5,584 | 2 |
| getSigner | 1,472 | 3,872 | 1,472 | 7,472 | 10 |
| initialize | 2,888 | 108,624 | 116,829 | 116,829 | 46 |
| isValidSignature | 682 | 52,001 | 5,208 | 286,606 | 12 |
| receive | 0 | 20,263 | 21,055 | 21,055 | 266 |
| removeWebAuthnP256R1Signer | 366 | 509 | 366 | 18,866 | 258 |
| upgradeToAndCall | 8,711 | 10,985 | 8,711 | 16,219 | 8 |
| version | 237 | 237 | 237 | 237 | 2 |
| webAuthnVerifier | 236 | 236 | 236 | 236 | 256 |

One Time Deployment Cost/Size: 2,642,889 gas / 12,451 bytes

### AccountFactory Contract
| Function Name | min | avg | median | max | # calls |
|--------------|-----|-----|--------|-----|---------|
| accountImplementation | 194 | 194 | 194 | 194 | 2 |
| createAndInitAccount | 36,839 | 67,679 | 39,915 | 251,953 | 296 |
| getAddress | 7,965 | 7,965 | 7,965 | 7,965 | 295 |
| owner | 190 | 190 | 190 | 190 | 1 |
| version | 200 | 200 | 200 | 200 | 2 |

One Time Deployment Cost/Size: 1,127,454 gas / 5,329 bytes

### Paymaster Contract
| Function Name | min | avg | median | max | # calls |
|--------------|-----|-----|--------|-----|---------|
| deposit | 53,349 | 53,349 | 53,349 | 53,349 | 1,028 |
| entryPoint | 249 | 249 | 249 | 249 | 1 |
| getDeposit | 1,067 | 1,084 | 1,067 | 5,567 | 258 |
| operator | 336 | 2,320 | 2,336 | 2,336 | 259 |
| owner | 374 | 1,574 | 2,374 | 2,374 | 5 |
| postOp | 22,227 | 22,802 | 22,419 | 24,075 | 512 |
| renounceOwnership | 23,208 | 23,334 | 23,334 | 23,460 | 2 |
| transferOperator | 25,875 | 26,131 | 26,110 | 29,122 | 259 |
| transferOwnership | 23,989 | 26,275 | 26,275 | 28,562 | 2 |
| validatePaymasterUserOp | 25,901 | 33,123 | 34,829 | 34,856 | 11 |
| version | 260 | 260 | 260 | 260 | 2 |
| withdrawTo(address,uint256) | 23,962 | 36,874 | 24,190 | 62,571 | 770 |
| withdrawTo(uint256) | 64,146 | 64,146 | 64,146 | 64,146 | 1 |

One Time Deployment Cost/Size: 1,187,147 gas / 5,587 bytes

### SignerVaultWrapper Contract
| Function Name | min | avg | median | max | # calls |
|--------------|-----|-----|--------|-----|---------|
| getWebauthnP256R1StartingSlot(address) | 953 | 953 | 953 | 953 | 256 |
| getWebauthnP256R1StartingSlot(bytes32) | 935 | 935 | 935 | 935 | 256 |
| vanillaP256K1Root | 667 | 667 | 667 | 667 | 1 |
| webAuthnP256R1Root | 601 | 601 | 601 | 601 | 1 |

One Time Deployment Cost/Size: 260,398 gas / 994 bytes

## Dependencies

### External

External key dependencies (in `lib/` directory) include:
- forge-std: Foundry's standard library
- openzeppelin-contracts: OpenZeppelin contract implementations
- account-abstraction: ERC-4337 entrypoint implementation from [eth-infinitism](https://github.com/eth-infinitism/account-abstraction)

### Internal

Smoo.th's dependencies (in `lib/` directory) include:
- [webauthn](https://github.com/get-smooth/webauthn): Our library that verifies passkey/webauthn payload
- [secp256r1-verify](https://github.com/get-smooth/secp256r1-verify): Our solidity library to verify a secp256r1 signature in several ways


## Contributing

Contributions are welcome! Please check out our [Contributing Guidelines](CONTRIBUTING.md) for details.

## License

See the [LICENSE](LICENSE.md) file for details.
