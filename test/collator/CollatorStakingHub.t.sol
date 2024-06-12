// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../../src/collator/CollatorStakingHub.sol";
import "../../src/deposit/Deposit.sol";

contract CollatorStakingHubTest is Test {
    address hub;

    function setUp() public {
        address gring = address(new GRINGMock());
        address deposit = Upgrades.deployTransparentProxy(
            "Deposit.sol:Deposit", msg.sender, abi.encodeCall(Deposit.initialize, ("RING Deposit", "RDPS"))
        );
        hub = Upgrades.deployTransparentProxy(
            "CollatorStakingHub.sol:CollatorStakingHub",
            msg.sender,
            abi.encodeCall(CollatorStakingHub.initialize, (gring, deposit))
        );
    }
}

contract GRINGMock is ERC20 {
    constructor() ERC20("Governance RINGMock", "gRINGM") {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}
