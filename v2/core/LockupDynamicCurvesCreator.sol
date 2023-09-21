// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { ISablierV2LockupDynamic } from "@sablier/v2-core/src/interfaces/ISablierV2LockupDynamic.sol";
import { Broker, LockupDynamic } from "@sablier/v2-core/src/types/DataTypes.sol";
import { ud2x18, ud60x18 } from "@sablier/v2-core/src/types/Math.sol";
import { IERC20 } from "@sablier/v2-core/src/types/Tokens.sol";

/// @notice Example of how to create a Lockup Dynamic stream with different curve shapes.
// forgefmt: disable-next-line
/// @dev The exact curve shapes can be found in the docs: https://docs.sablier.com/concepts/protocol/stream-types#lockup-dynamic
contract LockupDynamicCurvesCreator {
    // Mainnet addresses
    IERC20 public constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    ISablierV2LockupDynamic public constant lockupDynamic =
        ISablierV2LockupDynamic(0x39EFdC3dbB57B2388CcC4bb40aC4CB1226Bc9E44);

    function createLockupDynamicStream_Exponential() external returns (uint256 streamId) {
        // Declare the total amount as 100 DAI
        uint128 totalAmount = 100e18;

        // Transfer the provided amount of DAI tokens to this contract
        DAI.transferFrom(msg.sender, address(this), totalAmount);

        // Approve the Sablier contract to spend DAI
        DAI.approve(address(lockupDynamic), totalAmount);

        // Declare the params struct
        LockupDynamic.CreateWithDeltas memory params;

        // Declare the function parameters
        params.sender = msg.sender; // The sender will be able to cancel the stream
        params.recipient = address(0xcafe); // The recipient of the streamed assets
        params.totalAmount = totalAmount; // Total amount is the amount inclusive of all fees
        params.asset = DAI; // The streaming asset
        params.cancelable = true; // Whether the stream will be cancelable or not
        params.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Declare a single-size segment to match the curve
        params.segments = new LockupDynamic.SegmentWithDelta[](1);
        params.segments[0] =
            LockupDynamic.SegmentWithDelta({ amount: uint128(totalAmount), delta: 100 days, exponent: ud2x18(6e18) });

        // Create the Sablier stream
        streamId = lockupDynamic.createWithDeltas(params);
    }

    function createLockupDynamicStream_ExponentialCliff() external returns (uint256 streamId) {
        // Declare the total amount as 100 DAI
        uint128 totalAmount = 100e18;

        // Transfer the provided amount of DAI tokens to this contract
        DAI.transferFrom(msg.sender, address(this), totalAmount);

        // Approve the Sablier contract to spend DAI
        DAI.approve(address(lockupDynamic), totalAmount);

        // Declare the params struct
        LockupDynamic.CreateWithDeltas memory params;

        // Declare the function parameters
        params.sender = msg.sender; // The sender will be able to cancel the stream
        params.recipient = address(0xcafe); // The recipient of the streamed assets
        params.totalAmount = totalAmount; // Total amount is the amount inclusive of all fees
        params.asset = DAI; // The streaming asset
        params.cancelable = true; // Whether the stream will be cancelable or not
        params.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Declare a three-size segment to match the curve
        params.segments = new LockupDynamic.SegmentWithDelta[](3);
        params.segments[0] =
            LockupDynamic.SegmentWithDelta({ amount: 0, delta: 50 days - 1 seconds, exponent: ud2x18(1e18) });
        params.segments[1] = LockupDynamic.SegmentWithDelta({ amount: 20e18, delta: 1 seconds, exponent: ud2x18(1e18) });
        params.segments[2] = LockupDynamic.SegmentWithDelta({ amount: 80e18, delta: 50 days, exponent: ud2x18(6e18) });

        // Create the Sablier stream
        streamId = lockupDynamic.createWithDeltas(params);
    }
}
