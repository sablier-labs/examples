// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { ISablierLockupRecipient } from "@sablier/v2-core/src/interfaces/ISablierLockupRecipient.sol";

abstract contract RecipientHooks is ISablierLockupRecipient {
    mapping(address => uint256) internal _balances;

    constructor(address sablierLockup_) {
        sablierLockup = sablierLockup_;
    }

    // Do something after a stream was canceled by the sender.
    function onSablierLockupCancel(
        uint256 streamId,
        uint128, /* senderAmount */
        uint128 /* recipientAmount */
    )
        external
        pure
        returns (bytes4 selector)
    {
        // Check: the caller is the lockup contract.
        if (msg.sender != sablierLockup) {
            revert CallerNotSablierContract(msg.sender, sablierLockup);
        }

        // Liquidate the user's position.
        _liquidate({ nftId: streamId });

        return ISablierLockupRecipient.onSablierLockupCancel.selector;
    }

    // Do something after the sender or an NFT operator withdrew funds from a stream.
    function onSablierLockupWithdraw(
        uint256, /* streamId */
        address caller,
        address, /* to */
        uint128 amount
    )
        external
        returns (bytes4 selector)
    {
        // Reduce the user's balance.
        _balances[caller] -= amount;

        return ISablierLockupRecipient.onSablierLockupWithdraw.selector;
    }

    function _liquidate(uint256 nftId) internal pure { }
    function _updateRiskRatio(uint256 nftId) internal pure { }
}
