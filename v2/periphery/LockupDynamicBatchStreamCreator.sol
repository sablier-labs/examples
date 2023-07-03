// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.13;

import { IAllowanceTransfer } from "@permit2/interfaces/IAllowanceTransfer.sol";
import { IPRBProxy } from "@prb/proxy/interfaces/IPRBProxy.sol";
import { IPRBProxyRegistry } from "@prb/proxy/interfaces/IPRBProxyRegistry.sol";
import { ISablierV2ProxyTarget } from "@sablier/v2-periphery/interfaces/ISablierV2ProxyTarget.sol";
import { Batch, Broker, LockupDynamic, Permit2Params } from "@sablier/v2-periphery/types/DataTypes.sol";
import { BatchBuilder } from "@sablier/v2-periphery-test/utils/BatchBuilder.sol";
import { ISablierV2LockupDynamic } from "@sablier/v2-core/interfaces/ISablierV2LockupDynamic.sol";
import { ud2x18, ud60x18 } from "@sablier/v2-core/types/Math.sol";
import { IERC20 } from "@sablier/v2-core/types/Tokens.sol";

contract LockupDynamicBatchStreamCreator {
    IERC20 public constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IAllowanceTransfer public constant PERMIT2 = IAllowanceTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    IPRBProxyRegistry public constant PROXY_REGISTRY = IPRBProxyRegistry(0x33e200B5fb5e0C57d370d5202c26A35d07A46B98);
    ISablierV2LockupDynamic public immutable sablierLockupDynamic;
    ISablierV2ProxyTarget public immutable sablierProxyTarget;

    constructor(ISablierV2LockupDynamic sablierLockupDynamic_, ISablierV2ProxyTarget sablierProxyTarget_) {
        sablierLockupDynamic = sablierLockupDynamic_;
        sablierProxyTarget = sablierProxyTarget_;
    }

    function batchCreateLockupDynamicStream(
        uint256 perStreamAmount,
        uint256 batchSize,
        bytes memory signature
    )
        public
        returns (uint256[] memory streamIds)
    {
        IPRBProxy proxy = PROXY_REGISTRY.getProxy({ owner: address(this) }); // Get the proxy for this contract
        if (address(proxy) == address(0)) {
            proxy = PROXY_REGISTRY.deployFor(address(this)); // Deploy the proxy if it doesn't exist
        }

        uint256 transferAmount = perStreamAmount * batchSize;

        // Approve the Permit2 contract to spend DAI
        uint256 allowance = DAI.allowance(address(this), address(PERMIT2));
        if (allowance < transferAmount) {
            DAI.approve({ spender: address(PERMIT2), amount: type(uint256).max });
        }

        IAllowanceTransfer.PermitDetails memory permitDetails;
        permitDetails.token = address(DAI);
        permitDetails.amount = uint160(transferAmount);
        permitDetails.expiration = type(uint48).max; // maximum expiration possible
        (,, permitDetails.nonce) =
            PERMIT2.allowance({ user: address(this), token: address(DAI), spender: address(proxy) });

        IAllowanceTransfer.PermitSingle memory permitSingle;
        permitSingle.details = permitDetails;
        permitSingle.sigDeadline = type(uint48).max; // same deadline as expiration

        // Declare the Permit2 params
        Permit2Params memory permit2Params;
        permit2Params.permitSingle = permitSingle;
        permit2Params.signature = signature;

        // Declare a single batch struct
        Batch.CreateWithMilestones memory batchSingle;
        batchSingle.sender = address(proxy); // The sender will be able to cancel the stream
        batchSingle.recipient = address(0xcafe); // The recipient of the streamed assets
        batchSingle.cancelable = true; // Whether the stream will be cancelable or not
        batchSingle.segments = new LockupDynamic.Segment[](2);
        // Declare some dummy segments
        batchSingle.segments[0] =
            LockupDynamic.Segment({ amount: 0, exponent: ud2x18(1e18), milestone: uint40(block.timestamp + 4 weeks) });
        batchSingle.segments[1] = LockupDynamic.Segment({
            amount: perStreamAmount,
            exponent: ud2x18(3.14e18),
            milestone: uint40(block.timestamp + 52 weeks)
        });
        batchSingle.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Fill the batch param
        Batch.CreateWithMilestones[] memory batch = BatchBuilder.fillBatch(batchSingle, batchSize);

        // Encode the data for the proxy
        bytes memory data = abi.encodeCall(
            sablierProxyTarget.batchCreateWithMilestones, (sablierLockupDynamic, DAI, batch, permit2Params)
        );
        // Create multiple streams via the proxy
        bytes memory response = proxy.execute(address(sablierProxyTarget), data);
        streamIds = abi.decode(response, (uint256[]));
    }
}
