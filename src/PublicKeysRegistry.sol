// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

contract PublicKeysRegistry {
    error ImproperLength();
    error ImproperPublicKey();

    mapping (address user => bytes public_key) public public_keys;

    function submitPublicKey(bytes calldata public_key) external {
        if (public_key.length != 64) {
            revert ImproperLength();
        }

        if (address(uint160(uint256(keccak256(public_key)))) != msg.sender) {
            revert ImproperPublicKey();
        }

        public_keys[msg.sender] = public_key;
    }
}
