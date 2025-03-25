// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "lib/forge-std/src/Test.sol";
import {StdInvariant} from "lib/forge-std/src/StdInvariant.sol";
import {DeployJSC} from "script/DeployJSC.s.sol";
import {JSCEngine} from "src/JSCEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {JuliansStableCoin} from "src/JuliansStableCoin.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract InvariantsTest is StdInvariant, Test {
    DeployJSC private deployer;
    JuliansStableCoin jsc;
    JSCEngine jsce;
    HelperConfig config;
    address wEth;
    address wBtc;

    function setUp() external {
        deployer = new DeployJSC();
        (jsc, jsce, config) = deployer.run();
        (,, wEth, wBtc,) = config.activeNetworkConfig();
        targetContract(address(jsce));
    }
}
