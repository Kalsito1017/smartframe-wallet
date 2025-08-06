# smartframe-wallet

**Modular Account Abstraction Wallet Framework**  
Built on top of ERC-4337 and designed for fully programmable user accounts.

---

## 🔍 Overview

`smartframe-wallet` is a lightweight, extensible smart contract wallet architecture implementing **Account Abstraction (ERC-4337)**. It allows users and developers to create custom wallet logic with modular components such as:

- Custom validation (signers, social recovery, passkeys, etc.)
- Gas sponsorship (Paymasters)
- Plugin execution
- Session keys & automation

---

## 🛠️ Tech Stack

- **Solidity 0.8.x**
- **ERC-4337** compliant contracts via [`eth-infinitism/account-abstraction@v0.7.0`](https://github.com/eth-infinitism/account-abstraction)
- **Foundry** for development and testing
- **TypeScript** scripts for deployment and automation
- **OpenZeppelin Contracts** for battle-tested Solidity components
- **zkSync Contracts** (via `foundry-era-contracts`) for zk-rollup compatibility
- **forge-std** for testing utilities
- **foundry-devops** for deployment scripting
- **Use** --system-mode = true and via-ir = true

---

## ✨ Features

- ✅ ERC-4337 compatible
- 🔌 Modular plugin architecture
- 🔐 Custom signature schemes
- ⛽ Native Paymaster support
- 🧩 Easily extendable via hooks and session logic
- 🌀 zkSync & L2 compatibility

---

## 📁 Folder Structure

lib/
├── account-abstraction # ERC-4337 contracts (v0.7.0)
----
├── forge-std # Foundry standard library
----
├── foundry-devops # Deployment scripting toolkit
----
├── foundry-era-contracts # zkSync-compatible contracts
----
└── openzeppelin-contracts # OpenZeppelin contract library

scripts/
├── DeployZkMinimal.ts # zkSync minimal deployment script
----
├── EncryptKey.ts # Encryption utility
----
└── SendAATx.ts # Send Account Abstraction transaction script


---

## 🧪 Getting Started

1. **Install dependencies:**

   ```bash
   rm -rf lib/account-abstraction
   forge install eth-infinitism/account-abstraction@v0.7.0
   forge install foundry-rs/forge-std
   forge install openzeppelin/openzeppelin-contracts
   forge install zksync-era/foundry-era-contracts
   forge install jonasschmedtmann/foundry-devops

⚠️ Disclaimer
This codebase is for educational purposes only and has not undergone a formal security audit. Use at your own risk.
