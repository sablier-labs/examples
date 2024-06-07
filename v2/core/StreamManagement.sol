// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { ISablierV2Lockup } from "@sablier/v2-core/src/interfaces/ISablierV2Lockup.sol";

/// @notice Examples of how to manage Sablier streams after they have been created.
/// @dev This code is referenced in the docs: https://docs.sablier.com/contracts/v2/guides/stream-management/setup
contract StreamManagement {
    ISablierV2Lockup public immutable sablier;

    constructor(ISablierV2Lockup sablier_) {
        sablier = sablier_;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    02-WITHDRAW
    //////////////////////////////////////////////////////////////////////////*/

    // This function can be called by the sender, recipient, or an approved NFT operator
    function withdraw(uint256 streamId) external {
        sablier.withdraw({ streamId: streamId, to: address(0xcafe), amount: 1337e18 });
    }

    // This function can be called by the sender, recipient, or an approved NFT operator
    function withdrawMax(uint256 streamId) external {
        sablier.withdrawMax({ streamId: streamId, to: address(0xcafe) });
    }

    // This function can be called by either the recipient or an approved NFT operator
    function withdrawMultiple(uint256[] calldata streamIds, uint128[] calldata amounts) external {
        sablier.withdrawMultiple({ streamIds: streamIds, amounts: amounts });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     03-CANCEL
    //////////////////////////////////////////////////////////////////////////*/

    // This function can be called by either the sender or the recipient
    function cancel(uint256 streamId) external {
        sablier.cancel(streamId);
    }

    // This function can be called only by the sender
    function cancelMultiple(uint256[] calldata streamIds) external {
        sablier.cancelMultiple(streamIds);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    04-RENOUNCE
    //////////////////////////////////////////////////////////////////////////*/

    // This function can be called only by the sender
    function renounce(uint256 streamId) external {
        sablier.renounce(streamId);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    05-TRANSFER
    //////////////////////////////////////////////////////////////////////////*/

    // This function can be called by either the recipient or an approved NFT operator
    function safeTransferFrom(uint256 streamId) external {
        sablier.safeTransferFrom({ from: address(this), to: address(0xcafe), tokenId: streamId });
    }

    // This function can be called by either the recipient or an approved NFT operator
    function transferFrom(uint256 streamId) external {
        sablier.transferFrom({ from: address(this), to: address(0xcafe), tokenId: streamId });
    }

    // This function can be called only by the recipient
    function withdrawMaxAndTransfer(uint256 streamId) external {
        sablier.withdrawMaxAndTransfer({ streamId: streamId, newRecipient: address(0xcafe) });
    }
}
