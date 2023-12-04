// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IPublicKeysRegistry } from "src/interfaces/IPublicKeysRegistry.sol";

contract PublicKeysRegistry is IPublicKeysRegistry {
    mapping (address user => bytes public_key) private public_keys;

    function getPublicKey(address owner) external view override returns (bytes memory public_key) {
        public_key = public_keys[owner];
    }

    function submitPublicKey(bytes calldata public_key) external override {
        if (public_key.length != 64) {
            revert ImproperLength();
        }

        if (address(uint160(uint256(keccak256(public_key)))) != msg.sender) {
            revert ImproperPublicKey();
        }

        public_keys[msg.sender] = public_key;
    }
}
