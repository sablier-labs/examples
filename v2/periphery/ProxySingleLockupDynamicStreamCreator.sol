// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { ISablierV2LockupDynamic } from "@sablier/v2-core/src/interfaces/ISablierV2LockupDynamic.sol";
import { ud2x18, ud60x18 } from "@sablier/v2-core/src/types/Math.sol";
import { IERC20 } from "@sablier/v2-core/src/types/Tokens.sol";
import { ISablierV2ProxyTarget } from "@sablier/v2-periphery/src/interfaces/ISablierV2ProxyTarget.sol";
import { IPRBProxy, IPRBProxyRegistry } from "@sablier/v2-periphery/src/types/Proxy.sol";
import { Broker, LockupDynamic } from "@sablier/v2-periphery/src/types/DataTypes.sol";

contract SingleLockupDynamicStreamCreator {
    // Mainnet addresses
    IERC20 public constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    // See https://docs.sablier.com/contracts/v2/deployments for all deployments
    ISablierV2LockupDynamic public constant LOCKUP_DYNAMIC =
        ISablierV2LockupDynamic(0x39EFdC3dbB57B2388CcC4bb40aC4CB1226Bc9E44);
    ISablierV2ProxyTarget public constant PROXY_TARGET_APPROVE =
        ISablierV2ProxyTarget(0x638a7aC8315767cEAfc57a6f5e3559454347C3f6);

    IPRBProxyRegistry public constant PROXY_REGISTRY = IPRBProxyRegistry(0x584009E9eDe26e212182c9745F5c000191296a78);

    function singleCreateStream(uint128 amount0, uint128 amount1) public returns (uint256 streamId) {
        // Get the proxy for this contract and deploy it if it doesn't exist
        IPRBProxy proxy = PROXY_REGISTRY.getProxy({ user: address(this) });
        if (address(proxy) == address(0)) {
            proxy = PROXY_REGISTRY.deployFor(address(this));
        }

        // Sum the segment amounts
        uint256 totalAmount = amount0 + amount1;

        // Transfer the provided amount of DAI tokens to this contract
        DAI.transferFrom(msg.sender, address(this), totalAmount);

        // Approve the Permit2 contract to spend DAI
        uint256 allowance = DAI.allowance(address(this), address(proxy));
        if (allowance < totalAmount) {
            DAI.approve({ spender: address(proxy), amount: type(uint256).max });
        }

        // Declare the create function params
        LockupDynamic.CreateWithMilestones memory createParams;
        createParams.sender = address(proxy); // The sender to stream the assets, he will be able to cancel the stream
        createParams.recipient = address(0xCAFE); // The recipient of the streamed assets
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
            abi.encodeCall(PROXY_TARGET_APPROVE.createWithMilestones, (LOCKUP_DYNAMIC, createParams, ""));

        // Create a single Lockup Dynamic stream via the proxy and Sablier's proxy target approve
        bytes memory response = proxy.execute(address(PROXY_TARGET_APPROVE), data);
        streamId = abi.decode(response, (uint256));
    }
}
