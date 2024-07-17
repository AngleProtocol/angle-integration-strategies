// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import { BaseStrategy, ERC4626, Math } from "./BaseStrategy.sol";

contract ERC4626Strategy is BaseStrategy {
    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        uint256 initialPerformanceFee,
        address initialIntegratorFeeRecipient,
        address initialProtocolFeeRecipient,
        address initialAdmin,
        address initialSwapRouter,
        address initialTokenTransferAddress,
        uint32 initialVestingPeriod,
        string memory definitiveName,
        string memory definitiveSymbol,
        address definitiveAsset,
        address definitiveStrategyAsset,
        uint256 definitiveProtocolFee
    )
        BaseStrategy(
            initialPerformanceFee,
            initialIntegratorFeeRecipient,
            initialProtocolFeeRecipient,
            initialAdmin,
            initialSwapRouter,
            initialTokenTransferAddress,
            initialVestingPeriod,
            definitiveName,
            definitiveSymbol,
            definitiveAsset,
            definitiveStrategyAsset,
            definitiveProtocolFee
        )
    {}

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
     */
    function _assetsHeld() internal view override returns (uint256) {
        return ERC4626(STRATEGY_ASSET).convertToAssets(ERC4626(STRATEGY_ASSET).balanceOf(address(this)));
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
     */
    function maxMint(address) public view override returns (uint256) {
        return ERC4626(STRATEGY_ASSET).maxMint(address(this));
    }

    /**
     * @inheritdoc ERC4626
     */
    function maxWithdraw(address owner) public view override returns (uint256) {
        return
            Math.min(
                _convertToAssets(balanceOf(owner), Math.Rounding.Floor),
                ERC4626(STRATEGY_ASSET).maxWithdraw(address(this))
            );
    }

    /**
     * @inheritdoc ERC4626
     */
    function maxRedeem(address owner) public view override returns (uint256) {
        // I don't think this is accurate here as the unit of the shares of the strategy assets are not always the
        // same as the units of the strategy
        return Math.min(balanceOf(owner), ERC4626(STRATEGY_ASSET).maxRedeem(address(this)));
    }
}
