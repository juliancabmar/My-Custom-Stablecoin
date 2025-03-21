// OUTSIDE CONTRACTS,LIBRARIES or INTERFACES
// Pragma statements
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

// Import statements
import {JuliansStableCoin} from "src/JuliansStableCoin.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {AggregatorV3Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

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
    uint256 constant LIQUIDATION_THRESHOLD = 50; // Can only mint JSC for 50% of the collateral value.
    uint256 constant LIQUIDATION_PRECISION = 100;
    uint256 constant PRECISION = 1e18;
    uint256 constant MIN_HEALTH_FACTOR = 1;

    JuliansStableCoin private immutable i_jsc;

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address tokenAddress => uint256 amount))
        private s_collateralDeposited;
    mapping(address user => uint256 amountOfJscMinted) private s_jscMinted;
    address[] private s_colateralTokens;

    // Events
    event CollateralDeposited(
        address indexed user,
        address indexed tokenAddress,
        uint256 indexed amount
    );
    event CollateralRedeemed(
        address indexed user,
        address indexed token,
        uint256 indexed amount
    );

    // Errors (local)
    error JSCEngine__NeedsMoreThanZero();
    error JSCEngine__TokenAddressesAndPriceFeedsAddressesMustBeSameLength();
    error JSCEngine__InvalidTokenAddress();
    error JSCEngine__TransferFailed();
    error JSCEngine__BrokenHealthFactor(address user, uint256 healthFactor);
    error JSCEngine__MintFailed();

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
    constructor(
        address[] memory _tokenAddresses,
        address[] memory _priceFeedsAddresses,
        address _jscAddress
    ) {
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

    function redeemCollateralFromJsc() external {}

    function redeemCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    ) external moreThanZero(amountCollateral) nonReentrant {
        s_collateralDeposited[msg.sender][
            tokenCollateralAddress
        ] -= amountCollateral;
        emit CollateralRedeemed(
            msg.sender,
            tokenCollateralAddress,
            amountCollateral
        );
    }

    function liquidate() external {}

    // public
    function mintJsc(
        uint256 _amountJscToMint
    ) public moreThanZero(_amountJscToMint) {
        s_jscMinted[msg.sender] += _amountJscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_jsc.mint(msg.sender, _amountJscToMint);
        if (!minted) {
            revert JSCEngine__MintFailed();
        }
    }

    function depositCollateral(
        address _tokenForCollateralAddress,
        uint256 _amountOfCollateral
    )
        public
        moreThanZero(_amountOfCollateral)
        isAllowedToken(_tokenForCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][
            _tokenForCollateralAddress
        ] += _amountOfCollateral;
        emit CollateralDeposited(
            msg.sender,
            _tokenForCollateralAddress,
            _amountOfCollateral
        );
        bool success = ERC20(_tokenForCollateralAddress).transferFrom(
            msg.sender,
            address(this),
            _amountOfCollateral
        );
        if (!success) {
            revert JSCEngine__TransferFailed();
        }
    }

    function _getCollateralValue(
        address _user
    ) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 i = 0; i < s_colateralTokens.length; i++) {
            address token = s_colateralTokens[i];
            uint256 amount = s_collateralDeposited[_user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
    }

    function getUsdValue(
        address _token,
        uint256 _amount
    ) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[_token]
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        uint8 usdDecimals = priceFeed.decimals();
        // The price had 8 extra decimals
        return (uint256(price) * _amount) / (10 ** usdDecimals);
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

    function _redeemCollateral() private {}

    function _burnJsc() private {}

    function _getAccountInformation(
        address _user
    )
        private
        view
        returns (uint256 totalJscMinted, uint256 totalCollateralValueInUsd)
    {
        totalJscMinted = s_jscMinted[_user];
        totalCollateralValueInUsd = _getCollateralValue(_user);
    }

    function _userHealthFactor(
        address _user
    ) private view returns (uint256 healthFactorPercentage) {
        (
            uint256 totalJscMinted,
            uint256 totalCollateralValueInUsd
        ) = _getAccountInformation(_user);
        uint256 jscMintLimit = (totalCollateralValueInUsd *
            LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (jscMintLimit * PRECISION) / totalJscMinted;
    }
}
