// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import { ISablierV2LockupRecipient } from "@sablier/v2-core/src/interfaces/hooks/ISablierV2LockupRecipient.sol";

abstract contract RecipientHooks is ISablierV2LockupRecipient {
    error CallerNotSablierContract(address caller, address sablierContract);

    address public immutable sablierLockup;

    mapping(address => uint256) internal _balances;

    constructor(address sablierLockup_) {
        sablierLockup = sablierLockup_;
    }

    // Do something after a stream was canceled by the sender.
    function onStreamCanceled(
        uint256 streamId,
        uint128, /* senderAmount */
        uint128 /* recipientAmount */
    )
        external
        view
    {
        // Check: the caller is the lockup contract.
        if (msg.sender != sablierLockup) {
            revert CallerNotSablierContract(msg.sender, sablierLockup);
        }

        // Liquidate the user's position.
        _liquidate({ nftId: streamId });
    }

    // Do something after a stream was renounced by the sender.
    function onStreamRenounced(uint256 streamId) external view {
        // Check: the caller is the lockup contract.
        if (msg.sender != sablierLockup) {
            revert CallerNotSablierContract(msg.sender, sablierLockup);
        }

        // Update the risk ratio.
        _updateRiskRatio({ nftId: streamId });
    }

    // Do something after the sender or an NFT operator withdrew funds from a stream.
    function onStreamWithdrawn(uint256, /* streamId */ address caller, address, /* to */ uint128 amount) external {
        // Check: the caller is the lockup contract.
        if (msg.sender != sablierLockup) {
            revert CallerNotSablierContract(msg.sender, sablierLockup);
        }

        // Reduce the user's balance.
        _balances[caller] -= amount;
    }

    function _liquidate(uint256 nftId) internal pure { }
    function _updateRiskRatio(uint256 nftId) internal pure { }
}
