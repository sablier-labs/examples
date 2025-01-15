// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ud2x18 } from "@prb/math/src/UD2x18.sol";
import { ud60x18 } from "@prb/math/src/UD60x18.sol";
import { ISablierLockup } from "@sablier/lockup/src/interfaces/ISablierLockup.sol";
import { Broker, Lockup, LockupDynamic } from "@sablier/lockup/src/types/DataTypes.sol";

/// @notice Examples of how to create Lockup Dynamic streams with different curve shapes.
/// @dev A visualization of the curve shapes can be found in the docs:
/// https://docs.sablier.com/concepts/protocol/stream-types#lockup-dynamic
/// Visualizing the curves while reviewing this code is recommended. The X axis will be assumed to represent "days".
contract LockupDynamicCurvesCreator {
    // Sepolia addresses
    IERC20 public constant DAI = IERC20(0x68194a729C2450ad26072b3D33ADaCbcef39D574);
    ISablierLockup public constant LOCKUP = ISablierLockup(0xC2Da366fD67423b500cDF4712BdB41d0995b0794);

    /// @dev For this function to work, the sender must have approved this dummy contract to spend DAI.
    function createStream_Exponential() external returns (uint256 streamId) {
        // Declare the total amount as 100 DAI
        uint128 totalAmount = 100e18;

        // Transfer the provided amount of DAI tokens to this contract
        DAI.transferFrom(msg.sender, address(this), totalAmount);

        // Approve the Sablier contract to spend DAI
        DAI.approve(address(LOCKUP), totalAmount);

        // Declare the params struct
        Lockup.CreateWithDurations memory params;

        // Declare the function parameters
        params.sender = msg.sender; // The sender will be able to cancel the stream
        params.recipient = address(0xCAFE); // The recipient of the streamed tokens
        params.totalAmount = totalAmount; // Total amount is the amount inclusive of all fees
        params.token = DAI; // The streaming token
        params.cancelable = true; // Whether the stream will be cancelable or not
        params.transferable = true; // Whether the stream will be transferable or not
        params.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Declare a single-size segment to match the curve shape
        LockupDynamic.SegmentWithDuration[] memory segments = new LockupDynamic.SegmentWithDuration[](1);
        segments[0] = LockupDynamic.SegmentWithDuration({
            amount: uint128(totalAmount),
            duration: 100 days,
            exponent: ud2x18(6e18)
        });

        // Create the LockupDynamic stream
        streamId = LOCKUP.createWithDurationsLD(params, segments);
    }

    function createStream_ExponentialCliff() external returns (uint256 streamId) {
        // Declare the total amount as 100 DAI
        uint128 totalAmount = 100e18;

        // Transfer the provided amount of DAI tokens to this contract
        DAI.transferFrom(msg.sender, address(this), totalAmount);

        // Approve the Sablier contract to spend DAI
        DAI.approve(address(LOCKUP), totalAmount);

        // Declare the params struct
        Lockup.CreateWithDurations memory params;

        // Declare the function parameters
        params.sender = msg.sender; // The sender will be able to cancel the stream
        params.recipient = address(0xCAFE); // The recipient of the streamed tokens
        params.totalAmount = totalAmount; // Total amount is the amount inclusive of all fees
        params.token = DAI; // The streaming token
        params.cancelable = true; // Whether the stream will be cancelable or not
        params.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Declare a three-size segment to match the curve shape
        LockupDynamic.SegmentWithDuration[] memory segments = new LockupDynamic.SegmentWithDuration[](3);
        segments[0] =
            LockupDynamic.SegmentWithDuration({ amount: 0, duration: 50 days - 1 seconds, exponent: ud2x18(1e18) });
        segments[1] = LockupDynamic.SegmentWithDuration({ amount: 20e18, duration: 1 seconds, exponent: ud2x18(1e18) });
        segments[2] = LockupDynamic.SegmentWithDuration({ amount: 80e18, duration: 50 days, exponent: ud2x18(6e18) });

        // Create the LockupDynamic stream
        streamId = LOCKUP.createWithDurationsLD(params, segments);
    }

    function createStream_UnlockInSteps() external returns (uint256 streamId) {
        // Declare the total amount as 100 DAI
        uint128 totalAmount = 100e18;

        // Transfer the provided amount of DAI tokens to this contract
        DAI.transferFrom(msg.sender, address(this), totalAmount);

        // Approve the Sablier contract to spend DAI
        DAI.approve(address(LOCKUP), totalAmount);

        // Declare the params struct
        Lockup.CreateWithDurations memory params;

        // Declare the function parameters
        params.sender = msg.sender; // The sender will be able to cancel the stream
        params.recipient = address(0xCAFE); // The recipient of the streamed tokens
        params.totalAmount = totalAmount; // Total amount is the amount inclusive of all fees
        params.token = DAI; // The streaming token
        params.cancelable = true; // Whether the stream will be cancelable or not
        params.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Declare a eight-size segment to match the curve shape
        uint256 segmentSize = 8;
        LockupDynamic.SegmentWithDuration[] memory segments = new LockupDynamic.SegmentWithDuration[](segmentSize);

        // The even segments are empty and are spaced ~25 days apart
        for (uint256 i = 0; i < segmentSize; i += 2) {
            segments[i] =
                LockupDynamic.SegmentWithDuration({ amount: 0, duration: 25 days - 1 seconds, exponent: ud2x18(1e18) });
        }

        // The odd segments are filled and have a delta of 1 second
        uint128 unlockAmount = totalAmount / uint128(segmentSize / 2);
        for (uint256 i = 1; i < segmentSize; i += 2) {
            segments[i] =
                LockupDynamic.SegmentWithDuration({ amount: unlockAmount, duration: 1 seconds, exponent: ud2x18(1e18) });
        }

        // Create the LockupDynamic stream
        streamId = LOCKUP.createWithDurationsLD(params, segments);
    }

    function createStream_MonthlyUnlocks() external returns (uint256 streamId) {
        // Declare the total amount as 120 DAI
        uint128 totalAmount = 120e18;

        // Transfer the provided amount of DAI tokens to this contract
        DAI.transferFrom(msg.sender, address(this), totalAmount);

        // Approve the Sablier contract to spend DAI
        DAI.approve(address(LOCKUP), totalAmount);

        // Declare the params struct
        Lockup.CreateWithDurations memory params;

        // Declare the function parameters
        params.sender = msg.sender; // The sender will be able to cancel the stream
        params.recipient = address(0xCAFE); // The recipient of the streamed tokens
        params.totalAmount = totalAmount; // Total amount is the amount inclusive of all fees
        params.token = DAI; // The streaming token
        params.cancelable = true; // Whether the stream will be cancelable or not
        params.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Declare a twenty four size segment to match the curve shape
        uint256 segmentSize = 24;
        LockupDynamic.SegmentWithDuration[] memory segments = new LockupDynamic.SegmentWithDuration[](segmentSize);

        // The even segments are empty and are spaced 30 days apart (~one month)
        for (uint256 i = 0; i < segmentSize; i += 2) {
            segments[i] =
                LockupDynamic.SegmentWithDuration({ amount: 0, duration: 30 days - 1 seconds, exponent: ud2x18(1e18) });
        }

        // The odd segments are filled and have a delta of 1 second
        uint128 unlockAmount = totalAmount / uint128(segmentSize / 2);
        for (uint256 i = 1; i < segmentSize; i += 2) {
            segments[i] =
                LockupDynamic.SegmentWithDuration({ amount: unlockAmount, duration: 1 seconds, exponent: ud2x18(1e18) });
        }

        // Create the LockupDynamic stream
        streamId = LOCKUP.createWithDurationsLD(params, segments);
    }

    function createStream_Timelock() external returns (uint256 streamId) {
        // Declare the total amount as 100 DAI
        uint128 totalAmount = 100e18;

        // Transfer the provided amount of DAI tokens to this contract
        DAI.transferFrom(msg.sender, address(this), totalAmount);

        // Approve the Sablier contract to spend DAI
        DAI.approve(address(LOCKUP), totalAmount);

        // Declare the params struct
        Lockup.CreateWithDurations memory params;

        // Declare the function parameters
        params.sender = msg.sender; // The sender will be able to cancel the stream
        params.recipient = address(0xCAFE); // The recipient of the streamed tokens
        params.totalAmount = totalAmount; // Total amount is the amount inclusive of all fees
        params.token = DAI; // The streaming token
        params.cancelable = true; // Whether the stream will be cancelable or not
        params.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Declare a two-size segment to match the curve shape
        LockupDynamic.SegmentWithDuration[] memory segments = new LockupDynamic.SegmentWithDuration[](2);
        segments[0] =
            LockupDynamic.SegmentWithDuration({ amount: 0, duration: 90 days - 1 seconds, exponent: ud2x18(1e18) });
        segments[1] = LockupDynamic.SegmentWithDuration({ amount: 100e18, duration: 1 seconds, exponent: ud2x18(1e18) });

        // Create the LockupDynamic stream
        streamId = LOCKUP.createWithDurationsLD(params, segments);
    }

    function createStream_UnlockLinear() external returns (uint256 streamId) {
        // Declare the total amount as 100 DAI
        uint128 totalAmount = 100e18;

        // Transfer the provided amount of DAI tokens to this contract
        DAI.transferFrom(msg.sender, address(this), totalAmount);

        // Approve the Sablier contract to spend DAI
        DAI.approve(address(LOCKUP), totalAmount);

        // Declare the params struct
        Lockup.CreateWithDurations memory params;

        // Declare the function parameters
        params.sender = msg.sender; // The sender will be able to cancel the stream
        params.recipient = address(0xCAFE); // The recipient of the streamed tokens
        params.totalAmount = totalAmount; // Total amount is the amount inclusive of all fees
        params.token = DAI; // The streaming token
        params.cancelable = true; // Whether the stream will be cancelable or not
        params.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Declare a two-size segment to match the curve shape
        LockupDynamic.SegmentWithDuration[] memory segments = new LockupDynamic.SegmentWithDuration[](2);
        segments[0] = LockupDynamic.SegmentWithDuration({ amount: 25e18, duration: 1 seconds, exponent: ud2x18(1e18) });
        segments[1] =
            LockupDynamic.SegmentWithDuration({ amount: 75e18, duration: 100 days - 1 days, exponent: ud2x18(1e18) });

        // Create the LockupDynamic stream
        streamId = LOCKUP.createWithDurationsLD(params, segments);
    }

    function createStream_UnlockCliffLinear() external returns (uint256 streamId) {
        // Declare the total amount as 100 DAI
        uint128 totalAmount = 100e18;

        // Transfer the provided amount of DAI tokens to this contract
        DAI.transferFrom(msg.sender, address(this), totalAmount);

        // Approve the Sablier contract to spend DAI
        DAI.approve(address(LOCKUP), totalAmount);

        // Declare the params struct
        Lockup.CreateWithDurations memory params;

        // Declare the function parameters
        params.sender = msg.sender; // The sender will be able to cancel the stream
        params.recipient = address(0xCAFE); // The recipient of the streamed tokens
        params.totalAmount = totalAmount; // Total amount is the amount inclusive of all fees
        params.token = DAI; // The streaming token
        params.cancelable = true; // Whether the stream will be cancelable or not
        params.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Declare a four-size segment to match the curve shape
        LockupDynamic.SegmentWithDuration[] memory segments = new LockupDynamic.SegmentWithDuration[](4);
        segments[0] = LockupDynamic.SegmentWithDuration({ amount: 25e18, duration: 1 seconds, exponent: ud2x18(1e18) });
        segments[1] =
            LockupDynamic.SegmentWithDuration({ amount: 0, duration: 50 days - 1 seconds, exponent: ud2x18(1e18) });
        segments[2] = LockupDynamic.SegmentWithDuration({ amount: 25e18, duration: 1 seconds, exponent: ud2x18(1e18) });
        segments[3] = LockupDynamic.SegmentWithDuration({ amount: 50e18, duration: 50 days, exponent: ud2x18(1e18) });

        // Create the LockupDynamic stream
        streamId = LOCKUP.createWithDurationsLD(params, segments);
    }
}
