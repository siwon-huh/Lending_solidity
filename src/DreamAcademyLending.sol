// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {SafeMath} from "openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import "./interface/IDreamAcademyLending.sol";
import "./interface/IPriceOracle.sol";
import "forge-std/console.sol";
contract DreamAcademyLending is IDreamAcaemdyLending{
    using SafeMath for uint256;
    IPriceOracle oracle;
    ERC20 usdc;
    address eth_address;
    address usdc_address;
    address owner;
    // mapping(address => uint256) map_total_deposit_token_amount;
    uint256 usdc_total_supply;
    uint256 eth_total_collateral;
    uint256 usdc_total_borrowal;
    uint256 usdc_total_interest;
    mapping(address => mapping(address => uint256)) map_user_deposit_token_amount;
    mapping(address => mapping(address => uint256)) map_user_deposit_token_blockNum;

    mapping(address => uint256) map_user_borrow_principal_usdc_amount;
    mapping(address => uint256) map_user_borrow_interest_usdc_amount;
    mapping(address => uint256) map_user_borrow_principal_with_interest_usdc_amount;
    mapping(address => uint256) map_user_borrow_usdc_blockNum;

    uint256 eth_price;
    uint256 usdc_price;

    uint256 loan_to_value = 50;
    uint256 current_block_number;
    uint256 block_interval;
    uint256 interest_10decimal = 1000000139;

    // uint256 liquidation_thershold = 75;


    // uint256 total_usdc_borrowal_principal;


    constructor(IPriceOracle _oracle, address _usdc) {
        oracle = _oracle;
        eth_address = address(0x00);
        usdc_address = _usdc;
        usdc = ERC20(usdc_address);
        owner = msg.sender;
    }

    function initializeLendingProtocol(address tokenAddress) public payable {
        // map_total_deposit_token_amount[tokenAddress] = msg.value;
        map_user_deposit_token_amount[msg.sender][tokenAddress] = msg.value;
        usdc.transferFrom(msg.sender, address(this), msg.value);
    }

    function deposit(address tokenAddress, uint256 amount) public payable {

        // requirements different from eth and usdc
        if (tokenAddress == eth_address){
            // when ETH deposit
            // deposit amount = msg.value
            // deposit amount should not be 0, and should match `amount`
            require(msg.value != 0, "ETH deposit: msg.value should not be 0");
            require(msg.value == amount, "ETH deposit: msg.value should match amount");

            // eth deposit to this contract

            // update deposit account book
            map_user_deposit_token_amount[msg.sender][tokenAddress] += msg.value;
            // map_total_deposit_token_amount[tokenAddress] += msg.value;
            // map_user_deposit_token_blockNum[msg.sender][tokenAddress] = block.number;

            eth_total_collateral += msg.value;

        } else {
            // check usdc allowance
            require(usdc.allowance(msg.sender, address(this)) >= amount, "USDC deposit: not enough allowance");


            // transfer sender's deposit to me
            bool result = usdc.transferFrom(msg.sender, address(this), amount);
            require(result, "USDC deposit failed");

            // update deposit account book
            map_user_deposit_token_amount[msg.sender][tokenAddress] += amount;
            // map_total_deposit_token_amount[tokenAddress] += amount;
            map_user_deposit_token_blockNum[msg.sender][tokenAddress] = block.number;

            usdc_total_supply += amount;
        }
    }

    // update eth and usdc price
    function updateOracle() internal {
        eth_price = oracle.getPrice(eth_address);
        usdc_price = oracle.getPrice(usdc_address);
    }

    function updateInterest() public {
        current_block_number = block.number;
        // 이자는 원금에 대해 기간만큼 붙는다.
        uint256 user_borrowal = map_user_borrow_principal_usdc_amount[msg.sender];
        uint256 block_interval = current_block_number - map_user_borrow_usdc_blockNum[msg.sender];
        uint256 user_interest;
        // 시간을 구한다.
        if (block_interval > 7200 * 100){
            block_interval = (current_block_number - map_user_borrow_usdc_blockNum[msg.sender]) / (7200 * 500);
            uint256 five_hundred_day_interest = 1648309416;
            // 이자 = 원금 * (500일 이자 ** 500일 단위 간격) - 원금
            user_interest = user_borrowal * five_hundred_day_interest ** block_interval / (10**9) ** block_interval - user_borrowal;
            // 총 이자 = 총 원금 * 500일 이자 ** 500일 단위 간격 - 총 원금
            usdc_total_interest = usdc_total_borrowal * five_hundred_day_interest ** block_interval / (10**9) ** block_interval - usdc_total_borrowal;
        } else {
            // 특정 시간동안 붙는 이자는 (원금) * ( 1 + 이자율 ) ** 시간 - (원금) 만큼이다.
            user_interest = user_borrowal * interest_10decimal ** block_interval / (10**9) ** block_interval - user_borrowal;
            usdc_total_interest = usdc_total_borrowal * interest_10decimal ** block_interval / (10**9) ** block_interval - usdc_total_borrowal;
        }

        // 업데이트된 이자를 넣어준다.
        map_user_borrow_interest_usdc_amount[msg.sender] = user_interest;
    }

    function borrow(address tokenAddress, uint256 amount) public {
        // 빌려주는 토큰은 무조건 usdc이다.
        require(tokenAddress == usdc_address, "no borrow option of ether");
        // 유저의 담보를 받아온다.
        uint256 user_eth_deposit = map_user_deposit_token_amount[msg.sender][eth_address];

        updateOracle();
        updateInterest();

        // 유저가 빌린 금액은 원금 + 이자이다.
        uint256 user_usdc_borrowed = getUserTotalDebt(msg.sender);


        // 담보 * LTV >= 빌린 금액 + 빌릴 금액이어야 한다.
        require(user_eth_deposit * eth_price * loan_to_value / 100 >= (user_usdc_borrowed + amount) * usdc_price, "not enough collateral");
        // 그와중에 usdc도 풀에 충분히 예치되어있어야 빌려줄 수 있다.
        require(usdc_total_supply >= amount, "not enough usdc supply");

        // 대출이 발생하면 누가 usdc를 얼마나 빌렸는지 업데이트해준다. 이 경우 원금만 업데이트 해주면 된다.
        map_user_borrow_principal_usdc_amount[msg.sender] += amount;
        // 대출이 발생한 블록넘버를 이자계산을 위해 업데이트해준다.
        map_user_borrow_usdc_blockNum[msg.sender] = block.number;

        // 대출이 발생하면 usdc를 채무자에게 송금해준다.
        usdc.approve(address(this), amount);
        usdc.transferFrom(address(this), msg.sender, amount);
        // total_usdc_borrowal_principal += amount;
        usdc_total_borrowal += amount;
    }

    // 유져의 빚 상태를 불러온다.
    function getUserTotalDebt(address account) public returns (uint256 user_debt){
        // 빚은 원금 + 이자이다.
        user_debt = map_user_borrow_principal_usdc_amount[account] + map_user_borrow_interest_usdc_amount[account];
        // 원금 + 이자의 상태를 업데이트해준다.
        map_user_borrow_principal_with_interest_usdc_amount[account] = user_debt;
    }

    // pay back one's borrowal. it can be partial
    function repay(address tokenAddress, uint256 amount) public {
        updateOracle();
        updateInterest();
        uint256 user_debt = getUserTotalDebt(msg.sender);
        require(user_debt >= amount, "repayal more than your debt");
        // 원금을 초과한 상환
        if (amount > map_user_borrow_principal_usdc_amount[msg.sender]) {
            // 원금은 0으로 돌려주고 이자를 원금으로 돌린다.
            map_user_borrow_principal_usdc_amount[msg.sender] = 0;
            map_user_borrow_interest_usdc_amount[msg.sender] -= amount - map_user_borrow_principal_usdc_amount[msg.sender];
        } else {
            // 원금을 초과하지 않을 경우 원금을 깎아준다.
            map_user_borrow_principal_usdc_amount[msg.sender] -= amount;
        }
        usdc_total_borrowal -= amount;
    }

    function liquidate(address user, address tokenAddress, uint256 amount) public {
        // updateOracle();
        // updateInterest();
        // uint256 user_total_deposit = map_user_deposit_token_amount[user][eth_address] * eth_price+ map_user_deposit_token_amount[user][usdc_address] + usdc_price;
        // uint256 user_total_borrow = map_user_borrow_principal_usdc_amount[user] * usdc_price;
        // require(user_total_deposit * liquidation_thershold < user_total_borrow * 100, "liquidation not yet");
        // uint _amount;
        // if(map_user_borrow_principal_usdc_amount[user] < 100){
        //     _amount = amount;
        // } else {
        //     if (tokenAddress == eth_address){
        //         _amount = amount * eth_price;
        //     } else {
        //         _amount = amount * usdc_price;
        //     }
        //     require(_amount <= user_total_deposit / 4);
        // }
        // if (user_total_deposit * liquidation_thershold < user_total_borrow * 100){
        //     // liquidate token to get usdc
        //     if (tokenAddress == eth_address){
        //         (bool sent, ) = (user).call{value: amount}("");
        //         map_user_deposit_token_amount[user][tokenAddress] -= amount;
        //     } else {
        //         bool result = usdc.transferFrom(user, address(this), amount);
        //         map_user_deposit_token_amount[user][tokenAddress] -= amount;
        //     }
        // }
    }
 

    function withdraw(address tokenAddress, uint256 amount) public {
        updateOracle();
        updateInterest();
        // 담보로 맡긴 이더를 빼려고 할 때의 경우이다.
        if(tokenAddress == eth_address){
            require(amount <= map_user_deposit_token_amount[msg.sender][eth_address], "cannot withdraw over your collateral");
            // 빚을 다 갚은 경우 담보를 빼줄 수 있다.
            uint256 user_debt = getUserTotalDebt(msg.sender);
            uint256 user_collateral = map_user_deposit_token_amount[msg.sender][eth_address];

            // LTV를 넘지 않는 선에서 withdraw해줘야 한다.
            // 빚 / (담보 가치 - withdraw 가치) 가 75% 이하여야 한다.
            // console.log(loan_to_value * ((user_collateral - amount) * eth_price));
            require((user_debt * 100 <= loan_to_value * ((user_collateral - amount) * eth_price)), "withdraw meets LTV limit");

            // 성공할 경우 장부를 업데이트 한 뒤 withdraw 양만큼 eth를 돌려준다.
            map_user_deposit_token_amount[msg.sender][eth_address] -= amount;
            (bool sent, ) = (msg.sender).call{value: amount}("");
        } else {
            require(amount / (10**18) <= getAccruedSupplyAmount(usdc_address), "over accrued amount");
            if (map_user_deposit_token_amount[msg.sender][usdc_address] <= amount){
                map_user_deposit_token_amount[msg.sender][usdc_address] = 0;
            } else {
                map_user_deposit_token_amount[msg.sender][usdc_address] -= amount;
            }
            usdc.approve(address(this), amount);
            usdc.transferFrom(address(this), msg.sender, amount);

        }
    }

    function getAccruedSupplyAmount(address tokenAddress) public returns (uint256 accruedSupplyAmount) {
        updateOracle();
        updateInterest();
        accruedSupplyAmount = (map_user_deposit_token_amount[msg.sender][usdc_address] + usdc_total_interest * map_user_deposit_token_amount[msg.sender][usdc_address]/ (usdc_total_supply));

    }


    receive() external payable {}
}