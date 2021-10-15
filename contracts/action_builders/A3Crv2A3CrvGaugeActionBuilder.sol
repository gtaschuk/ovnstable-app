// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ITokenExchange.sol";
import "../interfaces/IActionBuilder.sol";
import "../interfaces/IMark2Market.sol";

contract A3Crv2A3CrvGaugeActionBuilder is IActionBuilder {
    bytes32 constant ACTION_CODE = keccak256("A3Crv2A3CrvGauge");

    ITokenExchange tokenExchange;
    IERC20 a3CrvToken;
    IERC20 a3CrvGaugeToken;

    constructor(
        address _tokenExchange,
        address _a3CrvToken,
        address _a3CrvGaugeToken
    ) {
        require(_tokenExchange != address(0), "Zero address not allowed");
        require(_a3CrvToken != address(0), "Zero address not allowed");
        require(_a3CrvGaugeToken != address(0), "Zero address not allowed");

        tokenExchange = ITokenExchange(_tokenExchange);
        a3CrvToken = IERC20(_a3CrvToken);
        a3CrvGaugeToken = IERC20(_a3CrvGaugeToken);
    }

    function getActionCode() external pure override returns (bytes32) {
        return ACTION_CODE;
    }

    function buildAction(
        IMark2Market.TotalAssetPrices memory totalAssetPrices,
        ExchangeAction[] memory actions
    ) external view override returns (ExchangeAction memory) {
        IMark2Market.AssetPrices[] memory assetPrices = totalAssetPrices.assetPrices;

        // get diff from iteration over prices because can't use mapping in memory params to external functions
        uint256 diff = 0;
        int8 sign = 0;
        for (uint8 i = 0; i < assetPrices.length; i++) {
            // here we need a3CrvGauge diff to make action right
            if (assetPrices[i].asset == address(a3CrvGaugeToken)) {
                diff = assetPrices[i].diffToTarget;
                sign = assetPrices[i].diffToTargetSign;
                break;
            }
        }

        IERC20 from;
        IERC20 to;
        if (sign > 0) {
            from = a3CrvToken;
            to = a3CrvGaugeToken;
        } else {
            from = a3CrvGaugeToken;
            to = a3CrvToken;
        }

        ExchangeAction memory action = ExchangeAction(
            tokenExchange,
            ACTION_CODE,
            from,
            to,
            diff,
            false
        );

        return action;
    }
}