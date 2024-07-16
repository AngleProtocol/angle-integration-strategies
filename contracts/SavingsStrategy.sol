// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import { BaseStrategy, ERC4626, Math } from "./BaseStrategy.sol";

contract SavingsStrategy is BaseStrategy {
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
        uint256 initialVestingPeriod,
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
    function _harvestRewards(bytes calldata) internal override {
        // Do nothing
    }

    /**
     * @inheritdoc BaseStrategy
     */
    function _beforeWithdraw(uint256 assets) internal override {
        ERC4626(strategyAsset).withdraw(assets, address(this), address(this));
    }

    /**
     * @inheritdoc BaseStrategy
     */
    function _afterDeposit(uint256 assets) internal override {
        ERC4626(strategyAsset).deposit(assets, address(this));
    }

    /**
     * @inheritdoc BaseStrategy
     */
    function _assetsHeld() internal view override returns (uint256) {
        return ERC4626(strategyAsset).convertToAssets(ERC4626(strategyAsset).balanceOf(address(this)));
    }

    /*//////////////////////////////////////////////////////////////
                        ERC4626 VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc ERC4626
     */
    function maxDeposit(address) public view override returns (uint256) {
        return ERC4626(strategyAsset).maxDeposit(address(this));
    }

    /**
     * @inheritdoc ERC4626
     */
    function maxMint(address) public view override returns (uint256) {
        return ERC4626(strategyAsset).maxMint(address(this));
    }

    /**
     * @inheritdoc ERC4626
     */
    function maxWithdraw(address owner) public view override returns (uint256) {
        return
            Math.min(
                _convertToAssets(balanceOf(owner), Math.Rounding.Floor),
                ERC4626(strategyAsset).maxWithdraw(address(this))
            );
    }

    /**
     * @inheritdoc ERC4626
     */
    function maxRedeem(address owner) public view override returns (uint256) {
        return Math.min(balanceOf(owner), ERC4626(strategyAsset).maxRedeem(address(this)));
    }
}
