// SPDX-License-Identifier: MIT

// OUTSIDE CONTRACTS,LIBRARIES or INTERFACES
// Pragma statements
// Import statements
// Events
// Errors
// Interfaces
// Libraries
// Contracts

// INSIDE CONTRACTS,LIBRARIES or INTERFACES
// Type declarations
// State variables (#1:Constants, #2:Immutables, #3:Storage)
// Events
// Errors
// Modifiers
// Functions

// FUNCTION'S ORDER
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.20;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title JuliansStableCoin
 * @author Julian Cabrera
 * @dev This contract is a decentralized stable coin
 * Relative Stability: pegged/anchored to USD
 * Stability Method: algorithmic
 * Collateral Type: wETH & wBTC
 *
 * This contract will be goberned by DSCEngine contract. This contract is just the ERC20 implementation of our stablecoin.
 */
contract JuliansStableCoin is ERC20Burnable, Ownable {
    error JuliansStableCoin__AmountZeroNotAllowed();
    error JuliansStableCoin__BurnAmountExceedsbalance();
    error JuliansStableCoin__AddressZeroNotAllowed();

    constructor() ERC20("JuliansStableCoin", "DSC") Ownable(msg.sender) {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert JuliansStableCoin__AmountZeroNotAllowed();
        }
        if (balance < _amount) {
            revert JuliansStableCoin__BurnAmountExceedsbalance();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert JuliansStableCoin__AddressZeroNotAllowed();
        }
        if (_amount <= 0) {
            revert JuliansStableCoin__AmountZeroNotAllowed();
        }
        _mint(_to, _amount);
        return true;
    }
}
