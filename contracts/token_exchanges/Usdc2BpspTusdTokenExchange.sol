// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../interfaces/ITokenExchange.sol";
import "../interfaces/IConnector.sol";

contract Usdc2BpspTusdTokenExchange is ITokenExchange {
    IConnector public balConnector;
    IERC20 public usdcToken;
    IERC20 public bpspTusdToken;

    uint256 usdcDenominator;
    uint256 bpspTusdDenominator;

    constructor(
        address _balConnector,
        address _usdcToken,
        address _bpspTusdToken
    ) {
        require(_balConnector != address(0), "Zero address not allowed");
        require(_usdcToken != address(0), "Zero address not allowed");
        require(_bpspTusdToken != address(0), "Zero address not allowed");

        balConnector = IConnector(_balConnector);
        usdcToken = IERC20(_usdcToken);
        bpspTusdToken = IERC20(_bpspTusdToken);

        usdcDenominator = 10 ** (18 - IERC20Metadata(address(usdcToken)).decimals());
        //TODO balancer
        bpspTusdDenominator = 10 ** 12;
    }

    function exchange(
        address spender,
        IERC20 from,
        address receiver,
        IERC20 to,
        uint256 amount
    ) external override {
        require(
            (from == usdcToken && to == bpspTusdToken) || (from == bpspTusdToken && to == usdcToken),
            "Usdc2BpspTusdTokenExchange: Some token not compatible"
        );

        if (amount == 0) {
            uint256 fromBalance = from.balanceOf(address(this));
            if (fromBalance > 0) {
                from.transfer(spender, fromBalance);
            }
            return;
        }

        if (from == usdcToken && to == bpspTusdToken) {
            //TODO: denominator usage
            amount = amount / usdcDenominator;

            // if amount eq 0 after normalization transfer back balance and skip staking
            uint256 balance = usdcToken.balanceOf(address(this));
            if (amount == 0) {
                if (balance > 0) {
                    usdcToken.transfer(spender, balance);
                }
                return;
            }

            require(
                balance >= amount,
                "Usdc2BpspTusdTokenExchange: Not enough usdcToken"
            );

            usdcToken.transfer(address(balConnector), amount);
            balConnector.stake(address(usdcToken), amount, receiver);

            // transfer back unused amount
            uint256 unusedBalance = usdcToken.balanceOf(address(this));
            if (unusedBalance > 0) {
                usdcToken.transfer(spender, unusedBalance);
            }
        } else {
            //TODO: denominator usage
            amount = amount / bpspTusdDenominator;

            // if amount eq 0 after normalization transfer back balance and skip staking
            uint256 balance = bpspTusdToken.balanceOf(address(this));
            if (amount == 0) {
                if (balance > 0) {
                    bpspTusdToken.transfer(spender, balance);
                }
                return;
            }

            // aToken on transfer can lost/add 1 wei. On lost we need correct amount
            if (balance + 1 == amount) {
                amount = amount - 1;
            }

            require(
                balance >= amount,
                "Usdc2BpspTusdTokenExchange: Not enough bpspTusdToken"
            );

            // move assets to connector
            bpspTusdToken.transfer(address(balConnector), amount);

            // correct exchangeAmount if we got diff on aToken transfer
            uint256 onBalConnectorBalance = bpspTusdToken.balanceOf(address(balConnector));
            if (onBalConnectorBalance < amount) {
                amount = onBalConnectorBalance;
            }
            uint256 withdrewAmount = balConnector.unstake(address(usdcToken), amount, receiver);

            //TODO: may be add some checks for withdrewAmount

            // transfer back unused amount
            uint256 unusedBalance = bpspTusdToken.balanceOf(address(this));
            if (unusedBalance > 0) {
                bpspTusdToken.transfer(spender, unusedBalance);
            }
        }
    }
}
