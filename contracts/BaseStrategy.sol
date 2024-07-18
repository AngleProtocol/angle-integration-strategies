// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import { ERC4626, IERC20, ERC20, Math } from "oz/token/ERC20/extensions/ERC4626.sol";
import { SafeERC20 } from "oz/token/ERC20/utils/SafeERC20.sol";
import { AccessControl } from "oz/access/AccessControl.sol";
import { UtilsLib } from "morpho/libraries/UtilsLib.sol";
import "./utils/Errors.sol";

/// @title BaseStrategy
/// @author Angle Labs, Inc.
/// @notice Abstract contract to proxy the interaction with an strategy while taking performance fees
/// @dev This contract is using the MetaMorpho codebase as a base for the ERC4626 logic with an extra vesting logic
/// and extra fee: https://github.com/morpho-org/metamorpho/blob/main/src/MetaMorpho.sol
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
     *  @notice Event emitted when the developer fee is updated
     */
    event DeveloperFeeUpdated(uint256 newDeveloperFee);
    /**
     *  @notice Event emitted when the integrator fee recipient is updated
     */
    event IntegratorFeeRecipientUpdated(address newIntegratorFeeRecipient);
    /**
     *  @notice Event emitted when the developer fee recipient is updated
     */
    event DeveloperFeeRecipientUpdated(address newDeveloperFeeRecipient);
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
    event AccrueInterest(uint256 newTotalAssets, uint256 integratorFeeShares, uint256 developerFeeShares);

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier noZeroAddress(address targetAddress) {
        if (targetAddress == address(0)) {
            revert ZeroAddress();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct ConstructorArgs {
        uint32 initialPerformanceFee;
        uint32 initialDeveloperFee;
        address initialIntegratorFeeRecipient;
        address initialDeveloperFeeRecipient;
        address initialKeeper;
        address initialDeveloper;
        address initialIntegrator;
        address initialSwapRouter;
        address initialTokenTransferAddress;
        uint64 initialVestingPeriod;
        string definitiveName;
        string definitiveSymbol;
        address definitiveAsset;
        address definitiveStrategyAsset;
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant INTEGRATOR_ROLE = keccak256("INTEGRATOR_ROLE");
    bytes32 public constant DEVELOPER_ROLE = keccak256("DEVELOPER_ROLE");

    uint32 public constant WAD = 100_000; // 100%
    uint32 public constant MAX_FEE = 50_000; // 50%

    /**
     * @notice The offset to convert the decimals
     */
    uint8 private immutable _DECIMALS_OFFSET;
    /**
     * @notice The address of the strategy asset (stUSD for example)
     */
    address public immutable STRATEGY_ASSET;

    /*//////////////////////////////////////////////////////////////
                            MUTABLE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice The vesting period of the rewards
     */
    uint64 public vestingPeriod;
    /**
     * @notice The last update of the vesting
     */
    uint64 public lastUpdate;
    /**
     * @notice The profit that is locked in the strategy
     */
    uint128 public vestingProfit;
    /**
     * @notice The last total assets of the vault
     */
    uint256 public lastTotalAssets;
    /**
     * @notice The performance fee taken from the harvested profits from the strategy
     */
    uint32 public performanceFee;
    /**
     * @notice The address that receives the performance fee minus the developer fee
     */
    address public integratorFeeRecipient;
    /**
     * @notice The developer fee taken from the performance fee
     */
    uint32 public developerFee;
    /**
     * @notice The address that receives the developer fee from the performance fee
     */
    address public developerFeeRecipient;
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
        ConstructorArgs memory args
    ) ERC20(args.definitiveName, args.definitiveSymbol) ERC4626(IERC20(args.definitiveAsset)) {
        if (args.initialPerformanceFee > WAD || args.initialDeveloperFee > WAD || args.initialDeveloperFee > MAX_FEE) {
            revert InvalidFee();
        }
        if (
            args.initialIntegratorFeeRecipient == address(0) ||
            args.initialDeveloperFeeRecipient == address(0) ||
            args.initialSwapRouter == address(0) ||
            args.initialTokenTransferAddress == address(0) ||
            args.definitiveStrategyAsset == address(0)
        ) {
            revert ZeroAddress();
        }

        vestingPeriod = args.initialVestingPeriod;
        performanceFee = args.initialPerformanceFee;
        developerFee = args.initialDeveloperFee;
        integratorFeeRecipient = args.initialIntegratorFeeRecipient;
        developerFeeRecipient = args.initialDeveloperFeeRecipient;
        swapRouter = args.initialSwapRouter;
        tokenTransferAddress = args.initialTokenTransferAddress;

        STRATEGY_ASSET = args.definitiveStrategyAsset;
        _DECIMALS_OFFSET = uint8(uint256(18).zeroFloorSub(decimals()));

        // Roles managment
        _grantRole(KEEPER_ROLE, args.initialKeeper);
        _grantRole(DEVELOPER_ROLE, args.initialDeveloper);
        _grantRole(INTEGRATOR_ROLE, args.initialIntegrator);
        _setRoleAdmin(KEEPER_ROLE, DEVELOPER_ROLE);
        _setRoleAdmin(INTEGRATOR_ROLE, INTEGRATOR_ROLE);
        _setRoleAdmin(DEVELOPER_ROLE, DEVELOPER_ROLE);
    }

    /*//////////////////////////////////////////////////////////////
                            ERC4626 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc ERC4626
     */
    function _decimalsOffset() internal view override returns (uint8) {
        return _DECIMALS_OFFSET;
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
        (uint256 integratorFeeShares, uint256 developerFeeShares, uint256 newTotalAssets) = _accruedFeeShares();

        return
            _convertToSharesWithTotals(
                assets,
                totalSupply() + developerFeeShares + integratorFeeShares,
                newTotalAssets,
                rounding
            );
    }

    /**
     * @inheritdoc ERC4626
     * @dev The accrual of performance fees is taken into account in the conversion.
     */
    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view override returns (uint256) {
        (uint256 integratorFeeShares, uint256 developerFeeShares, uint256 newTotalAssets) = _accruedFeeShares();

        return
            _convertToAssetsWithTotals(
                shares,
                totalSupply() + developerFeeShares + integratorFeeShares,
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
        uint64 _lastUpdate = lastUpdate;
        uint64 _vestingPeriod = vestingPeriod;

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
            vestingProfit = uint128(lockedProfit() + gain);
            lastUpdate = uint32(block.timestamp);
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
        uint256 developerFeeShares;
        uint256 integratorFeeShares;
        (integratorFeeShares, developerFeeShares, newTotalAssets) = _accruedFeeShares();

        if (integratorFeeShares != 0) {
            _mint(integratorFeeRecipient, integratorFeeShares);
        }
        if (developerFeeShares != 0) {
            _mint(developerFeeRecipient, developerFeeShares);
        }

        emit AccrueInterest(newTotalAssets, integratorFeeShares, developerFeeShares);
    }

    /**
     * @dev Computes and returns the fee shares (`feeShares`) to mint and the new vault's total assets
     * (`newTotalAssets`).
     */
    function _accruedFeeShares()
        internal
        view
        returns (uint256 integratorFeeShares, uint256 developerFeeShares, uint256 newTotalAssets)
    {
        newTotalAssets = totalAssets();

        // `newTotalAssets.zeroFloorSub(lastTotalAssets)` is the value of the total interest earned by the strategy.
        // `feeAssets` may be rounded down to 0 if `totalInterest * fee < WAD`.
        uint256 feeAssets = (newTotalAssets.zeroFloorSub(lastTotalAssets)).mulDiv(performanceFee, WAD);
        if (feeAssets != 0) {
            // The fee assets is subtracted from the total assets in these calculations to compensate for the fact
            // that total assets is already increased by the total interest (including the fee assets).
            uint256 feeShares = _convertToSharesWithTotals(
                feeAssets,
                totalSupply(),
                newTotalAssets - feeAssets,
                Math.Rounding.Floor
            );

            developerFeeShares = feeShares.mulDiv(developerFee, WAD);
            integratorFeeShares = feeShares - developerFeeShares; // Cannot underflow as developerFee <= WAD
        }
    }

    /*//////////////////////////////////////////////////////////////
                               ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set the vesting period for the profit
     * @param newVestingPeriod The new vesting period to set
     * @custom:requires INTEGRATOR_ROLE
     */
    function setVestingPeriod(uint64 newVestingPeriod) external onlyRole(INTEGRATOR_ROLE) {
        if (newVestingPeriod == 0 || newVestingPeriod > 365 days) revert InvalidParameter();

        vestingPeriod = newVestingPeriod;

        emit VestingPeriodUpdated(newVestingPeriod);
    }

    /**
     * @notice Set the performance fee for the strategy
     * @param newPerformanceFee The new performance fee to set
     * @custom:requires INTEGRATOR_ROLE
     */
    function setPerformanceFee(uint32 newPerformanceFee) external onlyRole(INTEGRATOR_ROLE) {
        if (newPerformanceFee > WAD) {
            revert InvalidFee();
        }
        performanceFee = newPerformanceFee;

        emit PerformanceFeeUpdated(newPerformanceFee);
    }

    /**
     * @notice Set the developer fee for the strategy
     * @param newDeveloperFee The new developer fee to set
     * @custom:requires DEVELOPER_ROLE
     */
    function setDeveloperFee(uint32 newDeveloperFee) external onlyRole(DEVELOPER_ROLE) {
        if (newDeveloperFee > WAD || newDeveloperFee > performanceFee) {
            revert InvalidFee();
        }
        developerFee = newDeveloperFee;

        emit DeveloperFeeUpdated(newDeveloperFee);
    }

    /**
     * @notice Set the integrator fee recipient
     * @param newIntegratorFeeRecipient The new integrator fee recipient to set
     * @custom:requires INTEGRATOR_ROLE
     */
    function setIntegratorFeeRecipient(
        address newIntegratorFeeRecipient
    ) external onlyRole(INTEGRATOR_ROLE) noZeroAddress(newIntegratorFeeRecipient) {
        integratorFeeRecipient = newIntegratorFeeRecipient;

        emit IntegratorFeeRecipientUpdated(newIntegratorFeeRecipient);
    }

    /**
     * @notice Set the developer fee recipient
     * @param newDeveloperFeeRecipient The new developer fee recipient to set
     * @custom:requires DEVELOPER_ROLE
     */
    function setDeveloperFeeRecipient(
        address newDeveloperFeeRecipient
    ) external onlyRole(DEVELOPER_ROLE) noZeroAddress(newDeveloperFeeRecipient) {
        developerFeeRecipient = newDeveloperFeeRecipient;

        emit DeveloperFeeRecipientUpdated(newDeveloperFeeRecipient);
    }

    /**
     * @notice Set the dex/aggregator router to call to perform swaps
     * @param newSwapRouter address of the router
     * @custom:requires DEVELOPER_ROLE
     */
    function setSwapRouter(address newSwapRouter) external onlyRole(DEVELOPER_ROLE) noZeroAddress(newSwapRouter) {
        swapRouter = newSwapRouter;

        emit SwapRouterUpdated(newSwapRouter);
    }

    /**
     * @notice Set the token proxy address to allow to swap tokens
     * @param newTokenTransferAddress address of the token proxy
     * @custom:requires DEVELOPER_ROLE
     */
    function setTokenTransferAddress(
        address newTokenTransferAddress
    ) external onlyRole(DEVELOPER_ROLE) noZeroAddress(newTokenTransferAddress) {
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
     * @param amounts array of amounts to swap
     * @custom:requires KEEPER_ROLE
     */
    function swap(
        address[] calldata tokens,
        bytes[] calldata callDatas,
        uint256[] calldata amounts
    ) public onlyRole(KEEPER_ROLE) {
        address _asset = asset();
        address _strategyAsset = STRATEGY_ASSET;

        uint256 strategyAssetBalance = IERC20(_strategyAsset).balanceOf(address(this));
        uint256 assetBalance = IERC20(_asset).balanceOf(address(this));

        _swap(tokens, callDatas, amounts);

        uint256 newAssetBalance = IERC20(_asset).balanceOf(address(this));
        if (newAssetBalance < assetBalance) {
            revert OutgoingAssets();
        }

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
     * @param amounts array of amounts to swap
     */
    function _swap(address[] calldata tokens, bytes[] calldata callDatas, uint256[] calldata amounts) internal {
        uint256 length = tokens.length;
        for (uint256 i; i < length; ++i) {
            _approveTokenIfNeeded(tokens[i], tokenTransferAddress, amounts[i]);
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
     * @param token address of the token to approve
     * @param spender address of the router/aggregator
     * @param amount amount to approve
     */
    function _approveTokenIfNeeded(address token, address spender, uint256 amount) internal {
        uint256 allowance = IERC20(token).allowance(address(this), spender);
        if (allowance < amount) {
            IERC20(token).safeIncreaseAllowance(spender, amount - allowance);
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
