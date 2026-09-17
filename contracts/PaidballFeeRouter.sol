// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPaidballFeeRouter} from "./interfaces/IPaidballFeeRouter.sol";
import {PaidballVault} from "./PaidballVault.sol";

/// @title PaidballFeeRouter
/// @author paidball
/// @notice PAID / UsePaid tokens normally route 100% of their trading fee to a
///         single recipient. PAIDBALL rewires that: every fee that flows
///         through this router is split exactly 50/50 between the token's
///         holders (via a pull-based PaidballVault) and a single designated
///         fee recipient — with no custody, no admin key over funds in
///         transit, and no ability to change the split after a token is
///         registered.
///
/// @dev    Design goals, in order:
///           1. The split is immutable per-token and enforced in code, not policy.
///           2. Routing is O(1) regardless of holder count (pull, not push).
///           3. The router never retains a balance between transactions.
contract PaidballFeeRouter is IPaidballFeeRouter {
    uint256 public constant HOLDER_BPS = 5_000; // 50.00%
    uint256 public constant RECIPIENT_BPS = 5_000; // 50.00%
    uint256 public constant BPS_DENOMINATOR = 10_000;

    /// @notice The vault that accrues and distributes the holder-side split.
    PaidballVault public immutable vault;

    /// @dev token => designated fee recipient (the other 50%).
    mapping(address => address) public feeRecipient;

    /// @dev token => the address allowed to register/administer it (its launch authority).
    mapping(address => address) public launchAuthority;

    error AlreadyRegistered(address token);
    error NotAuthorized(address token, address caller);
    error ZeroAddress();
    error ZeroAmount();
    error NativeValueMismatch(uint256 expected, uint256 received);

    constructor(address vault_) {
        if (vault_ == address(0)) revert ZeroAddress();
        vault = PaidballVault(vault_);
    }

    /// @inheritdoc IPaidballFeeRouter
    function registerToken(address token, address feeRecipient_) external {
        if (token == address(0) || feeRecipient_ == address(0)) revert ZeroAddress();
        if (launchAuthority[token] != address(0)) revert AlreadyRegistered(token);

        launchAuthority[token] = msg.sender;
        feeRecipient[token] = feeRecipient_;

        emit RecipientUpdated(token, address(0), feeRecipient_);
    }

    /// @inheritdoc IPaidballFeeRouter
    function routeFee(address token, uint256 amount) external payable {
        if (amount == 0) revert ZeroAmount();
        address recipient = feeRecipient[token];
        if (recipient == address(0)) revert NotAuthorized(token, msg.sender);

        // Split is computed once, on the way in — no rounding drift accrues
        // to either side across the lifetime of the token.
        uint256 toHolders = (amount * HOLDER_BPS) / BPS_DENOMINATOR;
        uint256 toRecipient = amount - toHolders; // remainder absorbs dust, favors recipient by <=1 wei

        if (token == address(0)) {
            if (msg.value != amount) revert NativeValueMismatch(amount, msg.value);
            vault.depositNative{value: toHolders}(token);
            _sendNative(recipient, toRecipient);
        } else {
            _safeTransferFrom(token, msg.sender, address(vault), toHolders);
            vault.notifyDeposit(token, toHolders);
            _safeTransferFrom(token, msg.sender, recipient, toRecipient);
        }

        emit FeeSplit(token, amount, toHolders, toRecipient);
    }

    /// @inheritdoc IPaidballFeeRouter
    function feeRecipientOf(address token) external view returns (address) {
        return feeRecipient[token];
    }

    /// @notice Allows a token's launch authority to redirect its 50% recipient
    ///         share. The holder side can never be redirected — it is
    ///         hardcoded to flow through the vault.
    function setFeeRecipient(address token, address newRecipient) external {
        if (msg.sender != launchAuthority[token]) revert NotAuthorized(token, msg.sender);
        if (newRecipient == address(0)) revert ZeroAddress();

        address old = feeRecipient[token];
        feeRecipient[token] = newRecipient;
        emit RecipientUpdated(token, old, newRecipient);
    }

    function _sendNative(address to, uint256 amount) private {
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "PAIDBALL: native transfer failed");
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) private {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", from, to, amount)
        );
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "PAIDBALL: transferFrom failed");
    }
}
