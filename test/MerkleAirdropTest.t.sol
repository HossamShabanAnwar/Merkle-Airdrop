// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";
import {BagelToken} from "../src/BagelToken.sol";
import {ZkSyncChainChecker} from "@foundry-devops/src/ZkSyncChainChecker.sol";
import {DeployMerkleAirdrop} from "../script/DeployMerkleAirdrop.s.sol";

contract MerkleAirdropTest is ZkSyncChainChecker, Test {
    MerkleAirdrop public airdrop;
    BagelToken public token;

    bytes32 public merkleRoot = 0xaa5d581231e596618465a56aa0f5870ba6e20785fe436d5bfb82b08662ccc7c4;
    uint256 public amountToClaim = 25 * 1e18;
    uint256 public amountToSend = 100 * 1e18;
    bytes32[] public proof = [
        bytes32(0x0fd7c981d39bece61f7499702bf59b3114a90e66b51ba2c53abdf7b62986c00a),
        bytes32(0xe5ebd1e1b5a5478a944ecab36a9a954ac3b6b8216875f6524caa7a1d87096576)
    ];

    address public gasPayer;
    address user;
    uint256 userPrivKey;

    function setUp() public {
        if (!isZkSyncChain()) {
            DeployMerkleAirdrop deployer = new DeployMerkleAirdrop();
            (airdrop, token) = deployer.deployMerkleAirdrop();
        } else {
            token = new BagelToken();
            airdrop = new MerkleAirdrop(merkleRoot, token);
            token.mint(token.owner(), amountToSend); // We need to mint some tokens for the MerkleAirdrop to be able to make the transfer.
            token.transfer(address(airdrop), amountToSend);
        }
        (user, userPrivKey) = makeAddrAndKey("user");
        gasPayer = makeAddr("gasPayer");
    }

    function signMessage(uint256 privKey, address account) public view returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 hashedMessage = airdrop.getMessageHash(account, amountToClaim);
        (v, r, s) = vm.sign(privKey, hashedMessage);
    }

    function testUserCanClaim() public {
        // Arrange
        uint256 startingBalance = token.balanceOf(user);

        vm.prank(gasPayer);
        (uint8 v, bytes32 r, bytes32 s) = signMessage(userPrivKey, user);

        vm.prank(user);
        airdrop.claim(user, amountToClaim, proof, v, r, s);
        uint256 endingBalance = token.balanceOf(user);
        console.log("endingBalance: ", endingBalance);

        // Assert
        assertEq(endingBalance - startingBalance, amountToClaim);
    }
}
