// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {JSCEngine} from "src/JSCEngine.sol";
import {JuliansStableCoin} from "src/JuliansStableCoin.sol";
import {MockERC20} from "test/mock/MockERC20.sol";

contract Handler is Test {
    JSCEngine jsce;
    JuliansStableCoin jsc;

    MockERC20 wEth;
    MockERC20 wBtc;

    uint256 public timesMintisCalled;

    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(JSCEngine _jsce, JuliansStableCoin _jsc) {
        jsce = _jsce;
        jsc = _jsc;
    }

    function mintJsc(uint256 amount) public {}
}
