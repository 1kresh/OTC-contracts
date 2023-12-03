// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";

import {PublicKeysRegistry} from "../src/PublicKeysRegistry.sol";

contract PublicKeysRegistryTest is Test {
    PublicKeysRegistry public registry;
    Vm.Wallet wallet;

    function setUp() public {
        registry = new PublicKeysRegistry();
        wallet = vm.createWallet(uint256(keccak256(bytes("1"))));
    }

    function test_submit() public {
        vm.startPrank(wallet.addr);

        bytes memory public_key = abi.encodePacked(wallet.publicKeyX, wallet.publicKeyY);
        
        assertEq(registry.public_keys(wallet.addr), new bytes(0));
        registry.submitPublicKey(public_key);
        assertEq(registry.public_keys(wallet.addr), public_key);
        
        vm.stopPrank();
    }
}
