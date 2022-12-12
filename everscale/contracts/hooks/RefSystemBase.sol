pragma ton-solidity >= 0.39.0;
pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;


import "./../modules/bridge/interfaces/IProxyExtended.sol";
import "./../modules/bridge/interfaces/multivault/IProxyMultiVaultAlien_V3.sol";
import "./../modules/bridge/interfaces/event-configuration-contracts/IEverscaleEventConfiguration.sol";

import "./../modules/utils/ErrorCodes.sol";
import "./../modules/utils/TransferUtils.sol";

import "./../modules/bridge/alien-token/TokenRootAlienEVM.sol";
import "./../modules/bridge/alien-token-merge/MergePool.sol";
import "./../modules/bridge/alien-token-merge/MergeRouter.sol";
import "./../modules/bridge/alien-token-merge/MergePoolPlatform.sol";

import "ton-eth-bridge-token-contracts/contracts/interfaces/IAcceptTokensBurnCallback.sol";
import "ton-eth-bridge-token-contracts/contracts/interfaces/ITokenWallet.sol";


import '@broxus/contracts/contracts/access/InternalOwner.sol';
import '@broxus/contracts/contracts/utils/CheckPubKey.sol';
import '@broxus/contracts/contracts/utils/RandomNonce.sol';
import "@broxus/contracts/contracts/libraries/MsgFlag.sol";


import "./../modules/TokenContracts/interfaces/IAcceptTokensTransferCallback.sol";

import "../interfaces/IProxyHook.sol";
import "../interfaces/IProjectCallback.sol";
import "../proxy/HookedProxyMultiVaultCellEncoder.sol";

import "./RefInstance.sol";
import "./RefInstancePlatform.sol";
import "./RefAccountPlatform.sol";
import "./ProjectPlatform.sol";
import "./Project.sol";

import "../interfaces/IRefSystem.sol";
import "../interfaces/IUpgradeable.sol";

abstract contract RefSystemBase is
    IRefSystem,
    InternalOwner,
    IUpgradeable,
    IAcceptTokensTransferCallback
{   
    TvmCell public _platformCode;
    
    address public _refFactory;
    TvmCell public _refCode;
    TvmCell public _refPlatformCode;
    TvmCell public _accountCode;
    TvmCell public _accountPlatformCode;
    TvmCell public _projectCode;
    TvmCell public _projectPlatformCode;

    uint128 public _approvalFee;
    
    function _reserve() virtual internal returns (uint128) {
        return 0.2 ton;
    }
    function version() virtual public returns (uint32);

    function onAcceptTokensTransfer(
        address tokenRoot,
        uint128 amount,
        address sender,
        address senderWallet,
        address remainingGasTo,
        TvmCell payload
    ) override external {
        // TODO: Check if Valid Wallet
        (address projectOwner, address referred, address referrer) = abi.decode(payload, (address, address, address));
        address targetProject = _deriveProject(projectOwner);
        TvmCell acceptParams = abi.encode(msg.sender, tokenRoot, amount, sender, senderWallet, remainingGasTo, projectOwner, referred, referrer);
        Project(targetProject).meta{callback: RefSystemBase.getProjectMeta}(acceptParams);
    }

    function onAcceptTokensTransferPayloadEncoder(address projectOwner, address referred, address referrer) responsible external returns (TvmCell) {
        return abi.encode(projectOwner, referred, referrer);
    }

    function getProjectMeta(
        bool isApproved,
        uint128 cashback,
        uint128 projectFee,
        TvmCell acceptParams
    ) external {
        (address tokenWallet,
        address tokenRoot,
        uint128 amount,
        address sender,
        address senderWallet,
        address remainingGasTo,
        address projectOwner,
        address referred,
        address referrer) = abi.decode(acceptParams, (address, address, uint128, address, address, address, address, address, address));
        require(msg.sender == _deriveProject(projectOwner), 400, "Not a valid Project");

        // Allocate to System Owner
        if(amount< _approvalFee) return;
        _deployRefAccount(owner, tokenRoot, _approvalFee, sender, remainingGasTo);

        // Allocate to Project Owner
        if (amount < _approvalFee + projectFee) return;
        _deployRefAccount(projectOwner, tokenRoot, projectFee, sender, remainingGasTo);
        
        // Allocate Rewards
        uint128 r = amount - _approvalFee - projectFee;
        if (r < cashback) return;
        uint128 reward = r - cashback;
        _deployRefAccount(referrer, tokenWallet, reward, sender, remainingGasTo);
        _deployRefAccount(referred, tokenWallet, cashback, sender, remainingGasTo);
    }

    function requestTransfer(
        address recipient,
        address tokenWallet,
        uint128 reward,
        address remainingGasTo,
        bool notify,
        TvmCell payload
    ) override external {
        require(msg.sender == _deriveRefAccount(recipient), 400, "Invalid Account");
        ITokenWallet(tokenWallet).transfer(reward, recipient, 0 ton, remainingGasTo, notify, payload);
    }


    function deriveRef(address recipient) external responsible returns (address) {
       return _deriveRef(recipient);
    }

    function deriveProject(address owner) external responsible returns (address) {
       return _deriveProject(owner);
    }

    function deriveRefAccount(address owner) external responsible returns (address) {
       return _deriveRefAccount(owner);
    }
    function deployProject(
        address refSystem,
        uint16 projectFee,
        uint16 cashbackFee,
        address sender,
        address remainingGasTo
    ) public returns (address) {
        return new ProjectPlatform {
            stateInit: _buildProjectInitData(msg.sender),
            value: 0,
            wid: address(this).wid,
            bounce: true,
            flag: MsgFlag.REMAINING_GAS
        }(
            _projectCode,
            version(),
            _refFactory,
            projectFee,
            cashbackFee,
            sender,
            remainingGasTo
        );
    }

    function approveProject(address projectOwner) public {
        Project(_deriveProject(projectOwner)).acceptInit();
    }

    function _deriveRef(address recipient) internal returns (address) {
       return address(tvm.hash(_buildRefInitData(recipient)));
    }

    function _deriveProject(address owner) internal returns (address) {
        return address(tvm.hash(_buildProjectInitData(owner)));
    }

    function _deriveRefAccount(address owner) internal returns (address) {
        return address(tvm.hash(_buildRefAccountInitData(owner)));
    }

    function _deployRefAccount(
        address recipient,
        address tokenWallet,
        uint128 reward,
        address sender,
        address remainingGasTo
    ) internal returns (address) {
        return new RefAccountPlatform {
            stateInit: _buildRefAccountInitData(recipient),
            value: 3 ton,
            wid: address(this).wid,
            flag: 0,
            bounce: true
            // flag: MsgFlag.ALL_NOT_RESERVED
        }(_refCode, version(), tokenWallet, reward, sender, remainingGasTo);
    }
    
    function _deployRefInstance(address recipient, address lastRef, uint128 lastRefReward) internal returns (address) {
        return new RefInstancePlatform {
            stateInit: _buildRefInitData(recipient),
            value: 3 ton,
            wid: address(this).wid,
            flag: 0,
            bounce: true
            // flag: MsgFlag.ALL_NOT_RESERVED
        }(_refCode, version(), lastRef, lastRefReward, recipient, address(this));
    }

    function _buildProjectInitData(address owner) internal returns (TvmCell) {
        return tvm.buildStateInit({
            contr: ProjectPlatform,
            varInit: {
                root: address(this),
                owner: owner
            },
            pubkey: 0,
            code: _projectPlatformCode
        });
    }
    function _buildRefInitData(address target) internal returns (TvmCell) {
        return tvm.buildStateInit({
            contr: RefInstancePlatform,
            varInit: {
                root: address(this),
                owner: target
            },
            pubkey: 0,
            code: _refPlatformCode
        });
    }

    function _buildRefAccountInitData(address target) internal returns (TvmCell) {
        return tvm.buildStateInit({
            contr: RefAccountPlatform,
            varInit: {
                root: address(this),
                owner: target
            },
            pubkey: 0,
            code: _accountPlatformCode
        });
    }

}