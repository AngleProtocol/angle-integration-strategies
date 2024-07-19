// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import { BaseStrategy, ERC4626, Math } from "./BaseStrategy.sol";

/// @title ERC4626Strategy
/// @author Angle Labs, Inc.
/// @notice Strategy contract implementing the logic to interact with an ERC4626 asset
contract ERC4626Strategy is BaseStrategy {
    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(BaseStrategy.ConstructorArgs memory args) BaseStrategy(args) {}

    /*//////////////////////////////////////////////////////////////
                        HOOKS IMPLEMENTATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc BaseStrategy
     */
    function _beforeWithdraw(uint256 assets) internal override {
        ERC4626(STRATEGY_ASSET).withdraw(assets, address(this), address(this));
    }

    /**
     * @inheritdoc BaseStrategy
     */
    function _afterDeposit(uint256 assets) internal override {
        ERC4626(STRATEGY_ASSET).deposit(assets, address(this));
    }

    /**
     * @inheritdoc BaseStrategy
     * @dev it works only for ERC4626 with infinite liquidity (stUSD or MetaMorpho like)
     */
    function _assetsHeld() internal view override returns (uint256) {
        address _strategyAsset = STRATEGY_ASSET;
        return ERC4626(_strategyAsset).convertToAssets(ERC4626(_strategyAsset).balanceOf(address(this)));
    }

    /*//////////////////////////////////////////////////////////////
                        ERC4626 VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc ERC4626
     */
    function maxDeposit(address) public view override returns (uint256) {
        return ERC4626(STRATEGY_ASSET).maxDeposit(address(this));
    }

    /**
     * @inheritdoc ERC4626
     * @dev might overflow (in this case, the user should be able to mint the type(uint256).max)
     */
    function maxMint(address) public view override returns (uint256) {
        return _convertToShares(ERC4626(STRATEGY_ASSET).maxDeposit(address(this)), Math.Rounding.Floor);
    }

    /**
     * @inheritdoc ERC4626
     */
    function maxWithdraw(address user) public view override returns (uint256) {
        return
            Math.min(
                _convertToAssets(balanceOf(user), Math.Rounding.Floor),
                ERC4626(STRATEGY_ASSET).maxWithdraw(address(this))
            );
    }

    /**
     * @inheritdoc ERC4626
     * @dev might overflow (in this case, the user should be able to redeem the type(uint256).max)))
     */
    function maxRedeem(address user) public view override returns (uint256) {
        return _convertToShares(maxWithdraw(user), Math.Rounding.Floor);
    }
}
