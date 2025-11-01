// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ReentrancyAttacker
 * @notice Contract to test reentrancy protection
 * @dev DO NOT USE IN PRODUCTION - This is for testing only
 */
contract ReentrancyAttacker {
    address public target;
    address public token;
    address public merchant;
    uint256 public attackAttempts;

    constructor(address _target, address _token, address _merchant) {
        target = _target;
        token = _token;
        merchant = _merchant;
    }

    function attack(uint256 /* amount */) external {
        attackAttempts++;
        IERC20(token).approve(target, type(uint256).max);
        
        // This would try to reenter during withdrawal
        // But the actual attack logic is simplified here
        // Real attack would call back into withdraw during processPayment
    }
}

