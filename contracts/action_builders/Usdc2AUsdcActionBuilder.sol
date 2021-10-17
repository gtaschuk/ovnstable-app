// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ITokenExchange.sol";
import "../interfaces/IActionBuilder.sol";
import "../interfaces/IMark2Market.sol";

contract Usdc2AUsdcActionBuilder is IActionBuilder {
    bytes32 constant ACTION_CODE = keccak256("Usc2AUsdc");

    ITokenExchange tokenExchange;
    IERC20 usdcToken;
    IERC20 aUsdcToken;

    constructor(
        address _tokenExchange,
        address _usdcToken,
        address _aUsdcToken
    ) {
        require(_tokenExchange != address(0), "Zero address not allowed");
        require(_usdcToken != address(0), "Zero address not allowed");
        require(_aUsdcToken != address(0), "Zero address not allowed");

        tokenExchange = ITokenExchange(_tokenExchange);
        usdcToken = IERC20(_usdcToken);
        aUsdcToken = IERC20(_aUsdcToken);
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
        IMark2Market.AssetPrices memory usdcPrices;
        IMark2Market.AssetPrices memory aUsdcPrices;
        for (uint8 i = 0; i < assetPrices.length; i++) {
            if (assetPrices[i].asset == address(usdcToken)) {
                usdcPrices = assetPrices[i];
                continue;
            }
            if (assetPrices[i].asset == address(aUsdcToken)) {
                aUsdcPrices = assetPrices[i];
                continue;
            }
        }

        // because we know that usdc is leaf in tree and we can use this value
        uint256 diff = usdcPrices.diffToTarget;

        IERC20 from;
        IERC20 to;
        bool targetIsZero;
        if (usdcPrices.targetIsZero || usdcPrices.diffToTargetSign < 0) {
            from = usdcToken;
            to = aUsdcToken;
            targetIsZero = usdcPrices.targetIsZero;
        } else {
            from = aUsdcToken;
            to = usdcToken;
            targetIsZero = aUsdcPrices.targetIsZero;
        }

        ExchangeAction memory action = ExchangeAction(
            tokenExchange,
            ACTION_CODE,
            from,
            to,
            diff,
            targetIsZero,
            false
        );

        return action;
    }
}
