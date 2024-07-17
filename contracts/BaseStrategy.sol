// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import { ERC4626, IERC20, ERC20, Math } from "oz/token/ERC20/extensions/ERC4626.sol";
import { SafeERC20 } from "oz/token/ERC20/utils/SafeERC20.sol";
import { AccessControl } from "oz/access/AccessControl.sol";
import { UtilsLib } from "morpho/libraries/UtilsLib.sol";
import "./utils/Errors.sol";

abstract contract BaseStrategy is ERC4626, AccessControl {
    using SafeERC20 for IERC20;
    using UtilsLib for uint256;
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice Event emitted when the swap router is updated
     */
    event SwapRouterUpdated(address newSwapRouter);
    /**
     *  @notice Event emitted when the token proxy is updated
     */
    event TokenTransferAddressUpdated(address newTokenTransferAddress);
    /**
     *  @notice Event emitted when the performance fee is updated
     */
    event PerformanceFeeUpdated(uint256 newPerformanceFee);
    /**
     *  @notice Event emitted when the integrator fee recipient is updated
     */
    event IntegratorFeeRecipientUpdated(address newIntegratorFeeRecipient);
    /**
     *  @notice Event emitted when the labs fee recipient is updated
     */
    event LabsFeeRecipientUpdated(address newLabsFeeRecipient);
    /**
     *  @notice Event emitted when the vesting period is updated
     */
    event VestingPeriodUpdated(uint256 newVestingPeriod);
    /**
     *  @notice Event emitted when the interest is accrued
     */
    event UpdateLastTotalAssets(uint256 updatedTotalAssets);
    /**
     *  @notice Event emitted when the swap is performed
     */
    event AccrueInterest(uint256 newTotalAssets, uint256 integratorFeeShares, uint256 labsFeeShares);

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant INTEGRATOR_ROLE = keccak256("INTEGRATOR_ROLE");
    bytes32 public constant LABS_ROLE = keccak256("LABS_ROLE");

    uint256 public constant WAD = 100_000; // 100%

    /**
     * @notice The labs fee taken from the performance fee
     */
    uint256 public immutable LABS_FEE;
    /**
     * @notice The address of the strategy asset (stUSD for example)
     */
    address public immutable STRATEGY_ASSET;
    /**
     * @notice The offset to convert the decimals
     */
    uint256 private immutable _DECIMALS_OFFSET;

    /*//////////////////////////////////////////////////////////////
                            MUTABLE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice The profit that is locked in the strategy
     */
    uint256 public vestingProfit;
    /**
     * @notice The last time the profit was updated
     */
    uint256 public lastUpdate;
    /**
     * @notice The vesting period for the profit
     */
    uint256 public vestingPeriod;
    /**
     * @notice The last total assets of the vault
     */
    uint256 public lastTotalAssets;

    /**
     * @notice The performance fee taken from the harvested profits from the strategy
     */
    uint256 public performanceFee;
    /**
     * @notice The address that receives the performance fee minus the labs fee
     */
    address public integratorFeeRecipient;
    /**
     * @notice The address that receives the labs fee from the performance fee
     */
    address public labsFeeRecipient;

    /**
     *  @notice Dex/aggregaor router to call to perform swaps
     */
    address public swapRouter;
    /**
     * @notice Address to allow to swap tokens
     */
    address public tokenTransferAddress;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        uint256 initialPerformanceFee,
        address initialIntegratorFeeRecipient,
        address initialLabsFeeRecipient,
        address initialAdmin,
        address initialSwapRouter,
        address initialTokenTransferAddress,
        uint256 initialVestingPeriod,
        string memory definitiveName,
        string memory definitiveSymbol,
        address definitiveAsset,
        address definitiveStrategyAsset,
        uint256 definitiveLabsFee
    ) ERC20(definitiveName, definitiveSymbol) ERC4626(IERC20(definitiveAsset)) {
        if (initialPerformanceFee > WAD || definitiveLabsFee > WAD) {
            revert InvalidFee();
        }
        if (
            initialIntegratorFeeRecipient == address(0) ||
            initialLabsFeeRecipient == address(0) ||
            initialSwapRouter == address(0) ||
            initialTokenTransferAddress == address(0) ||
            definitiveStrategyAsset == address(0)
        ) {
            revert ZeroAddress();
        }

        vestingPeriod = initialVestingPeriod;
        performanceFee = initialPerformanceFee;
        integratorFeeRecipient = initialIntegratorFeeRecipient;
        labsFeeRecipient = initialLabsFeeRecipient;
        swapRouter = initialSwapRouter;
        tokenTransferAddress = initialTokenTransferAddress;

        LABS_FEE = definitiveLabsFee;
        STRATEGY_ASSET = definitiveStrategyAsset;
        _DECIMALS_OFFSET = uint256(18).zeroFloorSub(decimals());

        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
    }

    /*//////////////////////////////////////////////////////////////
                            ERC4626 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc ERC4626
     */
    function _decimalsOffset() internal view override returns (uint8) {
        return uint8(_DECIMALS_OFFSET);
    }

    /**
     * @inheritdoc ERC4626
     */
    function totalAssets() public view override returns (uint256) {
        return _assetsHeld() - lockedProfit();
    }

    /**
     * @inheritdoc ERC4626
     */
    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        uint256 newTotalAssets = _accrueFee();

        // Update `lastTotalAssets` to avoid an inconsistent state in a re-entrant context.
        // It is updated again in `_deposit`.
        lastTotalAssets = newTotalAssets;

        shares = _convertToSharesWithTotals(assets, totalSupply(), newTotalAssets, Math.Rounding.Floor);

        _deposit(_msgSender(), receiver, assets, shares);
    }

    /**
     * @inheritdoc ERC4626
     */
    function mint(uint256 shares, address receiver) public override returns (uint256 assets) {
        uint256 newTotalAssets = _accrueFee();

        // Update `lastTotalAssets` to avoid an inconsistent state in a re-entrant context.
        // It is updated again in `_deposit`.
        lastTotalAssets = newTotalAssets;

        assets = _convertToAssetsWithTotals(shares, totalSupply(), newTotalAssets, Math.Rounding.Ceil);

        _deposit(_msgSender(), receiver, assets, shares);
    }

    /**
     * @inheritdoc ERC4626
     */
    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256 shares) {
        uint256 newTotalAssets = _accrueFee();

        // Do not call expensive `maxWithdraw` and optimistically withdraw assets.

        shares = _convertToSharesWithTotals(assets, totalSupply(), newTotalAssets, Math.Rounding.Ceil);

        // `newTotalAssets - assets` may be a little off from `totalAssets()`.
        _updateLastTotalAssets(newTotalAssets.zeroFloorSub(assets));

        _withdraw(_msgSender(), receiver, owner, assets, shares);
    }

    /**
     * @inheritdoc ERC4626
     */
    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256 assets) {
        uint256 newTotalAssets = _accrueFee();

        // Do not call expensive `maxRedeem` and optimistically redeem shares.

        assets = _convertToAssetsWithTotals(shares, totalSupply(), newTotalAssets, Math.Rounding.Floor);

        // `newTotalAssets - assets` may be a little off from `totalAssets()`.
        _updateLastTotalAssets(newTotalAssets.zeroFloorSub(assets));

        _withdraw(_msgSender(), receiver, owner, assets, shares);
    }

    /**
     * @inheritdoc ERC4626
     */
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        super._deposit(caller, receiver, assets, shares);

        _afterDeposit(assets);

        // `lastTotalAssets + assets` may be a little off from `totalAssets()`.
        _updateLastTotalAssets(lastTotalAssets + assets);
    }

    /**
     * @inheritdoc ERC4626
     */
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal override {
        _beforeWithdraw(assets);

        super._withdraw(caller, receiver, owner, assets, shares);
    }

    /**
     * @inheritdoc ERC4626
     * @dev The accrual of performance fees is taken into account in the conversion.
     */
    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view override returns (uint256) {
        (uint256 integratorFeeShares, uint256 labsFeeShares, uint256 newTotalAssets) = _accruedFeeShares();

        return
            _convertToSharesWithTotals(
                assets,
                totalSupply() + labsFeeShares + integratorFeeShares,
                newTotalAssets,
                rounding
            );
    }

    /**
     * @inheritdoc ERC4626
     * @dev The accrual of performance fees is taken into account in the conversion.
     */
    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view override returns (uint256) {
        (uint256 integratorFeeShares, uint256 labsFeeShares, uint256 newTotalAssets) = _accruedFeeShares();

        return
            _convertToAssetsWithTotals(
                shares,
                totalSupply() + labsFeeShares + integratorFeeShares,
                newTotalAssets,
                rounding
            );
    }

    /**
     * @param assets The amount of assets to convert
     * @param newTotalSupply The new total supply of the vault
     * @param newTotalAssets The new total assets of the vault
     * @param rounding The rounding method to use
     * @return The amount of shares that the vault would exchange for the amount of `assets` provided
     *
     * @dev It assumes that the arguments `newTotalSupply` and `newTotalAssets` are up to date.
     */
    function _convertToSharesWithTotals(
        uint256 assets,
        uint256 newTotalSupply,
        uint256 newTotalAssets,
        Math.Rounding rounding
    ) internal view returns (uint256) {
        return assets.mulDiv(newTotalSupply + 10 ** _decimalsOffset(), newTotalAssets + 1, rounding);
    }

    /**
     * @param shares The amount of shares to convert
     * @param newTotalSupply The new total supply of the vault
     * @param newTotalAssets The new total assets of the vault
     * @param rounding The rounding method to use
     * @return The amount of assets that the vault would exchange for the amount of `shares` provided
     *
     * @dev It assumes that the arguments `newTotalSupply` and `newTotalAssets` are up to date.
     */
    function _convertToAssetsWithTotals(
        uint256 shares,
        uint256 newTotalSupply,
        uint256 newTotalAssets,
        Math.Rounding rounding
    ) internal view returns (uint256) {
        return shares.mulDiv(newTotalAssets + 1, newTotalSupply + 10 ** _decimalsOffset(), rounding);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Computes the current amount of locked profit
     * @dev This function is what effectively vests profits
     * @return The amount of locked profit
     */
    function lockedProfit() public view virtual returns (uint256) {
        // Get the last update and vesting delay.
        uint256 _lastUpdate = lastUpdate;
        uint256 _vestingPeriod = vestingPeriod;

        unchecked {
            // If the vesting period has passed, there is no locked profit.
            // This cannot overflow on human timescales
            if (block.timestamp >= _lastUpdate + _vestingPeriod) return 0;

            // Get the maximum amount we could return.
            uint256 currentlyVestingProfit = vestingProfit;

            // Compute how much profit remains locked based on the last time a profit was acknowledged
            // and the vesting period. It's impossible for an update to be in the future, so this will never underflow.
            return currentlyVestingProfit - (currentlyVestingProfit * (block.timestamp - _lastUpdate)) / _vestingPeriod;
        }
    }

    /*//////////////////////////////////////////////////////////////
                            HARVEST FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice  Updates the profit and loss made on the underlying strategy
     */
    function accumulate() public {
        _updateLastTotalAssets(_accrueFee());
    }

    /**
     * @notice Propagates a user side gain
     * @param gain Gain to propagate
     */
    function _handleUserGain(uint256 gain) internal virtual {
        if (gain != 0) {
            vestingProfit = (lockedProfit() + gain);
            lastUpdate = block.timestamp;
        }
    }

    /**
     * @dev Updates `lastTotalAssets` to `updatedTotalAssets`.
     * @param updatedTotalAssets The new total assets to set
     */
    function _updateLastTotalAssets(uint256 updatedTotalAssets) internal {
        lastTotalAssets = updatedTotalAssets;

        emit UpdateLastTotalAssets(updatedTotalAssets);
    }

    /**
     * @dev Accrues the fees and mints the fee shares to the fee recipients.
     * @return newTotalAssets The vault's total assets after accruing the interest.
     */
    function _accrueFee() internal returns (uint256 newTotalAssets) {
        uint256 labsFeeShares;
        uint256 integratorFeeShares;
        (integratorFeeShares, labsFeeShares, newTotalAssets) = _accruedFeeShares();

        if (integratorFeeShares != 0) {
            _mint(integratorFeeRecipient, integratorFeeShares);
        }
        if (labsFeeShares != 0) {
            _mint(labsFeeRecipient, labsFeeShares);
        }

        emit AccrueInterest(newTotalAssets, integratorFeeShares, labsFeeShares);
    }

    /**
     * @dev Computes and returns the fee shares (`feeShares`) to mint and the new vault's total assets
     * (`newTotalAssets`).
     */
    function _accruedFeeShares()
        internal
        view
        returns (uint256 integratorFeeShares, uint256 labsFeeShares, uint256 newTotalAssets)
    {
        newTotalAssets = totalAssets();

        uint256 totalInterest = newTotalAssets.zeroFloorSub(lastTotalAssets);
        if (totalInterest != 0 && performanceFee != 0) {
            // It is acknowledged that `feeAssets` may be rounded down to 0 if `totalInterest * fee < WAD`.
            uint256 feeAssets = totalInterest.mulDiv(performanceFee, WAD);
            // The fee assets is subtracted from the total assets in these calculations to compensate for the fact
            // that total assets is already increased by the total interest (including the fee assets).
            uint256 feeShares = _convertToSharesWithTotals(
                feeAssets,
                totalSupply(),
                newTotalAssets - feeAssets,
                Math.Rounding.Floor
            );

            labsFeeShares = feeShares.mulDiv(LABS_FEE, WAD);
            integratorFeeShares = feeShares - labsFeeShares; // Cannot underflow as labsFee <= WAD
        }
    }

    /*//////////////////////////////////////////////////////////////
                               ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set the vesting period for the profit
     * @param newVestingPeriod The new vesting period to set
     * @custom:requires DEFAULT_ADMIN_ROLE
     */
    function setVestingPeriod(uint256 newVestingPeriod) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newVestingPeriod == 0 || newVestingPeriod > 365 days) revert InvalidParameter();

        vestingPeriod = newVestingPeriod;

        emit VestingPeriodUpdated(newVestingPeriod);
    }

    /**
     * @notice Set the performance fee for the strategy
     * @param newPerformanceFee The new performance fee to set
     * @custom:requires INTEGRATOR_ROLE
     */
    function setPerformanceFee(uint256 newPerformanceFee) external onlyRole(INTEGRATOR_ROLE) {
        if (newPerformanceFee > WAD) {
            revert InvalidFee();
        }
        performanceFee = newPerformanceFee;

        emit PerformanceFeeUpdated(newPerformanceFee);
    }

    /**
     * @notice Set the integrator fee recipient
     * @param newIntegratorFeeRecipient The new integrator fee recipient to set
     * @custom:requires INTEGRATOR_ROLE
     */
    function setIntegratorFeeRecipient(address newIntegratorFeeRecipient) external onlyRole(INTEGRATOR_ROLE) {
        if (newIntegratorFeeRecipient == address(0)) {
            revert ZeroAddress();
        }
        integratorFeeRecipient = newIntegratorFeeRecipient;

        emit IntegratorFeeRecipientUpdated(newIntegratorFeeRecipient);
    }

    /**
     * @notice Set the labs fee recipient
     * @param newLabsFeeRecipient The new labs fee recipient to set
     * @custom:requires LABS_ROLE
     */
    function setLabsFeeRecipient(address newLabsFeeRecipient) external onlyRole(LABS_ROLE) {
        if (newLabsFeeRecipient == address(0)) {
            revert ZeroAddress();
        }
        labsFeeRecipient = newLabsFeeRecipient;

        emit LabsFeeRecipientUpdated(newLabsFeeRecipient);
    }

    /**
     * @notice Set the dex/aggregator router to call to perform swaps
     * @param newSwapRouter address of the router
     * @custom:requires DEFAULT_ADMIN_ROLE
     */
    function setSwapRouter(address newSwapRouter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newSwapRouter == address(0)) revert ZeroAddress();

        swapRouter = newSwapRouter;

        emit SwapRouterUpdated(newSwapRouter);
    }

    /**
     * @notice Set the token proxy address to allow to swap tokens
     * @param newTokenTransferAddress address of the token proxy
     * @custom:requires DEFAULT_ADMIN_ROLE
     */
    function setTokenTransferAddress(address newTokenTransferAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newTokenTransferAddress == address(0)) revert ZeroAddress();

        tokenTransferAddress = newTokenTransferAddress;

        emit TokenTransferAddressUpdated(newTokenTransferAddress);
    }

    /*//////////////////////////////////////////////////////////////
                            SWAP LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Swap tokens using the router/aggregator + vest the profit
     * @param tokens array of tokens to swap
     * @param callDatas array of bytes to call the router/aggregator
     * @custom:requires KEEPER_ROLE
     */
    function swap(address[] calldata tokens, bytes[] calldata callDatas) public onlyRole(KEEPER_ROLE) {
        address _asset = asset();
        address _strategyAsset = STRATEGY_ASSET;

        uint256 strategyAssetBalance = IERC20(_strategyAsset).balanceOf(address(this));

        _swap(tokens, callDatas);

        uint256 newAssetBalance = IERC20(_asset).balanceOf(address(this));

        _handleUserGain(newAssetBalance);
        _afterDeposit(newAssetBalance);

        uint256 newStrategyAssetBalance = IERC20(_strategyAsset).balanceOf(address(this));

        if (newStrategyAssetBalance < strategyAssetBalance) {
            revert OutgoingAssets();
        }
    }

    /**
     * @notice Swap tokens using the router/aggregator
     * @param tokens array of tokens to swap
     * @param callDatas array of bytes to call the router/aggregator
     */
    function _swap(address[] calldata tokens, bytes[] calldata callDatas) internal {
        uint256 length = tokens.length;
        for (uint256 i; i < length; ++i) {
            _approveTokenIfNeeded(tokens[i], tokenTransferAddress);
            _performRouterSwap(callDatas[i]);
        }
    }

    /**
     * @notice Perform the swap using the router/aggregator
     * @param callData bytes to call the router/aggregator
     */
    function _performRouterSwap(bytes calldata callData) internal {
        (bool success, bytes memory retData) = swapRouter.call(callData);

        if (!success) {
            if (retData.length != 0) {
                assembly {
                    revert(add(32, retData), mload(retData))
                }
            }
            revert SwapError();
        }
    }

    /**
     * @notice Approve the router/aggregator to spend the token if needed
     * @param _token address of the token to approve
     * @param _spender address of the router/aggregator
     */
    function _approveTokenIfNeeded(address _token, address _spender) internal {
        if (ERC20(_token).allowance(address(this), _spender) == 0) {
            IERC20(_token).approve(_spender, type(uint256).max);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                HOOKS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Compute the amount of asset held in the strategy contract
     * @return amount of asset held in the strategy contract
     */
    function _assetsHeld() internal view virtual returns (uint256);

    /**
     * @notice Hook that is called before a withdraw
     * @param assets The amount of assets to withdraw
     */
    function _beforeWithdraw(uint256 assets) internal virtual;

    /**
     * @notice Hook that is called after a deposit
     * @param assets The amount of assets to deposit
     */
    function _afterDeposit(uint256 assets) internal virtual;
}
