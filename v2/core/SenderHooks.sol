// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import { ISablierV2LockupSender } from "@sablier/v2-core/interfaces/hooks/ISablierV2LockupSender.sol";

contract SenderHooks is ISablierV2LockupSender {
    // Do something after a stream was canceled by the recipient.
    function onStreamCanceled(uint256 streamId, uint128 senderAmount, uint128 recipientAmount) external pure {
        // Record the received amount (canceling a stream auto-refunds the unstreamed funds back to the sender).
        balance += senderAmount;
    }
}
