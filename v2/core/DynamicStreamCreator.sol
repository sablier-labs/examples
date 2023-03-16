// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.13;

import { ISablierV2LockupDynamic } from "@sablier/v2-core/interfaces/ISablierV2LockupDynamic.sol";
import { Broker, LockupDynamic } from "@sablier/v2-core/types/DataTypes.sol";
import { ud2x18, ud60x18 } from "@sablier/v2-core/types/Math.sol";
import { IERC20 } from "@sablier/v2-core/types/Tokens.sol";

contract DynamicStreamCreator {
    IERC20 public constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    ISablierV2LockupDynamic public immutable sablier;

    constructor(ISablierV2LockupDynamic sablier_) {
        sablier = sablier_;
    }

    // This example assumes
    function createDynamicStream(uint256 amount0, uint256 amount1) external returns (uint256 streamId) {
        // Sum up the DAI amounts
        uint256 totalAmount = amount0 + amount1;

        // Transfer the provided amount of DAI tokens to this contract
        DAI.transferFrom(msg.sender, address(this), totalAmount);

        // Approve the Sablier contract to spend DAI
        DAI.approve(address(sablier), totalAmount);

        // Define some dummy segments
        LockupDynamic.SegmentWithDelta[] memory segments = new LockupDynamic.SegmentWithDelta[](2);
        segments[0] =
            LockupDynamic.Segment({ amount: amount0, exponent: ud2x18(3.14e18), milestone: block.timestamp + 4 weeks });
        segments[1] =
            LockupDynamic.Segment({ amount: amount1, exponent: ud2x18(0.5e18), milestone: block.timestamp + 2 years });

        // Prepare the function parameters
        LockupDynamic.CreateWithMilestones params;
        params.sender = msg.sender; // The sender will be able to cancel the stream
        params.recipient = address(0xcafe); // The recipient of the streamed assets
        params.totalAmount = uint128(totalAmount); // Total amount is the amount inclusive of all fees
        params.asset = DAI; // The streaming asset is DAI
        params.cancelable = false; // Whether the stream will be cancelable or not
        params.startTime = block.timestamp + 100 seconds;
        params.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Create the sablier stream
        streamId = sablier.createWithMilestones(params);
    }
}
