// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {DeployJSC} from "script/DeployJSC.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {JuliansStableCoin} from "src/JuliansStableCoin.sol";
import {JSCEngine} from "src/JSCEngine.sol";

contract JSCEngineTest is Test {
    DeployJSC private deployer;
    JuliansStableCoin jsc;
    JSCEngine jsce;
    HelperConfig config;
    address ethUsdPriceFeed;
    address wEth;

    function setUp() public {
        deployer = new DeployJSC();
        (jsc, jsce, config) = deployer.run();
        (ethUsdPriceFeed, , wEth, , ) = config.activeNetworkConfig();
    }

    // Price Tests

    function testGetUsdValue() public view {
        uint256 ehtAmount = 15e18;
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = jsce.getUsdValue(wEth, ehtAmount);
        assertEq(actualUsd, expectedUsd);
    }

    // Deposit collateral tests
}
