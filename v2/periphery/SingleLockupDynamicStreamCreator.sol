// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { ISablierV2LockupDynamic } from "@sablier/v2-core/interfaces/ISablierV2LockupDynamic.sol";
import { Broker, LockupDynamic } from "@sablier/v2-core/types/DataTypes.sol";
import { ud2x18, ud60x18 } from "@sablier/v2-core/types/Math.sol";
import { IERC20 } from "@sablier/v2-core/types/Tokens.sol";
import { ISablierV2ProxyTarget } from "@sablier/v2-periphery/interfaces/ISablierV2ProxyTarget.sol";
import { IAllowanceTransfer, Permit2Params } from "@sablier/v2-periphery/types/Permit2.sol";
import { IPRBProxy, IPRBProxyRegistry } from "@sablier/v2-periphery/types/Proxy.sol";

import { ERC1271 } from "./ERC1271.sol";

contract SingleLockupDynamicStreamCreator is ERC1271 {
    IERC20 public constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IAllowanceTransfer public constant PERMIT2 = IAllowanceTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    IPRBProxyRegistry public constant PROXY_REGISTRY = IPRBProxyRegistry(0xD42a2bB59775694c9Df4c7822BfFAb150e6c699D);
    ISablierV2LockupDynamic public immutable lockupDynamic;
    ISablierV2ProxyTarget public immutable proxyTarget;

    constructor(ISablierV2LockupDynamic lockupDynamic_, ISablierV2ProxyTarget proxyTarget_) {
        lockupDynamic = lockupDynamic_;
        proxyTarget = proxyTarget_;
    }

    function singleCreateLockupDynamicStream(uint256 amount0, uint256 amount1) public returns (uint256 streamId) {
        // Get the proxy for this contract and deploy it if it doesn't exist
        IPRBProxy proxy = PROXY_REGISTRY.getProxy({ owner: address(this) });
        if (address(proxy) == address(0)) {
            proxy = PROXY_REGISTRY.deployFor(address(this));
        }

        // Sum the segment amounts
        uint256 totalAmount = amount0 + amount1;

        // Transfer the provided amount of DAI tokens to this contract
        DAI.transferFrom(msg.sender, address(this), totalAmount);

        // Approve the Permit2 contract to spend DAI
        uint256 allowance = DAI.allowance(address(this), address(PERMIT2));
        if (allowance < totalAmount) {
            DAI.approve({ spender: address(PERMIT2), amount: type(uint256).max });
        }

        // Set up Permit2. See the full documentation at https://github.com/Uniswap/permit2
        IAllowanceTransfer.PermitDetails memory permitDetails;
        permitDetails.token = address(DAI);
        permitDetails.amount = uint160(totalAmount);
        permitDetails.expiration = type(uint48).max; // maximum expiration possible
        (,, permitDetails.nonce) =
            PERMIT2.allowance({ user: address(this), token: address(DAI), spender: address(proxy) });

        IAllowanceTransfer.PermitSingle memory permitSingle;
        permitSingle.details = permitDetails;
        permitSingle.spender = address(proxy); // the proxy will be the spender
        permitSingle.sigDeadline = type(uint48).max; // same deadline as expiration

        // Declare the Permit2 params needed by Sablier
        Permit2Params memory permit2Params;
        permit2Params.permitSingle = permitSingle;
        permit2Params.signature = bytes(""); // contracts don't sign transactions

        // Declare the create function params
        LockupDynamic.CreateWithMilestones memory createParams;
        createParams.sender = msg.sender; // The sender will be able to cancel the stream
        createParams.recipient = address(0xcafe); // The recipient of the streamed assets
        createParams.totalAmount = uint128(totalAmount); // Total amount is the amount inclusive of all fees
        createParams.asset = DAI; // The streaming asset is DAI
        createParams.cancelable = true; // Whether the stream will be cancelable or not
        createParams.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Declare some dummy segments
        createParams.segments = new LockupDynamic.Segment[](2);
        createParams.segments[0] = LockupDynamic.Segment({
            amount: uint128(amount0),
            exponent: ud2x18(1e18),
            milestone: uint40(block.timestamp + 4 weeks)
        });
        createParams.segments[1] = (
            LockupDynamic.Segment({
                amount: uint128(amount1),
                exponent: ud2x18(3.14e18),
                milestone: uint40(block.timestamp + 52 weeks)
            })
        );

        // Encode the data for the proxy target call
        bytes memory data =
            abi.encodeCall(proxyTarget.createWithMilestones, (lockupDynamic, createParams, permit2Params));

        // Create a single Lockup Dynamic stream via the proxy and Sablier's proxy target
        bytes memory response = proxy.execute(address(proxyTarget), data);
        streamId = abi.decode(response, (uint256));
    }
}
