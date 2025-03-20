// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "lib/forge-std/src/Test.sol";
import {DeployJSC} from "script/DeployJSC.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {JuliansStableCoin} from "src/JuliansStableCoin.sol";
import {JSCEngine} from "src/JSCEngine.sol";

contract JSCEngineTest is Test {
    DeployJSC private deployer;
    function setUp() public {
        deployer = new DeployJSC();
        (JuliansStableCoin jsc, JSCEngine jsce, HelperConfig config) = deployer.run();
        // Set up state variables
    }
}