// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

interface IPublicKeysRegistry {
    error ImproperLength();
    error ImproperPublicKey();

    function getPublicKey(address owner) external view returns (bytes memory public_key);
    
    function submitPublicKey(bytes calldata public_key) external;
}
