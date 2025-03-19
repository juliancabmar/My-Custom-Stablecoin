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

/**
 * @title JSCEngine
 * @author Julian Cabrera
 *
 * Is a minimalistic systen whose token maintain 1 token = $1 USD.
 * The stablecoin properties are:
 * - Dollar anchored/pegged
 * - Exogenous collateral (wETH, wBTC)
 * - Algorithmical based stability
 *
 * @notice This contract is the core of the JSC system
 * @notice The collateral allways will be > than the JSC minted (in equivalent USD)
 * @notice for simplicity, the system not contemplate the use of any "stability ratio" over the position mantain, and
 * the use of the "penalty" for the liquidation process.
 */

//// Imports

import {JuliansStableCoin} from "src/JuliansStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract JSCEngine is ReentrancyGuard {
    //// State variables

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address tokenAddress => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountOfJscMinted) private s_jscMinted;

    JuliansStableCoin private immutable i_jsc;

    //// Events

    event CollateralDeposited(address indexed user, address indexed tokenAddress, uint256 indexed amount);

    //// Errors

    error JSCEngine__NeedsMoreThanZero(); 
    error JSCEngine__TokenAddressesAndPriceFeedsAddressesMustBeSameLength();
    error JSCEngine__InvalidTokenAddress();
    error JSCEngine__TransferFailed();

    //// Modifiers

    modifier moreThanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert JSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address _token) {
        if (s_priceFeeds[_token] == address(0)) {
            revert JSCEngine__InvalidTokenAddress();
        }
        _;
    }

    //// Functions

    constructor(address[] memory _tokenAddresses, address[] memory _priceFeedsAddresses, address _jscAddress) {
        if (_tokenAddresses.length != _priceFeedsAddresses.length) {
            revert JSCEngine__TokenAddressesAndPriceFeedsAddressesMustBeSameLength();
        }
        for (uint256 i = 0; i < _tokenAddresses.length; i++) {
            s_priceFeeds[_tokenAddresses[i]] = _priceFeedsAddresses[i];
        }
        i_jsc = JuliansStableCoin(_jscAddress);
    }

    function depositCollateralAndMintJsc() external {}

    function redeemCollateralFromJsc() external {}

    function burnJsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view {} // get the "collateralization ratio" in MakerDAO
    
    /**
     * 
     * @param _amountJscToMint: the amount of JSC to mint
     * @notice they must have more collateral than the minimum threshold required
     */
    function mintJsc(uint256 _amountJscToMint) external moreThanZero(_amountJscToMint) {
        s_jscMinted[msg.sender] += _amountJscToMint;
        // revertIfHealthFactorIsBroken();
    }

    function _userHealthFactor(address _user) private view returns (uint256){
        (uint256 totalJscMinted, uint256 totalCollateralValueInUsd) = _getAccountInformation(_user);
    }

    function _getAccountInformation(address _user) private view returns (uint256 totalJscMinted, uint256 totalCollateralValueInUsd) {
        totalJscMinted = s_jscMinted[_user];
        totalCollateralValueInUsd = _getCollateralValueInUsd(_user);
        
    }

    function _getCollateralValue(address _user) public view returns (uint256 value) {
        
    }

    function revertIfHealthFactorIsBroken(address _user) internal view {}

    function redeemCollateral() internal {}

    /**
     *
     * @param _tokenForCollateralAddress: the address of the token to deposit as collateral
     * @param _amountOfCollateral: the amount of tokens depositated as collateral
     */
    function depositCollateral(address _tokenForCollateralAddress, uint256 _amountOfCollateral)
        internal
        moreThanZero(_amountOfCollateral)
        isAllowedToken(_tokenForCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][_tokenForCollateralAddress] += _amountOfCollateral;
        emit CollateralDeposited(msg.sender, _tokenForCollateralAddress, _amountOfCollateral);
        bool success = ERC20(_tokenForCollateralAddress).transferFrom(msg.sender, address(this), _amountOfCollateral);
        if (!success) {
            revert JSCEngine__TransferFailed();
        }
    }
}
