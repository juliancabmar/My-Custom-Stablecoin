// OUTSIDE CONTRACTS,LIBRARIES or INTERFACES
// Pragma statements
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

// Import statements
import {JuliansStableCoin} from "src/JuliansStableCoin.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {AggregatorV3Interface} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol"; NOT WORK REMAPING... WHY?

// Events (global)
// Errors (global)
// Interfaces
// Libraries
// Contracts

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
contract JSCEngine is ReentrancyGuard {
    // Type declarations
    // State variables (#1:Constants, #2:Immutables, #3:Storage)
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // Can only mint JSC for 50% of the collateral value.
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10; // 10% bonus for liquidators

    JuliansStableCoin private immutable i_jsc;

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address tokenAddress => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountOfJscMinted) private s_jscMinted;
    address[] private s_colateralTokens;

    // Events
    event CollateralDeposited(address indexed user, address indexed tokenAddress, uint256 indexed amount);
    event CollateralRedeemed(
        address indexed redeemFrom, address indexed redeemTo, address indexed token, uint256 amount
    );

    // Errors (local)
    error JSCEngine__NeedsMoreThanZero();
    error JSCEngine__TokenAddressesAndPriceFeedsAddressesMustBeSameLength();
    error JSCEngine__InvalidTokenAddress();
    error JSCEngine__TransferFailed();
    error JSCEngine__BrokenHealthFactor(address user, uint256 healthFactor);
    error JSCEngine__MintFailed();
    error JSCEngine__HealthFactorOK();
    error JSCEngine__HealthFactorNotImproved();

    // Modifiers
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

    // constructor
    constructor(address[] memory _tokenAddresses, address[] memory _priceFeedsAddresses, address _jscAddress) {
        if (_tokenAddresses.length != _priceFeedsAddresses.length) {
            revert JSCEngine__TokenAddressesAndPriceFeedsAddressesMustBeSameLength();
        }
        for (uint256 i = 0; i < _tokenAddresses.length; i++) {
            s_priceFeeds[_tokenAddresses[i]] = _priceFeedsAddresses[i];
            s_colateralTokens.push(_tokenAddresses[i]);
        }
        i_jsc = JuliansStableCoin(_jscAddress);
    }

    // receive function (if exists)

    // fallback function (if exists)

    // external
    function depositCollateralAndMintJsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountJSCToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintJsc(amountJSCToMint);
    }

    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        uint256 startingUserHealthFactor = _userHealthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert JSCEngine__HealthFactorOK();
        }
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;
        _redeemCollateral(user, msg.sender, collateral, totalCollateralToRedeem);
        _burnJsc(debtToCover, user, msg.sender);

        uint256 endingUserHealthFactor = _userHealthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert JSCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function getAccountInformation(address _user)
        external
        view
        returns (uint256 totalJscMinted, uint256 collateralValueInUsd)
    {
        (totalJscMinted, collateralValueInUsd) = _getAccountInformation(_user);
    }

    // public
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(msg.sender, msg.sender, tokenCollateralAddress, amountCollateral);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function mintJsc(uint256 _amountJscToMint) public moreThanZero(_amountJscToMint) {
        s_jscMinted[msg.sender] += _amountJscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_jsc.mint(msg.sender, _amountJscToMint);
        if (!minted) {
            revert JSCEngine__MintFailed();
        }
    }

    function depositCollateral(address _tokenForCollateralAddress, uint256 _amountOfCollateral)
        public
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

    function burnJsc(uint256 amount) public moreThanZero(amount) {
        _burnJsc(amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function getCollateralValue(address _user) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 i = 0; i < s_colateralTokens.length; i++) {
            address token = s_colateralTokens[i];
            uint256 amount = s_collateralDeposited[_user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
    }

    function getUsdValue(address _token, uint256 _amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[_token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        uint8 usdDecimals = priceFeed.decimals();
        // The price had 8 extra decimals
        return (uint256(price) * _amount) / ((10 ** usdDecimals) * PRECISION);
    }

    function getTokenAmountFromUsd(address token, uint256 usdAmountToWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        uint8 usdDecimals = priceFeed.decimals();
        return ((usdAmountToWei * (10 ** usdDecimals) * PRECISION) / uint256(price));
    }

    // internal

    function _revertIfHealthFactorIsBroken(address _user) internal view {
        uint256 userHealthFactor = _userHealthFactor(_user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert JSCEngine__BrokenHealthFactor(_user, userHealthFactor);
        }
    }

    function revertIfHealthFactorIsBroken(address _user) internal view {}

    // private

    function _redeemCollateral(address from, address to, address tokenCollateralAddress, uint256 amountCollateral)
        private
    {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);

        bool success = ERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert JSCEngine__TransferFailed();
        }
    }

    function _burnJsc(uint256 amountJscToBurn, address onBehalfOf, address jscFrom) private {
        s_jscMinted[onBehalfOf] -= amountJscToBurn;
        bool success = i_jsc.transferFrom(jscFrom, address(this), amountJscToBurn);
        if (!success) {
            revert JSCEngine__TransferFailed();
        }
        i_jsc.burn(amountJscToBurn);
    }

    function _getAccountInformation(address _user)
        private
        view
        returns (uint256 totalJscMinted, uint256 totalCollateralValueInUsd)
    {
        totalJscMinted = s_jscMinted[_user];
        totalCollateralValueInUsd = getCollateralValue(_user);
    }

    function _userHealthFactor(address _user) private view returns (uint256 healthFactorPercentage) {
        (uint256 totalJscMinted, uint256 totalCollateralValueInUsd) = _getAccountInformation(_user);
        uint256 jscMintLimit = (totalCollateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (jscMintLimit * PRECISION) / totalJscMinted;
    }
}
