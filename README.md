# KeloPay Smart Contract

**Stablecoin Payment Platform Smart Contract**

A comprehensive Solidity smart contract that serves as the core of the KeloPay stablecoin payment platform, enabling seamless, secure, and transparent payment operations using supported stablecoins (USDT, USDC, DAI, etc.).

## 🌟 Features

### ✅ Core Functionalities Implemented

- **Stablecoin Integration**
  - Support for multiple ERC-20 stablecoins
  - Token validation before accepting payments
  - SafeERC20 for secure transfers
  
- **User Payments**
  - Process payments from users to merchants
  - Comprehensive event logging
  - Optional metadata support (invoice ID, order reference)
  
- **Merchant Registration**
  - Self-registration for merchants
  - Admin approval/suspension control
  - Flexible payout wallet management
  
- **Transaction Logging**
  - On-chain transaction storage
  - Payment history retrieval per user/merchant
  - Paginated transaction queries
  
- **Withdrawals**
  - Single token withdrawals
  - Batch withdrawals
  - Withdraw all functionality
  
- **Access Control**
  - Ownable for admin privileges
  - Merchant-only functions
  - Authorization checks
  
- **Security Features**
  - ReentrancyGuard protection
  - Input validation
  - Emergency pause functionality
  - Transfer validation

### 🔒 Security

- ✅ **ReentrancyGuard** - All external state-changing functions protected
- ✅ **Ownable** - Admin-only functions secured
- ✅ **Pausable** - Emergency stop capability
- ✅ **SafeERC20** - Safe token transfers
- ✅ **Input Validation** - All parameters validated
- ✅ **Custom Errors** - Gas-efficient error handling
- ✅ **Checks-Effects-Interactions** - Proper function structure

## 📋 Events

All events are properly indexed for efficient filtering:

```solidity
event PaymentProcessed(address indexed payer, address indexed merchant, address indexed token, uint256 amount, string metadata, uint256 timestamp);
event MerchantRegistered(address indexed merchant, address indexed payoutWallet, uint256 timestamp);
event MerchantActivated(address indexed merchant, uint256 timestamp);
event MerchantSuspended(address indexed merchant, uint256 timestamp);
event MerchantWalletUpdated(address indexed merchant, address indexed oldWallet, address indexed newWallet, uint256 timestamp);
event Withdrawal(address indexed merchant, address indexed token, uint256 amount, uint256 timestamp);
event BatchWithdrawal(address indexed merchant, address[] tokens, uint256[] amounts, uint256 timestamp);
event TokenAdded(address indexed token, uint256 timestamp);
event TokenRemoved(address indexed token, uint256 timestamp);
event EmergencyWithdraw(address indexed token, uint256 amount, uint256 timestamp);
```

## 🚀 Quick Start

### Installation

```bash
npm install
```

### Compilation

```bash
npx hardhat compile
```

### Deploy

```bash
npx hardhat run scripts/deploy.ts
```

## 📖 Usage

### Merchant Registration

```solidity
// Register as a merchant
stablecoinPayment.registerMerchant(payoutWalletAddress);

// Update payout wallet
stablecoinPayment.updatePayoutWallet(newPayoutWallet);
```

### Token Management (Admin)

```solidity
// Add a supported token
stablecoinPayment.addAllowedToken(tokenAddress);

// Remove a token
stablecoinPayment.removeAllowedToken(tokenAddress);
```

### Payment Processing

```solidity
// User makes a payment to a merchant
stablecoinPayment.processPayment(
    merchantAddress,
    tokenAddress,
    amount,
    "Invoice #12345" // optional metadata
);
```

### Withdrawals

```solidity
// Merchant withdraws specific amount
stablecoinPayment.withdraw(tokenAddress, amount);

// Withdraw all balance
stablecoinPayment.withdrawAll(tokenAddress);

// Batch withdraw multiple tokens
stablecoinPayment.batchWithdraw([token1, token2], [amount1, amount2]);
```

### View Functions

```solidity
// Get merchant info
stablecoinPayment.getMerchant(merchantAddress);

// Get merchant balance
stablecoinPayment.getMerchantBalance(merchantAddress, tokenAddress);

// Get user transactions
stablecoinPayment.getUserTransactions(userAddress);

// Get merchant transactions
stablecoinPayment.getMerchantTransactions(merchantAddress);

// Get all transactions (paginated)
stablecoinPayment.getAllTransactions(startIndex, endIndex);
```

## 🛠️ Architecture

### Contract Structure

```
StablecoinPayment
├── Ownable (OpenZeppelin)
├── ReentrancyGuard (OpenZeppelin)
└── Pausable (OpenZeppelin)
```

### State Variables

- `allowedTokens` - Mapping of supported ERC20 tokens
- `merchants` - Merchant information storage
- `merchantBalances` - Token balances per merchant
- `userTransactions` - Transaction history per user
- `merchantTransactions` - Transaction history per merchant
- `allTransactions` - Global transaction log

## 🔐 Security Considerations

### Reentrancy Protection
- All withdrawal and payment functions use `nonReentrant` modifier
- Checks-Effects-Interactions pattern enforced

### Access Control
- Owner-only: `addAllowedToken`, `removeAllowedToken`, `pause`, `unpause`, `suspendMerchant`, `activateMerchant`, `emergencyWithdraw`
- Merchant-only: `withdraw`, `withdrawAll`, `batchWithdraw`, `updatePayoutWallet`

### Input Validation
- Token addresses validated (non-zero)
- Amounts checked (minimum payment amount)
- Merchant status verified (active)
- Metadata optional (can be empty string)

### Emergency Controls
- Contract can be paused by owner
- Emergency withdrawal for stuck tokens
- Merchant suspension capability

## 📊 Features Summary

| Feature | Status |
|---------|--------|
| Multi-token support | ✅ |
| Merchant self-registration | ✅ |
| Admin merchant control | ✅ |
| Payment processing | ✅ |
| Transaction history | ✅ |
| Withdrawal system | ✅ |
| Batch withdrawals | ✅ |
| Reentrancy protection | ✅ |
| Emergency pause | ✅ |
| Access control | ✅ |
| Event emissions | ✅ |
| Gas optimization | ✅ |

## 🌐 Supported Networks

The contract is compatible with all EVM chains that support Solidity 0.8.28+.

## 📝 Contract Details

- **Solidity Version:** 0.8.28
- **License:** MIT
- **Compiler:** solc with optimizer enabled (200 runs)
- **Libraries:** OpenZeppelin Contracts v5.4.0

## 🔗 References

- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [ERC-20 Token Standard](https://eips.ethereum.org/EIPS/eip-20)
- [SafeERC20](https://docs.openzeppelin.com/contracts/3.x/api/token/erc20#SafeERC20)

## 📄 License

MIT License

---

**KeloPay - Bridging Crypto to Real-World Payments**
