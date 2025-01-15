// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { StakeSablierNFT_Fork_Test } from "../StakeSablierNFT.t.sol";

contract Unstake_Test is StakeSablierNFT_Fork_Test {
    function test_RevertWhen_CallerIsNotStaker() external {
        // Change the caller to a non staker.
        resetPrank({ msgSender: users.bob.addr });

        vm.expectRevert(abi.encodeWithSelector(UnauthorizedCaller.selector, users.bob.addr, users.bob.streamId));
        stakingContract.unstake(users.bob.streamId);
    }

    function test_WhenCallerIsStaker() external {
        // Change the caller to a non staker and stake a stream.
        resetPrank({ msgSender: users.joe.addr });
        stakingContract.stake(users.joe.streamId);

        vm.warp(block.timestamp + 1 days);

        // Expect {Unstaked} event to be emitted.
        vm.expectEmit({ emitter: address(stakingContract) });
        emit Unstaked(users.joe.addr, users.joe.streamId);

        // Unstake the NFT.
        stakingContract.unstake(users.joe.streamId);

        // Assert: NFT has been transferred.
        assertEq(SABLIER.ownerOf(users.joe.streamId), users.joe.addr);

        // Assert: `stakedTokens` and `stakedStreamId` have been deleted from storage.
        assertEq(stakingContract.stakedUsers(users.joe.streamId), address(0));
        assertEq(stakingContract.stakedStreams(users.joe.addr), 0);

        // Assert: `totalERC20StakedSupply` has been updated.
        assertEq(stakingContract.totalERC20StakedSupply(), AMOUNT_IN_STREAM);

        // Assert: `updateReward` has correctly updated the storage variables.
        uint256 expectedReward = 1 days * rewardRate / 2;
        assertApproxEqAbs(stakingContract.rewards(users.joe.addr), expectedReward, 0.0001e18);
        assertEq(stakingContract.lastUpdateTime(), block.timestamp);
        assertEq(stakingContract.totalRewardPaidPerERC20Token(), (expectedReward * 1e18) / AMOUNT_IN_STREAM);
        assertEq(stakingContract.userRewardPerERC20Token(users.joe.addr), (expectedReward * 1e18) / AMOUNT_IN_STREAM);
    }
}
