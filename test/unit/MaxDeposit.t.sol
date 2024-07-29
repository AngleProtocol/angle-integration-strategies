// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.26;

import "../ERC4626StrategyTest.t.sol";

contract MaxDepositTest is ERC4626StrategyTest {
    function test_MaxDeposit_Success() public {
        assertEq(strategy.maxDeposit(alice), ERC4626(strategyAsset).maxDeposit(address(strategy)));
    }

    function test_MaxDeposit_MockValue() public {
        vm.mockCall(
            strategyAsset,
            abi.encodeWithSelector(ERC4626.maxDeposit.selector, address(strategy)),
            abi.encode(100e18)
        );
        assertEq(strategy.maxDeposit(alice), 100e18);
    }
}
