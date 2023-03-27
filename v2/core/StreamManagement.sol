// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.13;

import { ISablierV2Lockup } from "@sablier/v2-core/interfaces/ISablierV2Lockup.sol";

contract StreamManagement {
    ISablierV2Lockup public immutable sablier;

    constructor(ISablierV2Lockup sablier_) {
        sablier = sablier_;
    }

    // This function can be called by the sender or the recipient
    function cancel(uint256 streamId) external {
        sablier.cancel(streamId);
    }

    // This function can be called only by the sender
    function cancelMultiple(uint256[] calldata streamIds) external {
        sablier.cancelMultiple(streamIds);
    }

    // This function can be called only by the sender
    function renounce(uint256 streamId) external {
        sablier.renounce(streamId);
    }

    // This function can be called by the recipient or an approved NFT operator
    function transfer(uint256 streamId) external {
        sablier.transferFrom({ from: address(this), to: address(0xcafe), tokenId: streamId });
    }

    // This function can be called by the sender, recipient, or an approved NFT operator
    function withdraw(uint256 streamId) external {
        sablier.withdraw({ streamId: streamId, to: address(0xcafe), amount: 1337e18 });
    }

    // This function can be called by the sender, recipient, or an approved NFT operator
    function withdrawMax(uint256 streamId) external {
        sablier.withdrawMax({ streamId: streamId, to: address(0xcafe) });
    }

    // This function can be called by recipient or an approved NFT operator
    function withdrawMultiple(uint256[] calldata streamIds, uint128[] calldata amounts) external {
        sablier.withdrawMultiple({ streamIds: streamIds, to: address(0xcafe), amounts: amounts });
    }
}
