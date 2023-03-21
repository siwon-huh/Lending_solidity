// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

//version 0.0.1 - 21/03/2023 13:13

interface IPriceOracle {
    function getPrice(address asset) external view returns (uint256);
}
contract DreamAcademyLending is IPriceOracle{

    IPriceOracle oracle;
    address asset;
    constructor(IPriceOracle _oracle, address _asset) {
        oracle = _oracle;
        asset = _asset;
    }
    function getPrice(address _asset) public view returns (uint256){

    }
    function initializeLendingProtocol(address) public payable {

    }
    function deposit(address tokenAddress, uint256 amount) public payable {

    }

    function borrow(address tokenAddress, uint256 amount) public {

    }

    function repay(address tokenAddress, uint256 amount) public {

    }

    function liquidate(address user, address tokenAddress, uint256 amount) public {

    }


    function withdraw(address tokenAddress, uint256 amount) external {

    }

    function getAccruedSupplyAmount(address _asset) public returns (uint256 accruedSupplyAmount) {

    }

    receive() external payable {
        // for ether receive
    }
}