// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ud60x18 } from "@prb/math/src/UD60x18.sol";
import { ISablierV2LockupTranched } from "@sablier/v2-core/src/interfaces/ISablierV2LockupTranched.sol";
import { Broker, LockupTranched } from "@sablier/v2-core/src/types/DataTypes.sol";
import { ISablierV2BatchLockup } from "@sablier/v2-periphery/src/interfaces/ISablierV2BatchLockup.sol";
import { BatchLockup } from "@sablier/v2-periphery/src/types/DataTypes.sol";

contract BatchLTStreamCreator {
    // Sepolia addresses
    IERC20 public constant DAI = IERC20(0x68194a729C2450ad26072b3D33ADaCbcef39D574);
    // See https://docs.sablier.com/contracts/v2/deployments for all deployments
    ISablierV2LockupTranched public constant LOCKUP_TRANCHED =
        ISablierV2LockupTranched(0x3a1beA13A8C24c0EA2b8fAE91E4b2762A59D7aF5);
    ISablierV2BatchLockup public constant BATCH_LOCKUP =
        ISablierV2BatchLockup(0x04A9c14b7a000640419aD5515Db4eF4172C00E31);

    /// @dev For this function to work, the sender must have approved this dummy contract to spend DAI.
    function batchCreateStreams(uint128 perStreamAmount) public returns (uint256[] memory streamIds) {
        // Create a batch of two streams
        uint256 batchSize = 2;

        // Calculate the combined amount of DAI assets to transfer to this contract
        uint256 transferAmount = perStreamAmount * batchSize;

        // Transfer the provided amount of DAI tokens to this contract
        DAI.transferFrom(msg.sender, address(this), transferAmount);

        // Approve the Batch contract to spend DAI
        DAI.approve({ spender: address(BATCH_LOCKUP), value: transferAmount });

        // Declare the first stream in the batch
        BatchLockup.CreateWithTimestampsLT memory stream0;
        stream0.sender = address(0xABCD); // The sender to stream the assets, he will be able to cancel the stream
        stream0.recipient = address(0xCAFE); // The recipient of the streamed assets
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
        stream1.sender = address(0xABCD); // The sender to stream the assets, he will be able to cancel the stream
        stream1.recipient = address(0xBEEF); // The recipient of the streamed assets
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

        streamIds = BATCH_LOCKUP.createWithTimestampsLT(LOCKUP_TRANCHED, DAI, batch);
    }
}
