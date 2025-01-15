// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ISablierLockup } from "@sablier/lockup/src/interfaces/ISablierLockup.sol";
import { ILockupNFTDescriptor } from "@sablier/lockup/src/interfaces/ILockupNFTDescriptor.sol";
import { SablierLockup } from "@sablier/lockup/src/SablierLockup.sol";

import { Test } from "forge-std/src/Test.sol";
import { StreamManagementWithHook } from "./StreamManagementWithHook.sol";

contract MockERC20 is ERC20 {
    constructor(address to) ERC20("MockERC20", "MockERC20") {
        _mint(to, 1_000_000e18);
    }
}

contract StreamManagementWithHookTest is Test {
    StreamManagementWithHook internal streamManager;
    ISablierLockup internal sablierLockup;

    ERC20 internal token;
    uint128 internal amount = 10e18;
    uint256 internal defaultStreamId;

    address internal alice;
    address internal bob;
    address internal sablierAdmin;

    function setUp() public {
        vm.createSelectFork({ urlOrAlias: "sepolia", blockNumber: 7_497_776 });

        // Create a test users
        alice = makeAddr("Alice");
        bob = makeAddr("Bob");
        sablierAdmin = payable(makeAddr("SablierAdmin"));

        // Create a mock ERC20 token and send 1M tokens to Bob
        token = new MockERC20(bob);

        // Deploy Sablier Lockup Linear contract
        sablierLockup = new SablierLockup(
            sablierAdmin,
            ILockupNFTDescriptor(address(0)), // Irrelevant for test purposes
            500 // the MAX_COUNT
        );

        // Deploy StreamManagementWithHook contract
        streamManager = new StreamManagementWithHook(sablierLockup, token);

        // Whitelist the contract to be able to hook into Sablier Lockup contract
        vm.startPrank(sablierAdmin);
        sablierLockup.allowToHook(address(streamManager));
        vm.stopPrank();

        // Approve streamManager to spend MockERC20 on behalf of Bob
        vm.startPrank(bob);
        token.approve(address(streamManager), type(uint128).max);
    }

    // Test creating a stream from Bob (Stream Manager Owner) to Alice (Beneficiary)
    function test_Create() public {
        // Create a stream with Alice as the beneficiary
        uint256 streamId = streamManager.create({ beneficiary: alice, totalAmount: amount });

        // Check streamId
        assertEq(streamId, 1);

        // Check balances
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 1_000_000e18 - amount);
        assertEq(token.balanceOf(address(streamManager.SABLIER())), amount);

        // Check stream details are correct
        assertEq(address(sablierLockup.getUnderlyingToken(streamId)), address(token));
        assertEq(sablierLockup.getRecipient(streamId), address(streamManager));
        assertEq(sablierLockup.getDepositedAmount(streamId), amount);
        assertEq(sablierLockup.isCancelable(streamId), true);
        assertEq(sablierLockup.isTransferable(streamId), false);

        // Check streamManager details are correct
        assertEq(streamManager.streamBeneficiaries(streamId), alice);
    }

    modifier givenStreamsCreated() {
        // Create a stream with Alice as the beneficiary
        defaultStreamId = streamManager.create({ beneficiary: alice, totalAmount: amount });
        require(defaultStreamId == 1, "Stream creation failed");
        _;
    }

    // Test that withdraw from Sablier stream reverts if it is directly called on the Sablier Lockup contract
    function test_Withdraw_RevertWhen_CallerNotStreamManager() public givenStreamsCreated {
        // Warp time to exceed total duration
        vm.warp({ newTimestamp: block.timestamp + 60 weeks });

        // Prank Alice to be the `msg.sender`.
        vm.startPrank(alice);

        // Since Alice is the `msg.sender`, `withdraw` to Sablier stream should revert due to hook restriction
        vm.expectRevert(abi.encodeWithSelector(StreamManagementWithHook.CallerNotThisContract.selector));
        sablierLockup.withdraw(defaultStreamId, address(streamManager), 1e18);
    }

    // Test that withdraw from Sablier stream succeeds if it is called through the `streamManager` contract
    function test_Withdraw() public givenStreamsCreated {
        // Advance time enough to make cliff period over and the total duration to be over
        vm.warp({ newTimestamp: block.timestamp + 60 weeks });

        // Prank Alice to be the `msg.sender`
        vm.startPrank(alice);

        // Alice can withdraw from the streamManager contract
        streamManager.withdraw(defaultStreamId, 1e18);

        assertEq(token.balanceOf(alice), 1e18);

        // Withdraw max tokens from the stream
        streamManager.withdrawMax(defaultStreamId);

        assertEq(token.balanceOf(alice), 10e18);
    }
}
