// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IPaidballFeeRouter
/// @notice Minimal interface for a PAIDBALL fee router: a stateless, non-custodial
///         splitter that sits between a PAID/UsePaid token's fee hook and its
///         two payout destinations.
interface IPaidballFeeRouter {
    /// @dev Emitted every time a fee payment is received and split.
    /// @param token The token that generated the fee (address(0) for native asset).
    /// @param amount Total amount routed in this call, pre-split.
    /// @param toHolders Amount forwarded to the holder distributor.
    /// @param toRecipient Amount forwarded to the designated fee recipient.
    event FeeSplit(address indexed token, uint256 amount, uint256 toHolders, uint256 toRecipient);

    /// @dev Emitted when a token's fee recipient is set or changed.
    event RecipientUpdated(address indexed token, address indexed oldRecipient, address indexed newRecipient);

    /// @notice Routes an incoming fee payment for `token`, splitting it 50/50
    ///         between the holder distributor and the configured fee recipient.
    /// @dev MUST be called with `msg.value == amount` when `token == address(0)`.
    ///      MUST pull `amount` of `token` via transferFrom otherwise.
    function routeFee(address token, uint256 amount) external payable;

    /// @notice Registers a token with PAIDBALL and sets its fee recipient.
    ///         Callable once per token by the token's launch authority.
    function registerToken(address token, address feeRecipient) external;

    /// @notice Returns the configured fee recipient for a token.
    function feeRecipientOf(address token) external view returns (address);
}
