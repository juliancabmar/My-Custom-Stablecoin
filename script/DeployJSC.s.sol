// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {JuliansStableCoin} from "src/JuliansStableCoin.sol";
import {JSCEngine} from "src/JSCEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract DeployJSC is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (JuliansStableCoin, JSCEngine, HelperConfig) {
        HelperConfig config = new HelperConfig();
        (address wEthUsdPriceFeed, address wBtcUsdPriceFeed, address wEth, address wBtc, uint256 deployerKey) =
            config.activeNetworkConfig();

        tokenAddresses = [wEth, wBtc];
        priceFeedAddresses = [wEthUsdPriceFeed, wBtcUsdPriceFeed];

        vm.startBroadcast(deployerKey);
        JuliansStableCoin jsc = new JuliansStableCoin();
        JSCEngine jscEngine = new JSCEngine(tokenAddresses, priceFeedAddresses, address(jsc));

        jsc.transferOwnership(address(jscEngine));
        vm.stopBroadcast();

        return (jsc, jscEngine, config);
    }
}
