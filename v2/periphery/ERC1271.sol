// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

contract ERC1271 {
    function isValidSignature(bytes32, bytes memory) public pure returns (bytes4) {
        return this.isValidSignature.selector;
    }
}
