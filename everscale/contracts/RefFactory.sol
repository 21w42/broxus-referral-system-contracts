pragma ton-solidity >= 0.39.0;
pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "ton-eth-bridge-token-contracts/contracts/interfaces/IAcceptTokensBurnCallback.sol";

import '@broxus/contracts/contracts/access/InternalOwner.sol';
import '@broxus/contracts/contracts/utils/CheckPubKey.sol';
import '@broxus/contracts/contracts/utils/RandomNonce.sol';
import "@broxus/contracts/contracts/libraries/MsgFlag.sol";

import "./interfaces/IUpgradeable.sol";

import "./RefLast.sol";
import "./RefLastPlatform.sol";
import "./ProjectPlatform.sol";
import "./Project.sol";
import "./interfaces/IRefSystemUpgradeable.sol";
import "./RefSystemPlatform.sol";

import "./interfaces/IRefSystem.sol";

contract RefFactory is InternalOwner, RandomNonce {

    TvmCell public _refSystemPlatformCode;
    TvmCell public _refSystemCode;
    TvmCell public _refLastPlatformCode;
    TvmCell public _refLastCode;
    TvmCell public _accountPlatformCode;
    TvmCell public _accountCode;
    TvmCell public _projectPlatformCode;
    TvmCell public _projectCode;
    uint128 public _systemFee;
    uint128 public _deployAccountValue;
    uint128 public _deployRefLastValue;

    constructor(
        address owner,
        TvmCell refSystemPlatformCode,
        TvmCell refSystemCode,
        TvmCell refLastPlatformCode,
        TvmCell refLastCode,
        TvmCell accountPlatformCode,
        TvmCell accountCode,
        TvmCell projectPlatformCode,
        TvmCell projectCode
    ) public {
        tvm.accept();
        _refSystemPlatformCode = refSystemPlatformCode;
        _refSystemPlatformCode = refSystemPlatformCode;
        _refSystemCode = refSystemCode;
        _refLastPlatformCode = refLastPlatformCode;
        _refLastCode = refLastCode;
        _accountPlatformCode = accountPlatformCode;
        _accountCode = accountCode;
        _projectPlatformCode = projectPlatformCode;
        _projectCode = projectCode;
        setOwnership(owner);
    }

    function deployRefSystemAuto(
        address owner,
        uint32 version,
        uint128 systemFee,
        uint128 deployAccountValue,
        uint128 deployRefLastValue,
        address sender,
        address remainingGasTo
    ) public onlyOwner returns (address) {
        return new RefSystemPlatform {
            stateInit: _buildRefSystemInitData(owner),
            wid: address(this).wid,
            value: 0,
            bounce: true,
            flag: MsgFlag.ALL_NOT_RESERVED
        }(_refSystemCode, version, _refLastPlatformCode, _refLastCode, _accountPlatformCode, _accountCode, _projectPlatformCode, _projectCode, systemFee, deployAccountValue, deployRefLastValue, sender, remainingGasTo);
    }

    function deployRefSystem(
        address owner,
        uint32 version,
        TvmCell refSystemCode,
        TvmCell refLastPlatformCode,
        TvmCell refLastCode,
        TvmCell accountPlatformCode,
        TvmCell accountCode,
        TvmCell projectPlatformCode,
        TvmCell projectCode,
        uint128 systemFee,
        uint128 deployAccountValue,
        uint128 deployRefLastValue,
        address sender,
        address remainingGasTo
    ) public onlyOwner returns (address) {
        return new RefSystemPlatform {
            stateInit: _buildRefSystemInitData(owner),
            wid: address(this).wid,
            value: 0,
            bounce: true,
            flag: MsgFlag.ALL_NOT_RESERVED
        }(refSystemCode, version, refLastPlatformCode, refLastCode, accountPlatformCode, accountCode, projectPlatformCode, projectCode, systemFee, deployAccountValue, deployRefLastValue, sender, remainingGasTo);
    }

    function upgradeRefSystem(
        address refSysOwner,
        TvmCell code
    ) public onlyOwner returns (address) {
        IRefSystemUpgradeable(_deriveRefSystem(refSysOwner)).upgrade{value: 0, flag: MsgFlag.ALL_NOT_RESERVED}(code);
    }

    function upgradeTarget(
        address target,
        uint32 version,
        TvmCell code,
        address remainingGasTo
    ) public onlyOwner returns (address) {
        IUpgradeable(target).acceptUpgrade{value: 0, flag: MsgFlag.ALL_NOT_RESERVED}(code, version, remainingGasTo);
    }

    function deriveRefSystem(address owner) public returns (address) {
        return _deriveRefSystem(owner);
    }
    
    function _deriveRefSystem(address owner) internal returns (address) {
        return address(tvm.hash(_buildRefSystemInitData(owner)));
    }

    function _buildRefSystemInitData(address owner) internal returns (TvmCell) {
        return tvm.buildStateInit({
            contr: RefSystemPlatform,
            varInit: {
                root: address(this),
                owner: owner
            },
            pubkey: 0,
            code: _refSystemPlatformCode
        });
    }
    
}