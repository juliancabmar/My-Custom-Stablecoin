// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {DeployJSC} from "script/DeployJSC.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {JuliansStableCoin} from "src/JuliansStableCoin.sol";
import {JSCEngine} from "src/JSCEngine.sol";
import {MockERC20} from "../mock/MockERC20.sol";

contract JSCEngineTest is Test {
    DeployJSC private deployer;
    JuliansStableCoin jsc;
    JSCEngine jsce;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address wEth;
    address wBtc;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    modifier depositedCollateral() {
        vm.startPrank(USER);
        MockERC20(wEth).approve(address(jsce), AMOUNT_COLLATERAL);
        jsce.depositCollateral(wEth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    modifier depositedCollateralAndMintedJsc() {
        vm.startPrank(USER);
        MockERC20(wEth).approve(address(jsce), AMOUNT_COLLATERAL);
        jsce.depositCollateralAndMintJsc(wEth, AMOUNT_COLLATERAL, 1 ether);
        vm.stopPrank();
        _;
    }

    function setUp() public {
        deployer = new DeployJSC();
        (jsc, jsce, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, wEth, wBtc,) = config.activeNetworkConfig();
        MockERC20(wEth).mint(USER, STARTING_ERC20_BALANCE);
    }

    // Constructor Tests

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(wEth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(JSCEngine.JSCEngine__TokenAddressesAndPriceFeedsAddressesMustBeSameLength.selector);
        new JSCEngine(tokenAddresses, priceFeedAddresses, address(jsc));
    }

    // Price Tests

    function testGetUsdValue() public view {
        uint256 ehtAmount = 15e18;
        uint256 expectedUsd = 30000;
        uint256 actualUsd = jsce.getUsdValue(wEth, ehtAmount);
        assertEq(actualUsd, expectedUsd);
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 1000;
        uint256 expectedTokenAmount = 5e17;
        uint256 actualToken = jsce.getTokenAmountFromUsd(wEth, usdAmount);
        assertEq(actualToken, expectedTokenAmount);
    }

    // Deposit collateral tests

    function testReverseIfCollateralZero() public {
        vm.startPrank(USER);
        MockERC20(wEth).approve(address(jsce), AMOUNT_COLLATERAL);

        vm.expectRevert(JSCEngine.JSCEngine__NeedsMoreThanZero.selector);
        jsce.depositCollateral(wEth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        MockERC20 ranToken = new MockERC20("RAN", "RAN", USER, STARTING_ERC20_BALANCE);
        vm.startPrank(USER);
        vm.expectRevert(JSCEngine.JSCEngine__InvalidTokenAddress.selector);
        jsce.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalJscminted, uint256 collateralValueInUsd) = jsce.getAccountInformation(USER);

        uint256 expectedTotalJscMinted = 0;
        uint256 expectedDepositAmount = jsce.getTokenAmountFromUsd(wEth, collateralValueInUsd);

        assertEq(totalJscminted, expectedTotalJscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    function testDepositCollateralAndMintJsc() public {
        uint256 expectedTotalJscMinted = 1000;
        vm.startPrank(USER);
        MockERC20(wEth).approve(address(jsce), AMOUNT_COLLATERAL);
        jsce.depositCollateralAndMintJsc(wEth, AMOUNT_COLLATERAL, expectedTotalJscMinted);
        vm.stopPrank();

        (uint256 totalJscminted, uint256 collateralValueInUsd) = jsce.getAccountInformation(USER);

        uint256 expectedDepositAmount = jsce.getTokenAmountFromUsd(wEth, collateralValueInUsd);

        assertEq(totalJscminted, expectedTotalJscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    function testMoreThanZero() public {
        vm.expectRevert(JSCEngine.JSCEngine__NeedsMoreThanZero.selector);
        jsce.depositCollateral(wEth, 0);
    }

    function testGetAccountInformation() public depositedCollateral {
        (uint256 totalJscminted, uint256 collateralValueInUsd) = jsce.getAccountInformation(USER);

        uint256 expectedTotalJscMinted = 0;
        uint256 expectedDepositAmount = jsce.getTokenAmountFromUsd(wEth, collateralValueInUsd);

        assertEq(totalJscminted, expectedTotalJscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    function testGetCollateralValue() public depositedCollateral {
        uint256 actualCollateralValue = jsce.getCollateralValue(USER);
        uint256 expectesCollateralValue = jsce.getUsdValue(wEth, AMOUNT_COLLATERAL);
        assertEq(actualCollateralValue, expectesCollateralValue);
    }

    // Mint and Burn JSC Tests

    function testMintJsc() public depositedCollateral {
        uint256 amountToMint = jsce.getUsdValue(wEth, AMOUNT_COLLATERAL * 45 / 100);
        vm.prank(USER);
        jsce.mintJsc(amountToMint);
        (uint256 totalJscminted,) = jsce.getAccountInformation(USER);
        assertEq(totalJscminted, amountToMint);
        console.log(amountToMint);
    }

    // function testBurnJsc() public depositedCollateral {
    //     uint256 amountToMint = jsce.getUsdValue(wEth, AMOUNT_COLLATERAL * 45 / 100);
    //     vm.startPrank(USER);
    //     jsce.mintJsc(amountToMint);
    //     (uint256 totalJscminted,) = jsce.getAccountInformation(USER);
    //     jsc.approve(address(jsce), totalJscminted);
    //     jsce.burnJsc(totalJscminted);
    //     vm.stopPrank();
    //     // assertEq(totalJscminted, 0);
    // }

    function testBurnJsc() public depositedCollateralAndMintedJsc {
        vm.startPrank(USER);
        jsc.approve(address(jsce), 1000);
        jsce.burnJsc(1000);
        vm.stopPrank();

        uint256 userBalance = jsc.balanceOf(USER);
        assertEq(userBalance, 0);
    }

    // Reedem Collateral Tests

    // function testRedeemColateral() public depositedCollateral {
    //     vm.startPrank(USER);
    //     jsce.redeemCollateral(wEth, AMOUNT_COLLATERAL);
    //     vm.stopPrank();
    // }
}
