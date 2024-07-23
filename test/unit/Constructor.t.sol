// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.26;

import "../ERC4626StrategyTest.t.sol";

contract ConstructorTest is ERC4626StrategyTest {
    function test_constructor_Normal() public view {
        assertEq(strategy.vestingPeriod(), 1 weeks);
        assertEq(strategy.performanceFee(), 10_000);
        assertEq(strategy.developerFee(), 20_000);
        assertEq(strategy.developerFeeRecipient(), developer);
        assertEq(strategy.integratorFeeRecipient(), integrator);
        assertEq(strategy.swapRouter(), ONEINCH_ROUTER);
        assertEq(strategy.tokenTransferAddress(), ONEINCH_ROUTER);
        assertEq(strategy.STRATEGY_ASSET(), strategyAsset);
        assertEq(strategy.decimals(), 18);
        assertEq(strategy.name(), "stUSD Strategy");
        assertEq(strategy.symbol(), "stUSDStrat");
        assertEq(strategy.lockedProfit(), 0);
    }

    function test_constructor_CorrectRoles() public view {
        assertTrue(strategy.hasRole(strategy.DEVELOPER_ROLE(), developer));
        assertTrue(strategy.hasRole(strategy.INTEGRATOR_ROLE(), integrator));
        assertTrue(strategy.hasRole(strategy.KEEPER_ROLE(), keeper));

        assertEq(strategy.getRoleAdmin(strategy.DEVELOPER_ROLE()), strategy.DEVELOPER_ROLE());
        assertEq(strategy.getRoleAdmin(strategy.INTEGRATOR_ROLE()), strategy.INTEGRATOR_ROLE());
        assertEq(strategy.getRoleAdmin(strategy.KEEPER_ROLE()), strategy.DEVELOPER_ROLE());
    }

    function test_constructor_DifferentDecimals() public {
        vm.mockCall(asset, abi.encodeWithSelector(IERC20.decimals.selector), abi.encode(2));
        strategy = new ERC4626Strategy(
            BaseStrategy.ConstructorArgs(
                10000, // 10%
                20000, // 20%
                integrator,
                developer,
                keeper,
                developer,
                integrator,
                ONEINCH_ROUTER,
                ONEINCH_ROUTER,
                1 weeks,
                "stUSD Strategy",
                "stUSDStrat",
                asset,
                strategyAsset
            )
        );

        assertEq(strategy.decimals(), 18);
    }

    function test_constructor_MaxPerformanceFee() public {
        vm.expectRevert(InvalidFee.selector);
        strategy = new ERC4626Strategy(
            BaseStrategy.ConstructorArgs(
                100_001, // 100.001%
                20_000, // 20%
                integrator,
                developer,
                keeper,
                developer,
                integrator,
                ONEINCH_ROUTER,
                ONEINCH_ROUTER,
                1 weeks,
                "stUSD Strategy",
                "stUSDStrat",
                asset,
                strategyAsset
            )
        );
    }

    function test_constructor_MaxDeveloperFee() public {
        vm.expectRevert(InvalidFee.selector);
        strategy = new ERC4626Strategy(
            BaseStrategy.ConstructorArgs(
                100_000, // 100%
                50_001, // 20%
                integrator,
                developer,
                keeper,
                developer,
                integrator,
                ONEINCH_ROUTER,
                ONEINCH_ROUTER,
                1 weeks,
                "stUSD Strategy",
                "stUSDStrat",
                asset,
                strategyAsset
            )
        );
    }

    function test_constructor_ZeroAdress() public {
        vm.expectRevert(ZeroAddress.selector);
        strategy = new ERC4626Strategy(
            BaseStrategy.ConstructorArgs(
                10000, // 10%
                20_000, // 20%
                address(0),
                developer,
                keeper,
                developer,
                integrator,
                ONEINCH_ROUTER,
                ONEINCH_ROUTER,
                1 weeks,
                "stUSD Strategy",
                "stUSDStrat",
                asset,
                strategyAsset
            )
        );

        vm.expectRevert(ZeroAddress.selector);
        strategy = new ERC4626Strategy(
            BaseStrategy.ConstructorArgs(
                10000, // 10%
                20_000, // 20%
                integrator,
                address(0),
                keeper,
                developer,
                integrator,
                ONEINCH_ROUTER,
                ONEINCH_ROUTER,
                1 weeks,
                "stUSD Strategy",
                "stUSDStrat",
                asset,
                strategyAsset
            )
        );

        vm.expectRevert(ZeroAddress.selector);
        strategy = new ERC4626Strategy(
            BaseStrategy.ConstructorArgs(
                10000, // 10%
                20_000, // 20%
                integrator,
                developer,
                address(0),
                developer,
                integrator,
                ONEINCH_ROUTER,
                ONEINCH_ROUTER,
                1 weeks,
                "stUSD Strategy",
                "stUSDStrat",
                asset,
                strategyAsset
            )
        );

        vm.expectRevert(ZeroAddress.selector);
        strategy = new ERC4626Strategy(
            BaseStrategy.ConstructorArgs(
                10000, // 10%
                20_000, // 20%
                integrator,
                developer,
                keeper,
                address(0),
                integrator,
                ONEINCH_ROUTER,
                ONEINCH_ROUTER,
                1 weeks,
                "stUSD Strategy",
                "stUSDStrat",
                asset,
                strategyAsset
            )
        );

        vm.expectRevert(ZeroAddress.selector);
        strategy = new ERC4626Strategy(
            BaseStrategy.ConstructorArgs(
                10000, // 10%
                20_000, // 20%
                integrator,
                developer,
                keeper,
                developer,
                address(0),
                ONEINCH_ROUTER,
                ONEINCH_ROUTER,
                1 weeks,
                "stUSD Strategy",
                "stUSDStrat",
                asset,
                strategyAsset
            )
        );

        vm.expectRevert(ZeroAddress.selector);
        strategy = new ERC4626Strategy(
            BaseStrategy.ConstructorArgs(
                10000, // 10%
                20_000, // 20%
                integrator,
                developer,
                keeper,
                developer,
                integrator,
                address(0),
                ONEINCH_ROUTER,
                1 weeks,
                "stUSD Strategy",
                "stUSDStrat",
                asset,
                strategyAsset
            )
        );

        vm.expectRevert(ZeroAddress.selector);
        strategy = new ERC4626Strategy(
            BaseStrategy.ConstructorArgs(
                10000, // 10%
                20_000, // 20%
                integrator,
                developer,
                keeper,
                developer,
                integrator,
                ONEINCH_ROUTER,
                address(0),
                1 weeks,
                "stUSD Strategy",
                "stUSDStrat",
                asset,
                strategyAsset
            )
        );
    }
}
