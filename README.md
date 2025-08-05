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
- **ERC-4337** compliant interfaces
- **Foundry** or Hardhat for testing/deployment
- **Optional Bundler integration**
- (Optional) **AA SDK** support (e.g., eth-infinitism, Biconomy SDK)

---

## ✨ Features

- ✅ ERC-4337 compatible
- 🔌 Modular plugin architecture
- 🔐 Custom signature schemes
- ⛽ Native Paymaster support
- 🧩 Easily extendable via hooks

## Disclaimer

This codebase is for educational purposes only and has not undergone a security review.

##You need to:

run rm -rf lib/account-abstraction (if you installed it without specifying a version, or if you did write your version), then run forge install eth-infinitism/account-abstraction@v0.7.0
