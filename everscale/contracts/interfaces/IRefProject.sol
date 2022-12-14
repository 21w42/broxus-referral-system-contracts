pragma ton-solidity >= 0.39.0;

import "ton-eth-bridge-token-contracts/contracts/interfaces/IVersioned.sol";
import "./IUpgradeable.sol";

interface IRefProject is IVersioned, IUpgradeable{
    function setProjectFee(uint128 fee) external;
    function setCashbackFee(uint128 fee) external;
    function upgrade(address remainingGasTo) external;
    function acceptInit() external;
    function meta(TvmCell payload) view external responsible returns (bool isApproved, uint128 cashbackFee, uint128 projectFee, TvmCell forwardedPayload);
}