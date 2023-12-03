// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

contract PublicKeysRegistry {
    error ImproperLength();
    error ImproperPublicKey();

    struct Position {
        string text;
        uint256 limit;

    }

    mapping (address user => bytes public_key) public public_keys;

    function createSellPosition(string calldata text, limit) external {
        
    }

    function buyPosition() external {

    }
}
