// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {DeployJSC} from "script/DeployJSC.s.sol";
import {JuliansStableCoin} from "src/JuliansStableCoin.sol";
import {JSCEngine} from "src/JSCEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract ForTest is Script {
    JuliansStableCoin jsc;
    JSCEngine jsce;
    HelperConfig config;

    function run() external {
        DeployJSC deployer = new DeployJSC();
        (jsc, jsce, config) = deployer.run();
        (, , address wEth, , ) = config.activeNetworkConfig();

        console.log(jsce.getUsdValue(wEth, 12e18));
    }
}
