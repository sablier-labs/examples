// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ud60x18 } from "@prb/math/src/UD60x18.sol";
import { ISablierBatchLockup } from "@sablier/lockup/src/interfaces/ISablierBatchLockup.sol";
import { ISablierLockup } from "@sablier/lockup/src/interfaces/ISablierLockup.sol";
import { BatchLockup, Broker, LockupTranched } from "@sablier/lockup/src/types/DataTypes.sol";

contract BatchLTStreamCreator {
    // Sepolia addresses
    IERC20 public constant DAI = IERC20(0x68194a729C2450ad26072b3D33ADaCbcef39D574);
    // See https://docs.sablier.com/guides/lockup/deployments for all deployments
    ISablierLockup public constant LOCKUP = ISablierLockup(0xC2Da366fD67423b500cDF4712BdB41d0995b0794);
    ISablierBatchLockup public constant BATCH_LOCKUP = ISablierBatchLockup(0xd4294579236eE290668c8FdaE9403c4F00D914f0);

    /// @dev For this function to work, the sender must have approved this dummy contract to spend DAI.
    function batchCreateStreams(uint128 perStreamAmount) public returns (uint256[] memory streamIds) {
        // Create a batch of two streams
        uint256 batchSize = 2;

        // Calculate the combined amount of DAI tokens to transfer to this contract
        uint256 transferAmount = perStreamAmount * batchSize;

        // Transfer the provided amount of DAI tokens to this contract
        DAI.transferFrom(msg.sender, address(this), transferAmount);

        // Approve the Batch contract to spend DAI
        DAI.approve({ spender: address(BATCH_LOCKUP), value: transferAmount });

        // Declare the first stream in the batch
        BatchLockup.CreateWithTimestampsLT memory stream0;
        stream0.sender = address(0xABCD); // The sender to stream the tokens, he will be able to cancel the stream
        stream0.recipient = address(0xCAFE); // The recipient of the streamed tokens
        stream0.totalAmount = perStreamAmount; // The total amount of each stream, inclusive of all fees
        stream0.cancelable = true; // Whether the stream will be cancelable or not
        stream0.transferable = false; // Whether the recipient can transfer the NFT or not
        stream0.startTime = uint40(block.timestamp); // Set the start time to block timestamp
        // Declare some dummy tranches
        stream0.tranches = new LockupTranched.Tranche[](2);
        stream0.tranches[0] = LockupTranched.Tranche({
            amount: uint128(perStreamAmount / 2),
            timestamp: uint40(block.timestamp + 1 weeks)
        });
        stream0.tranches[1] = LockupTranched.Tranche({
            amount: uint128(perStreamAmount - stream0.tranches[0].amount),
            timestamp: uint40(block.timestamp + 24 weeks)
        });
        stream0.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Declare the second stream in the batch
        BatchLockup.CreateWithTimestampsLT memory stream1;
        stream1.sender = address(0xABCD); // The sender to stream the tokens, he will be able to cancel the stream
        stream1.recipient = address(0xBEEF); // The recipient of the streamed tokens
        stream1.totalAmount = perStreamAmount; // The total amount of each stream, inclusive of all fees
        stream1.cancelable = false; // Whether the stream will be cancelable or not
        stream1.transferable = false; // Whether the recipient can transfer the NFT or not
        stream1.startTime = uint40(block.timestamp); // Set the start time to block timestamp
        // Declare some dummy tranches
        stream1.tranches = new LockupTranched.Tranche[](2);
        stream1.tranches[0] = LockupTranched.Tranche({
            amount: uint128(perStreamAmount / 4),
            timestamp: uint40(block.timestamp + 4 weeks)
        });
        stream1.tranches[1] = LockupTranched.Tranche({
            amount: uint128(perStreamAmount - stream1.tranches[0].amount),
            timestamp: uint40(block.timestamp + 24 weeks)
        });
        stream1.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Fill the batch array
        BatchLockup.CreateWithTimestampsLT[] memory batch = new BatchLockup.CreateWithTimestampsLT[](batchSize);
        batch[0] = stream0;
        batch[1] = stream1;

        streamIds = BATCH_LOCKUP.createWithTimestampsLT(LOCKUP, DAI, batch);
    }
}
