// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { ISablierV2LockupDynamic } from "@sablier/v2-core/src/interfaces/ISablierV2LockupDynamic.sol";
import { ud2x18, ud60x18 } from "@sablier/v2-core/src/types/Math.sol";
import { IERC20 } from "@sablier/v2-core/src/types/Tokens.sol";
import { IPRBProxy, IPRBProxyRegistry } from "@sablier/v2-periphery/src/types/Proxy.sol";
import { ISablierV2ProxyTarget } from "@sablier/v2-periphery/src/interfaces/ISablierV2ProxyTarget.sol";
import { Batch, Broker, LockupDynamic } from "@sablier/v2-periphery/src/types/DataTypes.sol";

contract ProxyBatchLockupDynamicStreamCreator {
    // Mainnet addresses
    IERC20 public constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    // See https://docs.sablier.com/contracts/v2/deployments for all deployments
    ISablierV2LockupDynamic public constant LOCKUP_DYNAMIC =
        ISablierV2LockupDynamic(0x39EFdC3dbB57B2388CcC4bb40aC4CB1226Bc9E44);
    ISablierV2ProxyTarget public constant PROXY_TARGET_APPROVE =
        ISablierV2ProxyTarget(0x638a7aC8315767cEAfc57a6f5e3559454347C3f6);

    IPRBProxyRegistry public constant PROXY_REGISTRY = IPRBProxyRegistry(0x584009E9eDe26e212182c9745F5c000191296a78);

    function batchCreateStreams(uint128 perStreamAmount) public returns (uint256[] memory streamIds) {
        // Get the proxy for this contract and deploy it if it doesn't exist
        IPRBProxy proxy = PROXY_REGISTRY.getProxy({ user: address(this) });
        if (address(proxy) == address(0)) {
            proxy = PROXY_REGISTRY.deployFor(address(this));
        }

        // Create a batch of two streams
        uint256 batchSize = 2;

        // Calculate the combined amount of DAI assets to transfer to this contract
        uint256 transferAmount = perStreamAmount * batchSize;

        // Transfer the provided amount of DAI tokens to this contract
        DAI.transferFrom(msg.sender, address(this), transferAmount);

        // Approve the Proxy contract to spend DAI
        uint256 allowance = DAI.allowance(address(this), address(proxy));
        if (allowance < transferAmount) {
            DAI.approve({ spender: address(proxy), amount: type(uint256).max });
        }

        // Declare the first stream in the batch
        Batch.CreateWithMilestones memory stream0;
        stream0.sender = address(proxy); // The sender to stream the assets, he will be able to cancel the stream
        stream0.recipient = address(0xCAFE); // The recipient of the streamed assets
        stream0.totalAmount = uint128(perStreamAmount); // The total amount of each stream, inclusive of all fees
        stream0.cancelable = true; // Whether the stream will be cancelable or not
        stream0.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Declare some dummy segments
        stream0.segments = new LockupDynamic.Segment[](2);
        stream0.segments[0] = LockupDynamic.Segment({
            amount: perStreamAmount / 2,
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
        stream1.sender = address(proxy); // The sender to stream the assets, he will be able to cancel the stream
        stream1.recipient = address(0xBEEF); // The recipient of the streamed assets
        stream1.totalAmount = perStreamAmount; // The total amount of each stream, inclusive of all fees
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

        // Encode the data for the proxy
        bytes memory data =
            abi.encodeCall(PROXY_TARGET_APPROVE.batchCreateWithMilestones, (LOCKUP_DYNAMIC, DAI, batch, ""));

        // Create a batch of streams via the proxy and Sablier's proxy target approve
        bytes memory response = proxy.execute(address(PROXY_TARGET_APPROVE), data);
        streamIds = abi.decode(response, (uint256[]));
    }
}
