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
    address wEth;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployJSC();
        (jsc, jsce, config) = deployer.run();
        (ethUsdPriceFeed, , wEth, , ) = config.activeNetworkConfig();
        MockERC20(wEth).mint(USER, STARTING_ERC20_BALANCE);
    }

    // Price Tests

    function testGetUsdValue() public view {
        uint256 ehtAmount = 15e18;
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = jsce.getUsdValue(wEth, ehtAmount);
        assertEq(actualUsd, expectedUsd);
    }

    // Deposit collateral tests

    function testReverseIfCollateralZero() public {
        vm.startPrank(USER);
        MockERC20(wEth).approve(address(jsce), AMOUNT_COLLATERAL);

        vm.expectRevert(JSCEngine.JSCEngine__NeedsMoreThanZero.selector);
        jsce.depositCollateral(wEth, 0);
        vm.stopPrank();
    }
}
