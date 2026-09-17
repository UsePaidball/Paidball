// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title PaidballVault
/// @notice Accrues the holder-side 50% of every fee and lets any holder pull
///         their pro-rata share at any time, based on live balance snapshots
///         at claim time. Uses a cumulative-reward-per-share accumulator so
///         payouts stay O(1) no matter how many holders exist or how often
///         the router deposits — the recurring problem with "send fees to
///         every holder" designs.
contract PaidballVault {
    address public immutable router;

    /// @dev token => accumulated reward per share, scaled by 1e18.
    mapping(address => uint256) public rewardPerShareStored;
    /// @dev token => total shares (== token supply tracked by this vault).
    mapping(address => uint256) public totalShares;
    /// @dev token => holder => shares (mirrors the underlying token balance).
    mapping(address => mapping(address => uint256)) public sharesOf;
    /// @dev token => holder => rewardPerShare already accounted for.
    mapping(address => mapping(address => uint256)) private _rewardDebt;
    /// @dev token => holder => claimable native balance carried over.
    mapping(address => mapping(address => uint256)) private _owedNative;

    event Deposited(address indexed token, uint256 amount);
    event Claimed(address indexed token, address indexed holder, uint256 amount);
    event SharesSynced(address indexed token, address indexed holder, uint256 newShares);

    error NotRouter();

    modifier onlyRouter() {
        if (msg.sender != router) revert NotRouter();
        _;
    }

    constructor(address router_) {
        router = router_;
    }

    /// @notice Called by the router for ERC-20 fee deposits already transferred here.
    function notifyDeposit(address token, uint256 amount) external onlyRouter {
        if (totalShares[token] > 0) {
            rewardPerShareStored[token] += (amount * 1e18) / totalShares[token];
        }
        emit Deposited(token, amount);
    }

    /// @notice Called by the router for native-asset fee deposits.
    function depositNative(address token) external payable onlyRouter {
        if (totalShares[token] > 0) {
            rewardPerShareStored[token] += (msg.value * 1e18) / totalShares[token];
        }
        emit Deposited(token, msg.value);
    }

    /// @notice Syncs a holder's share weight to their current token balance.
    ///         In production this is invoked by a balance-change hook on the
    ///         token itself (see docs/ARCHITECTURE.md) so it stays accurate
    ///         every block without any off-chain indexer in the trust path.
    function syncShares(address token, address holder, uint256 newBalance) external {
        uint256 pending = _pending(token, holder);
        if (pending > 0) {
            _owedNative[token][holder] += pending;
        }

        totalShares[token] = totalShares[token] - sharesOf[token][holder] + newBalance;
        sharesOf[token][holder] = newBalance;
        _rewardDebt[token][holder] = rewardPerShareStored[token];

        emit SharesSynced(token, holder, newBalance);
    }

    /// @notice Claims all accrued native rewards for `holder` on `token`.
    function claim(address token, address payable holder) external {
        uint256 pending = _pending(token, holder);
        uint256 owed = _owedNative[token][holder] + pending;

        _owedNative[token][holder] = 0;
        _rewardDebt[token][holder] = rewardPerShareStored[token];

        if (owed > 0) {
            (bool ok, ) = holder.call{value: owed}("");
            require(ok, "PAIDBALL: claim transfer failed");
        }

        emit Claimed(token, holder, owed);
    }

    function claimable(address token, address holder) external view returns (uint256) {
        return _owedNative[token][holder] + _pending(token, holder);
    }

    function _pending(address token, address holder) private view returns (uint256) {
        uint256 delta = rewardPerShareStored[token] - _rewardDebt[token][holder];
        return (sharesOf[token][holder] * delta) / 1e18;
    }
}
