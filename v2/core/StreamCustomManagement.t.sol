// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { Test } from "forge-std/src/Test.sol";
import { Errors } from "@sablier/v2-core/src/libraries/Errors.sol";
import { SablierV2LockupLinear } from "@sablier/v2-core/src/SablierV2LockupLinear.sol";
import { ISablierV2NFTDescriptor } from "@sablier/v2-core/src/interfaces/ISablierV2NFTDescriptor.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC721Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { StreamCustomManagement } from "./StreamCustomManagement.sol";

contract TEST is ERC20 {
    constructor(address to) ERC20("TEST", "TEST") {
        _mint(to, 1_000_000 ether);
    }
}

contract StreamCustomManagementTest is Test {
    ERC20 internal token;
    SablierV2LockupLinear internal sablierLockup;
    StreamCustomManagement internal management;

    address internal sablierOwner;
    address internal bob;
    address internal alice;

    function setUp() public {
        // Create a test user
        sablierOwner = payable(makeAddr("SablierOwner"));
        vm.deal({ account: sablierOwner, newBalance: 1 ether });

        // Create test users
        bob = makeAddr("Bob");
        alice = makeAddr("Alice");

        // Create a test ERC20 token and send 1M tokens to Bob
        token = new TEST(bob);

        // Initialize Sablier Lockup Linear contract
        sablierLockup = new SablierV2LockupLinear(
            sablierOwner,
            ISablierV2NFTDescriptor(address(0)) // Irrelevant for test purposes
        );

        // Initialize StreamCustomManagement contract
        management = new StreamCustomManagement(sablierLockup, token);
    }

    // Test creating a stream from Bob (Project Owner) to Alice (Investor)
    function test_create() public {
        uint128 amount = 10 ether;

        // Approve StreamCustomManagement to spend 10 TEST on behalf of Bob
        vm.startPrank(bob);
        token.approve(address(management), amount);

        // Create stream from Bob to Alice
        uint256 streamId = management.create(alice, amount);

        assertEq(streamId, 1);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 1_000_000 ether - amount);
        assertEq(token.balanceOf(address(sablierLockup)), amount);

        // Stream checks in the Sablier Lockup contract
        assertEq(address(sablierLockup.getAsset(streamId)), address(token));
        assertEq(sablierLockup.getRecipient(streamId), address(management));
        assertEq(sablierLockup.getDepositedAmount(streamId), amount);
        assertEq(sablierLockup.isTransferable(streamId), false);
        assertEq(sablierLockup.isCancelable(streamId), false);
        assertEq(sablierLockup.isDepleted(streamId), false);
        assertEq(sablierLockup.isStream(streamId), true);
        assertEq(sablierLockup.isCold(streamId), false);
        assertEq(sablierLockup.isWarm(streamId), true);
    }

    // Test that withdraws from Sablier Lockup contract revert if the caller is not the management contract
    function test_withdraw_from_sablier_reverts() public {
        // Whitelist the management contract in the Sablier Lockup contract hooks
        vm.startPrank(sablierOwner);
        sablierLockup.allowToHook(address(management));
        vm.stopPrank();

        // Create stream from Bob to Alice
        vm.startPrank(bob);
        token.approve(address(management), 10 ether);
        uint256 streamId = management.create(alice, 10 ether);
        vm.stopPrank();

        // Advance time enough to make cliff period over and the total duration to be over
        vm.warp({ newTimestamp: block.timestamp + 60 weeks });

        // Calls to Sablier Lockup "withdraw" should revert
        vm.startPrank(bob);
        vm.expectRevert();
        sablierLockup.withdraw(streamId, address(management), 1 ether);
        vm.stopPrank();

        vm.startPrank(sablierOwner);
        vm.expectRevert();
        sablierLockup.withdraw(streamId, address(management), 1 ether);
        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectRevert();
        sablierLockup.withdraw(streamId, address(management), 1 ether);
        vm.stopPrank();
    }

    // Test that withdraw works as expected and burns the Sablier ERC721 token when called from the management contract
    function test_withdraw_from_management() public {
        // Whitelist the management contract in the Sablier Lockup contract hooks
        vm.startPrank(sablierOwner);
        sablierLockup.allowToHook(address(management));
        vm.stopPrank();

        // Create stream from Bob to Alice
        vm.startPrank(bob);
        token.approve(address(management), 10 ether);
        uint256 streamId = management.create(alice, 10 ether);
        vm.stopPrank();

        // Advance time enough to make cliff period over and the total duration to be over
        vm.warp({ newTimestamp: block.timestamp + 60 weeks });

        // Reverts if Bob attempts to withdraw from the Sablier Lockup contract
        vm.startPrank(bob);
        vm.expectRevert();
        management.withdraw(streamId, 1 ether);
        vm.stopPrank();

        // Alice can withdraw from the management contract
        vm.startPrank(alice);
        management.withdraw(streamId, 1 ether);
        vm.stopPrank();

        assertEq(token.balanceOf(alice), 1 ether);
        assertEq(sablierLockup.isDepleted(streamId), false);

        // Withdraw remaining tokens from the stream
        vm.startPrank(alice);
        management.withdraw(streamId, 9 ether);
        vm.stopPrank();

        assertEq(token.balanceOf(alice), 10 ether);
        assertEq(sablierLockup.isDepleted(streamId), true);

        // Should have burned the Sablier ERC721 token
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, streamId));
        sablierLockup.ownerOf(streamId);
    }

    // Test that withdrawMax works as expected and burns the Sablier ERC721 token when called from the management
    // contract
    function test_withdrawMax_from_management() public {
        // Whitelist the management contract in the Sablier Lockup contract hooks
        vm.startPrank(sablierOwner);
        sablierLockup.allowToHook(address(management));
        vm.stopPrank();

        // Create stream from Bob to Alice
        vm.startPrank(bob);
        token.approve(address(management), 10 ether);
        uint256 streamId = management.create(alice, 10 ether);
        vm.stopPrank();

        // Advance time enough to make cliff period over and the total duration to be over
        vm.warp({ newTimestamp: block.timestamp + 60 weeks });

        // Reverts if Bob attempts to withdraw from the Sablier Lockup contract
        // (Respecting the example custom logic in the management contract)
        vm.startPrank(bob);
        vm.expectRevert();
        management.withdrawMax(streamId);
        vm.stopPrank();

        // Alice can withdraw from the management contract
        vm.startPrank(alice);
        management.withdrawMax(streamId);
        vm.stopPrank();

        assertEq(token.balanceOf(alice), 10 ether);

        // Should have burned the Sablier ERC721 token
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, streamId));
        sablierLockup.ownerOf(streamId);
    }

    // Test that ERC721 operations like transferFrom and burn revert if the stream is not depleted
    function test_ERC721_operations_revert() public {
        uint128 amount = 10 ether;

        // Approve StreamCustomManagement to spend 10 TEST on behalf of Bob
        vm.startPrank(bob);
        token.approve(address(management), amount);

        // Create stream from Bob to Alice
        uint256 streamId = management.create(alice, amount);
        vm.stopPrank();

        // All must revert
        address[] memory _addressToTest = new address[](3);
        _addressToTest[0] = address(sablierLockup);
        _addressToTest[1] = alice;
        _addressToTest[2] = address(management);

        // Tests before stream is depleted
        for (uint256 i = 0; i < _addressToTest.length; i++) {
            vm.startPrank(_addressToTest[i]);

            // ERC721 transfer reverts
            vm.expectRevert(abi.encodeWithSelector(Errors.SablierV2Lockup_NotTransferable.selector, streamId));
            sablierLockup.transferFrom(address(management), bob, streamId);
            vm.expectRevert(abi.encodeWithSelector(Errors.SablierV2Lockup_NotTransferable.selector, streamId));
            sablierLockup.safeTransferFrom(address(management), bob, streamId, "");

            // Stream not depleted error
            vm.expectRevert(abi.encodeWithSelector(Errors.SablierV2Lockup_StreamNotDepleted.selector, streamId));
            sablierLockup.burn(streamId);
        }

        // Advance time enough to make cliff period over and the total duration to be over
        vm.warp({ newTimestamp: block.timestamp + 60 weeks });

        // Withdraw all tokens from the stream
        vm.startPrank(alice);
        management.withdrawMax(streamId);
        vm.stopPrank();

        // Should have burned the Sablier ERC721 token
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, streamId));
        sablierLockup.ownerOf(streamId);
    }
}
