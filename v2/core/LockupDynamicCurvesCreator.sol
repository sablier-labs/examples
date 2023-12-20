// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ud2x18 } from "@prb/math/src/UD2x18.sol";
import { ud60x18 } from "@prb/math/src/UD60x18.sol";
import { ISablierV2LockupDynamic } from "@sablier/v2-core/src/interfaces/ISablierV2LockupDynamic.sol";
import { Broker, LockupDynamic } from "@sablier/v2-core/src/types/DataTypes.sol";

/// @notice Examples of how to create Lockup Dynamic streams with different curve shapes.
/// @dev A visualization of the curve shapes can be found in the docs:
/// https://docs.sablier.com/concepts/protocol/stream-types#lockup-dynamic
/// Visualizing the curves while reviewing this code is recommended. The X axis will be assumed to represent "days".
contract LockupDynamicCurvesCreator {
    // Mainnet addresses
    IERC20 public constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    ISablierV2LockupDynamic public constant LOCKUP_DYNAMIC =
        ISablierV2LockupDynamic(0x7CC7e125d83A581ff438608490Cc0f7bDff79127);

    function createStream_Exponential() external returns (uint256 streamId) {
        // Declare the total amount as 100 DAI
        uint128 totalAmount = 100e18;

        // Transfer the provided amount of DAI tokens to this contract
        DAI.transferFrom(msg.sender, address(this), totalAmount);

        // Approve the Sablier contract to spend DAI
        DAI.approve(address(LOCKUP_DYNAMIC), totalAmount);

        // Declare the params struct
        LockupDynamic.CreateWithDeltas memory params;

        // Declare the function parameters
        params.sender = msg.sender; // The sender will be able to cancel the stream
        params.recipient = address(0xCAFE); // The recipient of the streamed assets
        params.totalAmount = totalAmount; // Total amount is the amount inclusive of all fees
        params.asset = DAI; // The streaming asset
        params.cancelable = true; // Whether the stream will be cancelable or not
        params.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Declare a single-size segment to match the curve shape
        params.segments = new LockupDynamic.SegmentWithDelta[](1);
        params.segments[0] =
            LockupDynamic.SegmentWithDelta({ amount: uint128(totalAmount), delta: 100 days, exponent: ud2x18(6e18) });

        // Create the LockupDynamic stream
        streamId = LOCKUP_DYNAMIC.createWithDeltas(params);
    }

    function createStream_ExponentialCliff() external returns (uint256 streamId) {
        // Declare the total amount as 100 DAI
        uint128 totalAmount = 100e18;

        // Transfer the provided amount of DAI tokens to this contract
        DAI.transferFrom(msg.sender, address(this), totalAmount);

        // Approve the Sablier contract to spend DAI
        DAI.approve(address(LOCKUP_DYNAMIC), totalAmount);

        // Declare the params struct
        LockupDynamic.CreateWithDeltas memory params;

        // Declare the function parameters
        params.sender = msg.sender; // The sender will be able to cancel the stream
        params.recipient = address(0xCAFE); // The recipient of the streamed assets
        params.totalAmount = totalAmount; // Total amount is the amount inclusive of all fees
        params.asset = DAI; // The streaming asset
        params.cancelable = true; // Whether the stream will be cancelable or not
        params.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Declare a three-size segment to match the curve shape
        params.segments = new LockupDynamic.SegmentWithDelta[](3);
        params.segments[0] =
            LockupDynamic.SegmentWithDelta({ amount: 0, delta: 50 days - 1 seconds, exponent: ud2x18(1e18) });
        params.segments[1] = LockupDynamic.SegmentWithDelta({ amount: 20e18, delta: 1 seconds, exponent: ud2x18(1e18) });
        params.segments[2] = LockupDynamic.SegmentWithDelta({ amount: 80e18, delta: 50 days, exponent: ud2x18(6e18) });

        // Create the LockupDynamic stream
        streamId = LOCKUP_DYNAMIC.createWithDeltas(params);
    }

    function createStream_UnlockInSteps() external returns (uint256 streamId) {
        // Declare the total amount as 100 DAI
        uint128 totalAmount = 100e18;

        // Transfer the provided amount of DAI tokens to this contract
        DAI.transferFrom(msg.sender, address(this), totalAmount);

        // Approve the Sablier contract to spend DAI
        DAI.approve(address(LOCKUP_DYNAMIC), totalAmount);

        // Declare the params struct
        LockupDynamic.CreateWithDeltas memory params;

        // Declare the function parameters
        params.sender = msg.sender; // The sender will be able to cancel the stream
        params.recipient = address(0xCAFE); // The recipient of the streamed assets
        params.totalAmount = totalAmount; // Total amount is the amount inclusive of all fees
        params.asset = DAI; // The streaming asset
        params.cancelable = true; // Whether the stream will be cancelable or not
        params.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Declare a twenty-size segment to match the curve shape
        uint256 segmentSize = 20;
        params.segments = new LockupDynamic.SegmentWithDelta[](segmentSize);

        // The even segments are empty and are spaced ~10 days apart
        for (uint256 i = 0; i < segmentSize; i += 2) {
            params.segments[i] =
                LockupDynamic.SegmentWithDelta({ amount: 0, delta: 10 days - 1 seconds, exponent: ud2x18(1e18) });
        }

        // The odd segments are filled and have a delta of 1 second
        uint128 unlockAmount = totalAmount / uint128(segmentSize / 2);
        for (uint256 i = 1; i < segmentSize; i += 2) {
            params.segments[i] =
                LockupDynamic.SegmentWithDelta({ amount: unlockAmount, delta: 1 seconds, exponent: ud2x18(1e18) });
        }

        // Create the LockupDynamic stream
        streamId = LOCKUP_DYNAMIC.createWithDeltas(params);
    }
}
