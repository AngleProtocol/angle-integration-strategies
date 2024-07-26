// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.26;

import "../ERC4626StrategyTest.t.sol";

contract MaxDepositTest is ERC4626StrategyTest {
    function test_MaxDeposit_Success() public {
        assertEq(strategy.maxDeposit(alice), ERC4626(strategyAsset).maxDeposit(address(strategy)));
    }
}
