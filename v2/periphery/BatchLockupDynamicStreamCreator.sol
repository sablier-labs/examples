// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ud2x18 } from "@prb/math/src/UD2x18.sol";
import { ud60x18 } from "@prb/math/src/UD60x18.sol";
import { ISablierV2LockupDynamic } from "@sablier/v2-core/src/interfaces/ISablierV2LockupDynamic.sol";
import { ISablierV2Batch } from "@sablier/v2-periphery/src/interfaces/ISablierV2Batch.sol";
import { Batch, Broker, LockupDynamic } from "@sablier/v2-periphery/src/types/DataTypes.sol";

contract BatchLockupDynamicStreamCreator {
    // Mainnet addresses
    IERC20 public constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    // See https://docs.sablier.com/contracts/v2/deployments for all deployments
    ISablierV2Batch public constant BATCH = ISablierV2Batch(0xEa07DdBBeA804E7fe66b958329F8Fa5cDA95Bd55);
    ISablierV2LockupDynamic public constant LOCKUP_DYNAMIC =
        ISablierV2LockupDynamic(0x7CC7e125d83A581ff438608490Cc0f7bDff79127);

    function batchCreateStreams(uint128 perStreamAmount) public returns (uint256[] memory streamIds) {
        // Create a batch of two streams
        uint256 batchSize = 2;

        // Calculate the combined amount of DAI assets to transfer to this contract
        uint256 transferAmount = perStreamAmount * batchSize;

        // Transfer the provided amount of DAI tokens to this contract
        DAI.transferFrom(msg.sender, address(this), transferAmount);

        // Approve the Batch contract to spend DAI
        DAI.approve({ spender: address(BATCH), amount: transferAmount });

        // Declare the first stream in the batch
        Batch.CreateWithMilestones memory stream0;
        stream0.sender = address(0xABCD); // The sender to stream the assets, he will be able to cancel the stream
        stream0.recipient = address(0xCAFE); // The recipient of the streamed assets
        stream0.totalAmount = perStreamAmount; // The total amount of each stream, inclusive of all fees
        stream0.cancelable = true; // Whether the stream will be cancelable or not
        stream0.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Declare some dummy segments
        stream0.segments = new LockupDynamic.Segment[](2);
        stream0.segments[0] = LockupDynamic.Segment({
            amount: uint128(perStreamAmount / 2),
            exponent: ud2x18(0.25e18),
            milestone: uint40(block.timestamp + 1 weeks)
        });
        stream0.segments[1] = (
            LockupDynamic.Segment({
                amount: uint128(perStreamAmount - stream0.segments[0].amount),
                exponent: ud2x18(2.71e18),
                milestone: uint40(block.timestamp + 24 weeks)
            })
        );

        // Declare the second stream in the batch
        Batch.CreateWithMilestones memory stream1;
        stream1.sender = address(0xABCD); // The sender to stream the assets, he will be able to cancel the stream
        stream1.recipient = address(0xBEEF); // The recipient of the streamed assets
        stream1.totalAmount = uint128(perStreamAmount); // The total amount of each stream, inclusive of all fees
        stream1.cancelable = false; // Whether the stream will be cancelable or not
        stream1.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Declare some dummy segments
        stream1.segments = new LockupDynamic.Segment[](2);
        stream1.segments[0] = LockupDynamic.Segment({
            amount: uint128(perStreamAmount / 4),
            exponent: ud2x18(1e18),
            milestone: uint40(block.timestamp + 4 weeks)
        });
        stream1.segments[1] = (
            LockupDynamic.Segment({
                amount: uint128(perStreamAmount - stream1.segments[0].amount),
                exponent: ud2x18(3.14e18),
                milestone: uint40(block.timestamp + 52 weeks)
            })
        );

        // Fill the batch array
        Batch.CreateWithMilestones[] memory batch = new Batch.CreateWithMilestones[](batchSize);
        batch[0] = stream0;
        batch[1] = stream1;

        streamIds = BATCH.createWithMilestones(LOCKUP_DYNAMIC, DAI, batch);
    }
}
