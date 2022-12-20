//SPDX-License-Identifier:MIT
pragma solidity 0.8.17;



contract InterestRateModel {

    uint internal constant WAD = 1e18;

    uint internal immutable utilizationRateOptimal;

    uint internal immutable rate0;
    uint internal immutable slope1;
    uint internal immutable slope2;

    constructor(uint _utilizationRateOptimal,uint _rate0,uint _slope1,uint _slope2){
        utilizationRateOptimal = _utilizationRateOptimal;
        rate0 = _rate0;
        slope1 = _slope1;
        slope2 = _slope2;
    }
    
    function getBorrowRate(uint256 cash,uint256 borrows,uint reserves) external view returns (uint256){
        uint ur = (borrows*WAD)/cash;

        if(ur <= utilizationRateOptimal) return WAD + rate0 + (((ur*WAD)/utilizationRateOptimal)*slope1)/WAD;
        return WAD +rate0 + slope1 + (((ur-utilizationRateOptimal)*WAD/(1-utilizationRateOptimal))*slope1)/WAD;
    }

    function getSupplyRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves,
        uint256 reserveFactorMantissa
    )external view returns (uint256) {

    }
}