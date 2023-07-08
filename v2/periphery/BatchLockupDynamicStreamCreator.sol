// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { ISablierV2LockupDynamic } from "@sablier/v2-core/interfaces/ISablierV2LockupDynamic.sol";
import { Broker, LockupDynamic } from "@sablier/v2-core/types/DataTypes.sol";
import { ud2x18, ud60x18 } from "@sablier/v2-core/types/Math.sol";
import { IERC20 } from "@sablier/v2-core/types/Tokens.sol";
import { ISablierV2ProxyTarget } from "@sablier/v2-periphery/interfaces/ISablierV2ProxyTarget.sol";
import { Batch } from "@sablier/v2-periphery/types/DataTypes.sol";
import { IAllowanceTransfer, Permit2Params } from "@sablier/v2-periphery/types/Permit2.sol";
import { IPRBProxy, IPRBProxyRegistry } from "@sablier/v2-periphery/types/Proxy.sol";

contract BatchLockupDynamicStreamCreator {
    IERC20 public constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IAllowanceTransfer public constant PERMIT2 = IAllowanceTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    IPRBProxyRegistry public constant PROXY_REGISTRY = IPRBProxyRegistry(0xD42a2bB59775694c9Df4c7822BfFAb150e6c699D);
    ISablierV2LockupDynamic public immutable lockupDynamic;
    ISablierV2ProxyTarget public immutable proxyTarget;

    constructor(ISablierV2LockupDynamic lockupDynamic_, ISablierV2ProxyTarget proxyTarget_) {
        lockupDynamic = lockupDynamic_;
        proxyTarget = proxyTarget_;
    }

    function batchCreateLockupDynamicStream(
        uint256 perStreamAmount,
        bytes memory permit2Signature
    )
        public
        returns (uint256[] memory streamIds)
    {
        IPRBProxy proxy = PROXY_REGISTRY.getProxy({ owner: address(this) }); // Get the proxy for this contract
        if (address(proxy) == address(0)) {
            proxy = PROXY_REGISTRY.deployFor(address(this)); // Deploy the proxy if it doesn't exist
        }

        // Create a batch of two streams
        uint256 batchSize = 2;

        // Calculate the combined amount of DAI assets to transfer to this contract
        uint256 transferAmount = perStreamAmount * batchSize;

        // Transfer the provided amount of DAI tokens to this contract
        DAI.transferFrom(msg.sender, address(this), transferAmount);

        // Approve the Permit2 contract to spend DAI
        uint256 allowance = DAI.allowance(address(this), address(PERMIT2));
        if (allowance < transferAmount) {
            DAI.approve({ spender: address(PERMIT2), amount: type(uint256).max });
        }

        // Set up Permit2. See the full documentation at https://github.com/Uniswap/permit2
        IAllowanceTransfer.PermitDetails memory permitDetails;
        permitDetails.token = address(DAI);
        permitDetails.amount = uint160(transferAmount);
        permitDetails.expiration = type(uint48).max; // maximum expiration possible
        (,, permitDetails.nonce) =
            PERMIT2.allowance({ user: address(this), token: address(DAI), spender: address(proxy) });

        IAllowanceTransfer.PermitSingle memory permitSingle;
        permitSingle.details = permitDetails;
        permitSingle.sigDeadline = type(uint48).max; // same deadline as expiration

        // Declare the Permit2 params needed by Sablier
        Permit2Params memory permit2Params;
        permit2Params.permitSingle = permitSingle;
        permit2Params.signature = permit2Signature;

        // Declare the first stream in the batch
        Batch.CreateWithMilestones memory stream0;
        stream0.sender = address(proxy); // The sender will be able to cancel the stream
        stream0.recipient = address(0xcafe); // The recipient of the streamed assets
        stream0.totalAmount = uint128(totalAmount); // The total amount of each stream, inclusive of all fees
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
                amount: perStreamAmount - stream0.segments[0].amount,
                exponent: ud2x18(2.71e18),
                milestone: uint40(block.timestamp + 24 weeks)
            })
        );

        // Declare the second stream in the batch
        Batch.CreateWithMilestones memory stream1;
        stream1.sender = address(proxy); // The sender will be able to cancel the stream
        stream1.recipient = address(0xbeef); // The recipient of the streamed assets
        stream1.totalAmount = uint128(totalAmount); // The total amount of each stream, inclusive of all fees
        stream1.cancelable = false; // Whether the stream will be cancelable or not
        stream1.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Declare some dummy segments
        stream1.segments = new LockupDynamic.Segment[](2);
        stream1.segments[0] = LockupDynamic.Segment({
            amount: perStreamAmount / 4,
            exponent: ud2x18(1e18),
            milestone: uint40(block.timestamp + 4 weeks)
        });
        stream1.segments[1] = (
            LockupDynamic.Segment({
                amount: perStreamAmount - stream1.segments[0].amount,
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
            abi.encodeCall(proxyTarget.batchCreateWithMilestones, (lockupDynamic, DAI, batch, permit2Params));

        // Create a batch of streams via the proxy and Sablier's proxy target
        bytes memory response = proxy.execute(address(proxyTarget), data);
        streamIds = abi.decode(response, (uint256[]));
    }
}
