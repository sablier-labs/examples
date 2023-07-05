// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { ISablierV2LockupDynamic } from "@sablier/v2-core/interfaces/ISablierV2LockupDynamic.sol";
import { Broker, LockupDynamic } from "@sablier/v2-core/types/DataTypes.sol";
import { ud2x18, ud60x18 } from "@sablier/v2-core/types/Math.sol";
import { IERC20 } from "@sablier/v2-core/types/Tokens.sol";

/// @notice Example of how to create a Lockup Dynamic stream.
/// @dev This code is referenced in the docs: https://docs.sablier.com/contracts/v2/guides/create-stream/lockup-dynamic
contract LockupDynamicStreamCreator {
    IERC20 public constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    ISablierV2LockupDynamic public immutable sablier;

    constructor(ISablierV2LockupDynamic sablier_) {
        sablier = sablier_;
    }

    function createLockupDynamicStream(uint256 amount0, uint256 amount1) public returns (uint256 streamId) {
        // Sum up the segment amounts
        uint256 totalAmount = amount0 + amount1;

        // Transfer the provided amount of DAI tokens to this contract
        DAI.transferFrom(msg.sender, address(this), totalAmount);

        // Approve the Sablier contract to spend DAI
        DAI.approve(address(sablier), totalAmount);

        // Declare the params struct
        LockupDynamic.CreateWithMilestones params;

        // Declare the function parameters
        params.sender = msg.sender; // The sender will be able to cancel the stream
        params.recipient = address(0xcafe); // The recipient of the streamed assets
        params.totalAmount = uint128(totalAmount); // Total amount is the amount inclusive of all fees
        params.asset = DAI; // The streaming asset
        params.cancelable = true; // Whether the stream will be cancelable or not
        params.startTime = block.timestamp + 100 seconds;
        params.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Declare some dummy segments
        params.segments = new LockupDynamic.Segment[](2);
        params.segments[0] = LockupDynamic.Segment({
            amount: uint128(amount0),
            exponent: ud2x18(1e18),
            milestone: uint40(block.timestamp + 4 weeks)
        });
        params.segments[1] = (
            LockupDynamic.Segment({
                amount: uint128(amount1),
                exponent: ud2x18(3.14e18),
                milestone: uint40(block.timestamp + 52 weeks)
            })
        );

        // Create the Sablier stream
        streamId = sablier.createWithMilestones(params);
    }
}
