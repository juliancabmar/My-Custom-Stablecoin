// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "lib/forge-std/src/Script.sol";
import {MockV3Aggregator} from "test/mock/MockV3Aggregator.sol";
import {MockERC20} from "test/mock/MockERC20.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address wEthUsdPriceFeed;
        address wBtcUsdPriceFeed;
        address wEth;
        address wBtc;
        uint256 deployerKey;
    }

    uint8 constant DECIMALS = 8;
    int256 constant ETH_USD_PRICE = 2000e8;
    int256 constant BTC_USD_PRICE = 1000e8;
    uint256 constant INITIAL_BALANCE = 1000e8;

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig()
        public
        view
        returns (NetworkConfig memory sepoliaNetworkConfig)
    {
        sepoliaNetworkConfig = NetworkConfig({
            wEthUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306, // ETH / USD
            wBtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            wEth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wBtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            deployerKey: vm.envUint("SEPOLIA_PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.wEthUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }
        vm.startBroadcast();
        MockV3Aggregator wEthUsdPriceFeed = new MockV3Aggregator(
            DECIMALS,
            ETH_USD_PRICE
        );
        MockERC20 wEthMock = new MockERC20(
            "Wrapped ETH",
            "WETH",
            msg.sender,
            INITIAL_BALANCE
        );

        MockV3Aggregator wBtcUsdPriceFeed = new MockV3Aggregator(
            DECIMALS,
            BTC_USD_PRICE
        );
        MockERC20 wBtcMock = new MockERC20(
            "Wrapped BTC",
            "WBTC",
            msg.sender,
            INITIAL_BALANCE
        );
        vm.stopBroadcast();

        return
            NetworkConfig({
                wEthUsdPriceFeed: address(wEthUsdPriceFeed),
                wBtcUsdPriceFeed: address(wBtcUsdPriceFeed),
                wEth: address(wEthMock),
                wBtc: address(wBtcMock),
                deployerKey: vm.envUint("ANVIL_PRIVATE_KEY")
            });
    }
}
