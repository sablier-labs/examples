// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ud60x18 } from "@prb/math/src/UD60x18.sol";
import { ISablierV2LockupLinear } from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import { ISablierV2Batch } from "@sablier/v2-periphery/src/interfaces/ISablierV2Batch.sol";
import { Batch, Broker, LockupLinear } from "@sablier/v2-periphery/src/types/DataTypes.sol";

contract BatchLockupLinearStreamCreator {
    // Mainnet addresses
    IERC20 public constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    // See https://docs.sablier.com/contracts/v2/deployments for all deployments
    ISablierV2Batch public constant BATCH = ISablierV2Batch(0xEa07DdBBeA804E7fe66b958329F8Fa5cDA95Bd55);
    ISablierV2LockupLinear public constant LOCKUP_LINEAR =
        ISablierV2LockupLinear(0xAFb979d9afAd1aD27C5eFf4E27226E3AB9e5dCC9);

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
        Batch.CreateWithDurations memory stream0;
        stream0.sender = address(0xABCD); // The sender to stream the assets, he will be able to cancel the stream
        stream0.recipient = address(0xCAFE); // The recipient of the streamed assets
        stream0.totalAmount = perStreamAmount; // The total amount of each stream, inclusive of all fees
        stream0.cancelable = true; // Whether the stream will be cancelable or not
        stream0.durations = LockupLinear.Durations({
            cliff: 4 weeks, // Assets will be unlocked only after 4 weeks
            total: 52 weeks // Setting a total duration of ~1 year
         });
        stream0.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Declare the second stream in the batch
        Batch.CreateWithDurations memory stream1;
        stream1.sender = address(0xABCD); // The sender to stream the assets, he will be able to cancel the stream
        stream1.recipient = address(0xBEEF); // The recipient of the streamed assets
        stream1.totalAmount = perStreamAmount; // The total amount of each stream, inclusive of all fees
        stream1.cancelable = false; // Whether the stream will be cancelable or not
        stream1.durations = LockupLinear.Durations({
            cliff: 1 weeks, // Assets will be unlocked only after 1 week
            total: 26 weeks // Setting a total duration of ~6 months
         });
        stream1.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Fill the batch param
        Batch.CreateWithDurations[] memory batch = new Batch.CreateWithDurations[](batchSize);
        batch[0] = stream0;
        batch[1] = stream1;

        streamIds = BATCH.createWithDurations(LOCKUP_LINEAR, DAI, batch);
    }
}
