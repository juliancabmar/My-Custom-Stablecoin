// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {StdInvariant} from "lib/forge-std/src/StdInvariant.sol";
import {DeployJSC} from "script/DeployJSC.s.sol";
import {JSCEngine} from "src/JSCEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {JuliansStableCoin} from "src/JuliansStableCoin.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Invariants is StdInvariant, Test {
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

    function invariant_protocolMustHaveMoreValueThenTotalSupply() public view {
        // get the value of all the collateral in the protocol
        // compare it to all debt (jsc)
        uint256 totalSupply = jsc.totalSupply();
        uint256 totalWethDeposited = IERC20(wEth).balanceOf(address(jsce));
        uint256 totalWbtcDeposited = IERC20(wBtc).balanceOf(address(jsce));

        uint256 wEthUsdValue = jsce.getUsdValue(wEth, totalWethDeposited);
        uint256 wBtcUsdValue = jsce.getUsdValue(wBtc, totalWbtcDeposited);

        console.log("wEthUsdValue: ", wEthUsdValue);
        console.log("wBtcUsdValue: ", wBtcUsdValue);
        console.log("totalSupply: ", totalSupply);

        assert(wEthUsdValue + wBtcUsdValue >= totalSupply);
    }
}
