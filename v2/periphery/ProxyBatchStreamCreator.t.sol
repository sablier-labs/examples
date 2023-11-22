// SPDX-License-Identifier: GPL-3-0-or-later
pragma solidity >=0.8.19;

import { Test } from "forge-std/Test.sol";

import { ProxyBatchLockupDynamicStreamCreator } from "./ProxyBatchLockupDynamicStreamCreator.sol";
import { ProxyBatchLockupLinearStreamCreator } from "./ProxyBatchLockupLinearStreamCreator.sol";

contract ProxyBatchStreamCreatorTest is Test {
    // Test contracts
    ProxyBatchLockupDynamicStreamCreator internal proxyCreatorDynamic;
    ProxyBatchLockupLinearStreamCreator internal proxyCreatorLinear;

    address internal user;

    function setUp() public {
        // Fork Ethereum Mainnet
        vm.createSelectFork({ urlOrAlias: "mainnet" });

        // Deploy the stream creators
        proxyCreatorDynamic = new ProxyBatchLockupDynamicStreamCreator();
        proxyCreatorLinear = new ProxyBatchLockupLinearStreamCreator();

        // Create a test user
        user = payable(makeAddr("User"));
        vm.deal({ account: user, newBalance: 1 ether });

        // Mint some DAI tokens to the test user, which will be pulled by the creator contracts
        deal({ token: address(proxyCreatorLinear.DAI()), to: user, give: 4 * 1337e18 });

        // Make the test user the `msg.sender` in all following calls
        vm.startPrank({ msgSender: user });

        // Approve the creator contracts to pull DAI tokens from the test user
        proxyCreatorDynamic.DAI().approve({ spender: address(proxyCreatorDynamic), amount: 2 * 1337e18 });
        proxyCreatorLinear.DAI().approve({ spender: address(proxyCreatorLinear), amount: 2 * 1337e18 });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   LOCKUP-DYNAMIC
    //////////////////////////////////////////////////////////////////////////*/

    // Tests that creating streams works by checking the stream ids
    function test_ProxyBatchLockupDynamicStreamCreator() public {
        uint256 nextStreamId = proxyCreatorDynamic.LOCKUP_DYNAMIC().nextStreamId();
        uint256[] memory actualStreamIds = proxyCreatorDynamic.batchCreateStreams({ perStreamAmount: 1337e18 });
        uint256[] memory expectedStreamIds = new uint256[](2);
        expectedStreamIds[0] = nextStreamId;
        expectedStreamIds[1] = nextStreamId + 1;
        assertEq(actualStreamIds, expectedStreamIds);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   LOCKUP-LINEAR
    //////////////////////////////////////////////////////////////////////////*/

    // Tests that creating streams works by checking the stream ids
    function test_ProxyBatchLockupLinearStreamCreator() public {
        uint256 nextStreamId = proxyCreatorLinear.LOCKUP_LINEAR().nextStreamId();
        uint256[] memory actualStreamIds = proxyCreatorLinear.batchCreateStreams({ perStreamAmount: 1337e18 });
        uint256[] memory expectedStreamIds = new uint256[](2);
        expectedStreamIds[0] = nextStreamId;
        expectedStreamIds[1] = nextStreamId + 1;
        assertEq(actualStreamIds, expectedStreamIds);
    }
}
