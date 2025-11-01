// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title StablecoinPayment
 * @notice Core contract for KeloPay stablecoin payment platform
 * @dev Implements payment processing, merchant management, and withdrawals
 */
contract StablecoinPayment is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // Constants
    uint256 public constant MIN_PAYMENT_AMOUNT = 1e6; // 1 USDT/USDC (6 decimals minimum)

    // Structs
    struct Merchant {
        address payoutWallet;
        bool isActive;
        uint256 registrationTime;
        uint256 totalRevenue;
    }

    struct Transaction {
        address payer;
        address merchant;
        address token;
        uint256 amount;
        string metadata;
        uint256 timestamp;
        bool exists;
    }

    // Custom Errors
    error InvalidTokenAddress();
    error InvalidAmount();
    error InvalidMerchant();
    error MerchantNotActive();
    error PaymentFailed();
    error WithdrawalFailed();
    error InsufficientBalance();
    error UnauthorizedAccess();
    error InvalidPayoutWallet();
    error EmptyBatch();

    // State Variables
    mapping(address => bool) public allowedTokens;
    mapping(address => Merchant) public merchants;
    mapping(address => mapping(address => uint256)) public merchantBalances; // merchant => token => balance
    mapping(address => Transaction[]) public userTransactions;
    mapping(address => Transaction[]) public merchantTransactions;
    Transaction[] public allTransactions;

    uint256 public totalTransactions;
    uint256 public totalMerchants;
    address[] public merchantList;

    // Events
    event PaymentProcessed(
        address indexed payer,
        address indexed merchant,
        address indexed token,
        uint256 amount,
        string metadata,
        uint256 timestamp
    );

    event MerchantRegistered(
        address indexed merchant,
        address indexed payoutWallet,
        uint256 timestamp
    );

    event MerchantActivated(
        address indexed merchant,
        uint256 timestamp
    );

    event MerchantSuspended(
        address indexed merchant,
        uint256 timestamp
    );

    event MerchantWalletUpdated(
        address indexed merchant,
        address indexed oldWallet,
        address indexed newWallet,
        uint256 timestamp
    );

    event Withdrawal(
        address indexed merchant,
        address indexed token,
        uint256 amount,
        uint256 timestamp
    );

    event BatchWithdrawal(
        address indexed merchant,
        address[] tokens,
        uint256[] amounts,
        uint256 timestamp
    );

    event TokenAdded(
        address indexed token,
        uint256 timestamp
    );

    event TokenRemoved(
        address indexed token,
        uint256 timestamp
    );

    event EmergencyWithdraw(
        address indexed token,
        uint256 amount,
        uint256 timestamp
    );

    /**
     * @notice Constructor
     * @param initialOwner The contract owner address
     */
    constructor(address initialOwner) Ownable(initialOwner) {
        // Initialize with common stablecoins
        // Note: In production, these addresses should be set via setAllowedTokens
    }

    // ============ MODIFIERS ============

    modifier onlyActiveMerchant(address merchant) {
        if (!merchants[merchant].isActive) revert MerchantNotActive();
        _;
    }

    modifier validToken(address token) {
        if (!allowedTokens[token]) revert InvalidTokenAddress();
        _;
    }

    modifier validAmount(uint256 amount) {
        if (amount < MIN_PAYMENT_AMOUNT) revert InvalidAmount();
        _;
    }

    modifier onlyMerchant() {
        if (!merchants[msg.sender].isActive) revert UnauthorizedAccess();
        _;
    }

    // ============ ADMIN FUNCTIONS ============

    /**
     * @notice Add a supported stablecoin token
     * @param token The ERC20 token address
     */
    function addAllowedToken(address token) external onlyOwner {
        if (token == address(0)) revert InvalidTokenAddress();
        if (allowedTokens[token]) revert InvalidTokenAddress();

        allowedTokens[token] = true;
        emit TokenAdded(token, block.timestamp);
    }

    /**
     * @notice Remove a supported stablecoin token
     * @param token The ERC20 token address
     */
    function removeAllowedToken(address token) external onlyOwner validToken(token) {
        allowedTokens[token] = false;
        emit TokenRemoved(token, block.timestamp);
    }

    /**
     * @notice Pause the contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Emergency withdraw funds (only for stuck tokens)
     * @param token The ERC20 token address
     * @param amount The amount to withdraw
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);
        emit EmergencyWithdraw(token, amount, block.timestamp);
    }

    // ============ MERCHANT FUNCTIONS ============

    /**
     * @notice Register as a merchant
     * @param payoutWallet The wallet address to receive payments
     */
    function registerMerchant(address payoutWallet) external whenNotPaused {
        if (payoutWallet == address(0)) revert InvalidPayoutWallet();
        if (merchants[msg.sender].payoutWallet != address(0)) revert InvalidMerchant();

        merchants[msg.sender] = Merchant({
            payoutWallet: payoutWallet,
            isActive: true,
            registrationTime: block.timestamp,
            totalRevenue: 0
        });

        merchantList.push(msg.sender);
        totalMerchants++;

        emit MerchantRegistered(msg.sender, payoutWallet, block.timestamp);
        emit MerchantActivated(msg.sender, block.timestamp);
    }

    /**
     * @notice Update merchant payout wallet
     * @param newPayoutWallet The new payout wallet address
     */
    function updatePayoutWallet(address newPayoutWallet) external onlyMerchant whenNotPaused {
        if (newPayoutWallet == address(0)) revert InvalidPayoutWallet();

        address oldWallet = merchants[msg.sender].payoutWallet;
        merchants[msg.sender].payoutWallet = newPayoutWallet;

        emit MerchantWalletUpdated(msg.sender, oldWallet, newPayoutWallet, block.timestamp);
    }

    /**
     * @notice Activate a merchant account
     * @param merchant The merchant address
     */
    function activateMerchant(address merchant) external onlyOwner {
        if (merchants[merchant].payoutWallet == address(0)) revert InvalidMerchant();
        if (merchants[merchant].isActive) revert InvalidMerchant();

        merchants[merchant].isActive = true;
        emit MerchantActivated(merchant, block.timestamp);
    }

    /**
     * @notice Suspend a merchant account
     * @param merchant The merchant address
     */
    function suspendMerchant(address merchant) external onlyOwner {
        if (merchants[merchant].payoutWallet == address(0)) revert InvalidMerchant();
        if (!merchants[merchant].isActive) revert InvalidMerchant();

        merchants[merchant].isActive = false;
        emit MerchantSuspended(merchant, block.timestamp);
    }

    // ============ PAYMENT FUNCTIONS ============

    /**
     * @notice Process a payment from user to merchant
     * @param merchant The merchant address
     * @param token The ERC20 token address
     * @param amount The payment amount
     * @param metadata Optional metadata string (invoice ID, order reference, etc.)
     */
    function processPayment(
        address merchant,
        address token,
        uint256 amount,
        string calldata metadata
    ) external validToken(token) validAmount(amount) onlyActiveMerchant(merchant) nonReentrant whenNotPaused {
        // Transfer tokens from user to contract
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // Update merchant balance
        merchantBalances[merchant][token] += amount;

        // Update merchant total revenue
        merchants[merchant].totalRevenue += amount;

        // Create transaction record
        Transaction memory newTx = Transaction({
            payer: msg.sender,
            merchant: merchant,
            token: token,
            amount: amount,
            metadata: metadata,
            timestamp: block.timestamp,
            exists: true
        });

        // Store transaction
        userTransactions[msg.sender].push(newTx);
        merchantTransactions[merchant].push(newTx);
        allTransactions.push(newTx);
        totalTransactions++;

        emit PaymentProcessed(msg.sender, merchant, token, amount, metadata, block.timestamp);
    }

    // ============ WITHDRAWAL FUNCTIONS ============

    /**
     * @notice Withdraw merchant balance for a specific token
     * @param token The ERC20 token address
     * @param amount The amount to withdraw
     */
    function withdraw(address token, uint256 amount) external onlyMerchant nonReentrant whenNotPaused {
        if (amount == 0) revert InvalidAmount();
        if (merchantBalances[msg.sender][token] < amount) revert InsufficientBalance();

        // Update balance
        merchantBalances[msg.sender][token] -= amount;

        // Transfer to merchant's payout wallet
        address payoutWallet = merchants[msg.sender].payoutWallet;
        IERC20(token).safeTransfer(payoutWallet, amount);

        emit Withdrawal(msg.sender, token, amount, block.timestamp);
    }

    /**
     * @notice Withdraw entire balance for a specific token
     * @param token The ERC20 token address
     */
    function withdrawAll(address token) external onlyMerchant nonReentrant whenNotPaused {
        uint256 balance = merchantBalances[msg.sender][token];
        if (balance == 0) revert InsufficientBalance();

        // Update balance
        merchantBalances[msg.sender][token] = 0;

        // Transfer to merchant's payout wallet
        address payoutWallet = merchants[msg.sender].payoutWallet;
        IERC20(token).safeTransfer(payoutWallet, balance);

        emit Withdrawal(msg.sender, token, balance, block.timestamp);
    }

    /**
     * @notice Batch withdraw multiple tokens
     * @param tokens Array of token addresses
     * @param amounts Array of amounts to withdraw
     */
    function batchWithdraw(address[] calldata tokens, uint256[] calldata amounts) external onlyMerchant nonReentrant whenNotPaused {
        if (tokens.length == 0) revert EmptyBatch();
        if (tokens.length != amounts.length) revert InvalidAmount();

        address payoutWallet = merchants[msg.sender].payoutWallet;
        uint256[] memory actualAmounts = new uint256[](tokens.length);

        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 balance = merchantBalances[msg.sender][tokens[i]];
            uint256 withdrawalAmount = amounts[i];

            if (withdrawalAmount == 0) {
                withdrawalAmount = balance; // Withdraw all if 0 amount specified
            }

            if (balance < withdrawalAmount) revert InsufficientBalance();
            if (balance == 0) continue; // Skip tokens with zero balance

            merchantBalances[msg.sender][tokens[i]] -= withdrawalAmount;
            IERC20(tokens[i]).safeTransfer(payoutWallet, withdrawalAmount);
            actualAmounts[i] = withdrawalAmount;
        }

        emit BatchWithdrawal(msg.sender, tokens, actualAmounts, block.timestamp);
    }

    // ============ VIEW FUNCTIONS ============

    /**
     * @notice Get merchant details
     * @param merchant The merchant address
     * @return Merchant details struct
     */
    function getMerchant(address merchant) external view returns (Merchant memory) {
        return merchants[merchant];
    }

    /**
     * @notice Get merchant balance for a specific token
     * @param merchant The merchant address
     * @param token The ERC20 token address
     * @return balance The merchant's balance
     */
    function getMerchantBalance(address merchant, address token) external view returns (uint256) {
        return merchantBalances[merchant][token];
    }

    /**
     * @notice Get all transactions for a user
     * @param user The user address
     * @return Array of transactions
     */
    function getUserTransactions(address user) external view returns (Transaction[] memory) {
        return userTransactions[user];
    }

    /**
     * @notice Get all transactions for a merchant
     * @param merchant The merchant address
     * @return Array of transactions
     */
    function getMerchantTransactions(address merchant) external view returns (Transaction[] memory) {
        return merchantTransactions[merchant];
    }

    /**
     * @notice Get all transactions (paginated)
     * @param startIndex Starting index
     * @param endIndex Ending index (exclusive)
     * @return Array of transactions
     */
    function getAllTransactions(uint256 startIndex, uint256 endIndex) external view returns (Transaction[] memory) {
        if (endIndex > allTransactions.length) {
            endIndex = allTransactions.length;
        }
        if (startIndex >= endIndex) {
            return new Transaction[](0);
        }

        uint256 length = endIndex - startIndex;
        Transaction[] memory result = new Transaction[](length);

        for (uint256 i = 0; i < length; i++) {
            result[i] = allTransactions[startIndex + i];
        }

        return result;
    }

    /**
     * @notice Get total number of transactions
     * @return Total transaction count
     */
    function getTotalTransactions() external view returns (uint256) {
        return totalTransactions;
    }

    /**
     * @notice Get all registered merchants
     * @return Array of merchant addresses
     */
    function getAllMerchants() external view returns (address[] memory) {
        return merchantList;
    }

    /**
     * @notice Check if a token is allowed
     * @param token The ERC20 token address
     * @return Whether the token is allowed
     */
    function isTokenAllowed(address token) external view returns (bool) {
        return allowedTokens[token];
    }

    /**
     * @notice Get total merchants count
     * @return Total merchant count
     */
    function getTotalMerchants() external view returns (uint256) {
        return totalMerchants;
    }
}

