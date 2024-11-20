// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { StakeSablierNFT_Fork_Test } from "../StakeSablierNFT.t.sol";

contract Stake_Test is StakeSablierNFT_Fork_Test {
    function test_RevertWhen_StreamingAssetIsNotRewardAsset() external {
        resetPrank({ msgSender: users.bob.addr });

        vm.expectRevert(abi.encodeWithSelector(DifferentStreamingToken.selector, users.bob.streamId, DAI));
        stakingContract.stake(users.bob.streamId);
    }

    modifier whenStreamingAssetIsRewardAsset() {
        _;
    }

    function test_RevertWhen_AlreadyStaking() external whenStreamingAssetIsRewardAsset {
        resetPrank({ msgSender: users.alice.addr });

        vm.expectRevert(abi.encodeWithSelector(AlreadyStaking.selector, users.alice.addr, users.alice.streamId));
        stakingContract.stake(users.alice.streamId);
    }

    modifier notAlreadyStaking() {
        resetPrank({ msgSender: users.joe.addr });
        _;
    }

    function test_Stake() external whenStreamingAssetIsRewardAsset notAlreadyStaking {
        // Expect {Staked} event to be emitted.
        vm.expectEmit({ emitter: address(stakingContract) });
        emit Staked(users.joe.addr, users.joe.streamId);

        // Stake the NFT.
        stakingContract.stake(users.joe.streamId);

        // Assertions: NFT has been transferred to the staking contract.
        assertEq(SABLIER.ownerOf(users.joe.streamId), address(stakingContract));

        // Assertions: storage variables.
        assertEq(stakingContract.stakedAssets(users.joe.streamId), users.joe.addr);
        assertEq(stakingContract.stakedStreamId(users.joe.addr), users.joe.streamId);

        assertEq(stakingContract.totalERC20StakedSupply(), AMOUNT_IN_STREAM * 2);

        // Assert: `updateReward` has correctly updated the storage variables.
        assertApproxEqAbs(stakingContract.rewards(users.joe.addr), 0, 0);
        assertEq(stakingContract.lastUpdateTime(), block.timestamp);
        assertEq(stakingContract.totalRewardPaidPerERC20Token(), 0);
        assertEq(stakingContract.userRewardPerERC20Token(users.joe.addr), 0);
    }
}
