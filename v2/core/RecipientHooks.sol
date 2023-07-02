// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import { ISablierV2LockupRecipient } from "@sablier/v2-core/interfaces/hooks/ISablierV2LockupRecipient.sol";

contract RecipientHooks is ISablierV2LockupRecipient {
    // Do something after a stream was canceled by the sender.
    function onStreamCanceled(uint256 streamId, uint128 senderAmount, uint128 recipientAmount) external pure {
        // Liquidate the user's position.
        _liquidate({ nftId: streamId });
    }

    // Do something after a stream was renounced by the sender.
    function onStreamRenounced(uint256 streamId) external pure {
        // Update the risk ratio.
        _updateRiskRatio({ nftId: streamId });
    }

    // Do something after the sender or an NFT operator withdrew funds from a stream.
    function onStreamWithdrawn(uint256 streamId, address caller, address to, uint128 amount) external pure {
        // Reduce the user's balance.
        _balances[streamId] -= amount;
    }
}
