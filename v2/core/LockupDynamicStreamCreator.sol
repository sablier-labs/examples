// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ud2x18 } from "@prb/math/src/UD2x18.sol";
import { ud60x18 } from "@prb/math/src/UD60x18.sol";
import { ISablierV2LockupDynamic } from "@sablier/v2-core/src/interfaces/ISablierV2LockupDynamic.sol";
import { Broker, LockupDynamic } from "@sablier/v2-core/src/types/DataTypes.sol";

/// @notice Example of how to create a Lockup Dynamic stream.
/// @dev This code is referenced in the docs: https://docs.sablier.com/contracts/v2/guides/create-stream/lockup-dynamic
contract LockupDynamicStreamCreator {
    // Mainnet addresses
    IERC20 public constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    ISablierV2LockupDynamic public constant LOCKUP_DYNAMIC =
        ISablierV2LockupDynamic(0x3C7Cd8bE42489252CbCc6dC94a17F7f4ec74437E);

    function createStream(uint128 amount0, uint128 amount1) public returns (uint256 streamId) {
        // Sum the segment amounts
        uint256 totalAmount = amount0 + amount1;

        // Transfer the provided amount of DAI tokens to this contract
        DAI.transferFrom(msg.sender, address(this), totalAmount);

        // Approve the Sablier contract to spend DAI
        DAI.approve(address(LOCKUP_DYNAMIC), totalAmount);

        // Declare the params struct
        LockupDynamic.CreateWithMilestones memory params;

        // Declare the function parameters
        params.sender = msg.sender; // The sender will be able to cancel the stream
        params.recipient = address(0xCAFE); // The recipient of the streamed assets
        params.totalAmount = uint128(totalAmount); // Total amount is the amount inclusive of all fees
        params.asset = DAI; // The streaming asset
        params.cancelable = true; // Whether the stream will be cancelable or not
        params.startTime = uint40(block.timestamp + 100 seconds);
        params.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Declare some dummy segments
        params.segments = new LockupDynamic.Segment[](2);
        params.segments[0] = LockupDynamic.Segment({
            amount: amount0,
            exponent: ud2x18(1e18),
            milestone: uint40(block.timestamp + 4 weeks)
        });
        params.segments[1] = (
            LockupDynamic.Segment({
                amount: amount1,
                exponent: ud2x18(3.14e18),
                milestone: uint40(block.timestamp + 52 weeks)
            })
        );

        // Create the LockupDynamic stream
        streamId = LOCKUP_DYNAMIC.createWithMilestones(params);
    }
}
