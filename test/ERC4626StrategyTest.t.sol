// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.26;

import "./BaseTest.t.sol";
import "./Constants.t.sol";
import "../contracts/utils/Errors.sol";
import { IAccessControl } from "oz/access/AccessControl.sol";
import { ERC4626Strategy, BaseStrategy, ERC4626 } from "../contracts/ERC4626Strategy.sol";

contract ERC4626StrategyTest is BaseTest {
    ERC4626Strategy public strategy;
    address public asset;
    address public strategyAsset;

    function setUp() public virtual override {
        super.setUp();

        vm.createSelectFork("mainnet", 20363172);

        asset = _chainToContract(CHAIN_SOURCE, ContractType.AgUSD);
        strategyAsset = _chainToContract(CHAIN_SOURCE, ContractType.StUSD);

        strategy = new ERC4626Strategy(
            BaseStrategy.ConstructorArgs(
                1_000, // 10%
                2_000, // 20%
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
}
